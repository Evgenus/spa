fs = require('fs')
walk = require('fs-walk')
path = require('path')
detectiveCJS = require('detective')
detectiveAMD = require('detective-amd')
definition = require('module-definition').sync
crypto = require('crypto')
yaml = require('js-yaml')
ejs = require("ejs")
_  = require('underscore')
_.string =  require('underscore.string')
_.mixin(_.string.exports())

preg_quote = (str, delimiter) ->
    return (str + '')
        .replace(new RegExp('[.\\\\+*?\\[\\^\\]${}=!<>|:\\' + (delimiter || '') + '-]', 'g'), '\\$&')

globStringToRegex = (str) ->
    return new RegExp(
        preg_quote(str)
            .replace(/\\\*\\\*\//g, '(?:[^/]+/)*')
            .replace(/\\\*/g, '[^/]*')
            .replace(/\\\?/g, '[^/]')
        , 'm')

class CyclicDependenciesError extends Error
    constructor: (@loop) ->
        @name = @constructor.name
        @message = "Can't sort modules. Loop found: \n#{@loop}"

class UnresolvedDependencyError extends Error
    constructor: (@path, @alias) ->
        @name = @constructor.name
        @message = "Can't resolve dependency `#{@alias}` "+
                   "inside module `#{@path}`"

class ExternalDependencyError extends Error
    constructor: (@path, @alias, @dep) ->
        @name = @constructor.name
        @message = "Module at path `#{dep}` is required from `#{path}` " +
                   "as `#{alias}`, but it cant be found inside building scope."

class Loop
    constructor: () ->
        @_parts = []
    prepend: (path, alias) ->
        @_parts.unshift([path, alias])
        return this
    toString: ->
        return "" if @_parts.length == 0
        p = @_parts.concat([@_parts[0]])
        return (for i in [0..@_parts.length-1] 
            "#{p[i][0]} --[#{p[i][1]}]--> #{p[i+1][0]}" 
            ).join("\n")
            
make_md5 = (content) -> 
    return crypto.createHash('md5').update(content).digest('hex')

class Builder
    constructor: (options) ->
        @root = path.resolve(process.cwd(), options.root)
        @extensions = options.extensions ? [".js"]
        @excludes = _(options.excludes ? []).map(globStringToRegex)
        @paths = options.paths ? {}
        @hosting = for pattern, template of options.hosting ? {}
            pattern: globStringToRegex(pattern)
            template: template
        @default_loader = options.default_loader ? "cjs"
        @loaders = for pattern, type of options.loaders ? {}
            pattern: globStringToRegex(pattern)
            type: type            
        @manifest = options.manifest
        @index = options.index
        @_built_ins = ["loader"]
        @pretty = options.pretty ? false
        @assets = 
            appcache_template: path.join(__dirname, "assets/appcache.tmpl")
            index_template: path.join(__dirname, "assets/index.tmpl")
            md5: path.join(__dirname, "assets/md5.js")
            loader: path.join(__dirname, "assets/loader.js")
            fake_app: path.join(__dirname, "assets/fake/app.js")
            fake_manifest: path.join(__dirname, "assets/fake/manifest.json")
        for own name, value of options.assets
            @assets[name] = value
        @appcache = options.appcache
        @cached = options.cached
        @_clear()

    filter: (filepath) ->
        return false unless _(@extensions).any (ext) -> 
            path.extname(filepath) is ext
        return not _(@excludes).any (pattern) -> 
            pattern.test(filepath)

    _clear: ->
        @_modules = []
        @_by_path = {}
        @_by_id = {}

    _relativate: (filepath) -> 
        return '/' + filepath.split(path.sep).join('/')

    _enlist: (root) ->
        walk.filesSync root, (basedir, filename, stat) =>
            filepath = path.resolve(basedir, filename)
            relative = @_relativate(path.relative(root, filepath))

            return unless @filter(relative)

            module =
                path: filepath
                relative: relative

            @_by_path[filepath] = module
            @_modules.push(module)
        return

    _set_ids: ->
        for module in @_modules
            ext = path.extname(module.path)
            root = path.dirname(module.path)
            id = path.basename(module.path, ext)

            if id is "index"
                id = path.basename(root)
                root = path.dirname(root)

            while id of @_by_id
                id = path.basename(root) + "|" + id
                root = path.dirname(root)

            @_by_id[id] = module
            module.id = id
        return

    _resolve_to_file: (filepath) ->
        if fs.existsSync(filepath)
            stats = fs.statSync(filepath)
            if stats.isFile()
                return filepath
        return

    _resolve_to_directory: (dirpath) ->
        if fs.existsSync(dirpath)
            stats = fs.statSync(dirpath)
            if stats.isDirectory()
                return @_resolve_to_file(path.join(dirpath, "index.js"))
        return

    _get_type: (module) ->
        for rule in @loaders
            continue unless rule.pattern.test(module.relative)
            return rule.type
        switch definition(module.path)
            when "commonjs" then return "cjs"
            when "amd" then return "amd"
        return @default_loader

    _resolve: (module, dep) ->
        for alias, prefix of @paths
            if _(dep).startsWith(alias)
                dep = dep.replace(alias, prefix)
                break

        if _(dep).startsWith("/")
            dep = path.join(@root, dep)
        else if _(dep).startsWith("./") or _(dep).startsWith("../")
            basedir = path.dirname(module.path)
            dep = path.resolve(basedir, dep)

        return @_resolve_to_file(dep) ? 
               @_resolve_to_file(dep + ".js") ? 
               @_resolve_to_directory(dep)

    _analyze: (module) ->
        source = fs.readFileSync(module.path)
        module.md5 = make_md5(source)
        module.size = source.length
        module.deps_paths = {}

        deps = switch module.type
            when "cjs" then detectiveCJS(source)
            when "amd" then detectiveAMD(source)
            else []

        # add into deps hardcoded dependencies from config

        for dep in deps
            continue if dep in @_built_ins
            resolved = @_resolve(module, dep)
            unless resolved?
                throw new UnresolvedDependencyError(module.relative, dep)
            module.deps_paths[dep] = resolved
    
    _find_loop: (candidates) ->
        for candidate in candidates
            walked = []
            _go_deep = (current) =>
                module = @_by_path[current]
                relative = module.relative
                deps = module.deps_paths
                for alias, dep of deps
                    continue unless dep in candidates
                    continue if dep in walked
                    return new Loop().prepend(relative, alias) if dep is candidate
                    walked.push(dep)
                    deep = _go_deep(dep)
                    walked.pop()
                    return deep.prepend(relative, alias) if deep?
            has_loop = _go_deep(candidate)
            return has_loop if has_loop?

    _sort: ->
        left = (module.path for module in @_modules)
        order = []
        while left.length > 0
            use = []
            for mpath in left
                deps = @_by_path[mpath].deps_paths
                use.push(mpath) unless _(deps).any((dep) -> dep not in order)
            if use.length == 0
                throw new CyclicDependenciesError(@_find_loop(left))
            order.push(use...)
            left = left.filter((mpath) -> mpath not in use)
        @_modules = (@_by_path[mpath] for mpath in order)

    _link: ->
        for module in @_modules
            module.deps_ids = {}
            for dep, resolved of module.deps_paths
                if @_by_path[resolved]?
                    module.deps_ids[dep] = @_by_path[resolved].id
                else
                    throw new ExternalDependencyError(module.relative, dep, resolved)

    _host: (filepath) ->
        for rule in @hosting
            continue unless rule.pattern.test(filepath)
            return filepath.replace(rule.pattern, rule.template)
        return

    _write_manifest: ->
        data = for module in @_modules
            id: module.id
            url: module.url
            md5: module.md5
            size: module.size
            type: module.type
            deps: module.deps_ids

        filename = path.resolve(@root, @manifest)
        content = JSON.stringify(data, null, if @pretty then "  ")
        console.log("Writing #{filename}")
        fs.writeFileSync(filename, content)

    _write_index: ->
        assets = {}
        for own name, value of @assets
            assets[name] = fs.readFileSync(value, encoding: "utf8")

        compiled = ejs.compile(assets["index_template"])
        filename = path.resolve(@root, @index)
        @_index_content = compiled(assets)
        console.log("Writing #{filename}")
        fs.writeFileSync(filename, @_index_content)

    _write_appcache: ->
        assets = {}
        for filename in @cached
            filepath = path.resolve(@root, filename)
            relative = @_relativate(path.relative(@root, filepath))
            url = @_host(relative)
            continue unless url?
            content = fs.readFileSync(filepath, encoding: "utf8")
            assets[url] = make_md5(content)
        if @index?
            filepath = path.resolve(@root, @index)
            relative = @_relativate(path.relative(@root, filepath))
            url = @_host(relative)
            if url?
                filename = path.resolve(@root, @index)
                assets[url] = make_md5(@_index_content)
        
        if Object.keys(assets).length == 0
            if @index?
                console.log("No hosting rule for `#{@index}` file. AppCache manifest `#{@appcache}` appears to be empty")
            else
                console.log("There are no assets to be included into AppCache manifest `#{@appcache}`")

        template = @assets["appcache_template"]
        compiled = ejs.compile(fs.readFileSync(template, encoding: "utf8"))
        filename = path.resolve(@root, @appcache)
        content = compiled
            assets: assets
        console.log("Writing #{filename}")
        fs.writeFileSync(filename, content)

    build: ->
        @_enlist(@root)
        @_set_ids()
        for module in @_modules
            module.type = @_get_type(module)
            @_analyze(module)
        @_link()
        @_sort()
        for module in @_modules
            module.url = @_host(module.relative)
        @_write_manifest() if @manifest?
        @_write_index() if @index?
        @_write_appcache() if @appcache?
        return

load_json = (filepath) ->
    return unless filepath?
    source = fs.readFileSync(filepath)
    return JSON.parse(source)

load_yaml = (filepath) ->
    return unless filepath?
    source = fs.readFileSync(filepath, encoding: "utf8")
    return yaml.safeLoad(source)
    
get_config_content = (filepath) ->
    switch path.extname(filepath)
        when ".yaml", ".yml"
            return load_yaml(filepath)
        when ".json"
            return load_json(filepath)

Builder.from_config = (config_path) ->
    console.log("Reading config from #{config_path}")
    basedir = path.dirname(config_path)
    config = get_config_content(config_path)
    config.root ?= "."
    config.root = path.resolve(basedir, config.root)
    return new Builder(config)

exports.Builder = Builder
exports.CyclicDependenciesError = CyclicDependenciesError
exports.UnresolvedDependencyError = UnresolvedDependencyError
exports.ExternalDependencyError = ExternalDependencyError
exports.Loop = Loop
