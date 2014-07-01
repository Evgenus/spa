fs = require('fs')
walker = require('fs-walk-glob-rules')
globrules = require('glob-rules')
path = require('path')
clc = require('cli-color')
detectiveCJS = require('detective')
detectiveAMD = require('detective-amd')
definition = require('module-definition').sync
CryptoJS = require("crypto-js")
yaml = require('js-yaml')
ejs = require("ejs")
_  = require('underscore')
_.string =  require('underscore.string')
_.mixin(_.string.exports())

packagejson = ( ->
    packagepath = path.resolve(__dirname, '../package.json')
    return JSON.parse(fs.readFileSync(packagepath, 'utf8'))
    )()

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

class NoCopyingRuleError extends Error
    constructor: (@path) ->
        @name = @constructor.name
        @message = "No copying rule for module to be crypter at path `#{@path}`"

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

Logger = 
    info: (args...) ->
        console.info(args.join(" "))

    warn: (args...) ->
        console.warn(clc.bgYellow.bold("SPA"), clc.yellow(args.join(" ")))

    error: (args...) ->
        console.error(clc.bgRed.bold("SPA"), clc.red.bold(args.join(" ")))

encode_data = (data) ->
    if data instanceof Buffer
        words = []
        len = data.length
        i = 0
        while i < len
            words[i >>> 2] |= (data[i] & 0xff) << (24 - (i % 4) * 8)
            i++
        return CryptoJS.lib.WordArray.create(words, len)
    
    if data instanceof String or typeof data is "string"
        return CryptoJS.enc.Utf8.parse(data)

hashers = 
    md5: (data) -> 
        encoded_data = encode_data(data)
        hash = CryptoJS.MD5(encoded_data)
        return hash.toString(CryptoJS.enc.Hex)
    ripemd160: (data) -> 
        encoded_data = encode_data(data)
        hash = CryptoJS.RIPEMD160(encoded_data)
        return hash.toString(CryptoJS.enc.Hex)
    sha1: (data) -> 
        encoded_data = encode_data(data)
        hash = CryptoJS.SHA1(encoded_data)
        return hash.toString(CryptoJS.enc.Hex)
    sha224: (data) -> 
        encoded_data = encode_data(data)
        hash = CryptoJS.SHA224(encoded_data)
        return hash.toString(CryptoJS.enc.Hex)
    sha256: (data) -> 
        encoded_data = encode_data(data)
        hash = CryptoJS.SHA256(encoded_data)
        return hash.toString(CryptoJS.enc.Hex)
    sha384: (data) -> 
        encoded_data = encode_data(data)
        hash = CryptoJS.SHA384(encoded_data)
        return hash.toString(CryptoJS.enc.Hex)
    sha512: (data) -> 
        encoded_data = encode_data(data)
        hash = CryptoJS.SHA512(encoded_data)
        return hash.toString(CryptoJS.enc.Hex)
    sha3: (data) -> 
        encoded_data = encode_data(data)
        hash = CryptoJS.SHA3(encoded_data)
        return hash.toString(CryptoJS.enc.Hex)

encoders = 
    identity: (data, builder) ->
        return data

class Builder
    constructor: (options) ->
        @root = path.resolve(process.cwd(), options.root) + "/"
        @extensions = options.extensions ? [".js"]
        @excludes = options.excludes ? []
        @paths = options.paths ? {}
        @hosting = for pattern, template of options.hosting ? {}
            test: globrules.tester(pattern)
            transform: globrules.transformer(pattern, template)
        @copying = for pattern, template of options.copying ? {}
            test: globrules.tester(pattern)
            transform: globrules.transformer(pattern, template)
        @default_loader = options.default_loader ? "cjs"
        @loaders = for pattern, type of options.loaders ? {}
            test: globrules.tester(pattern)
            type: type            
        @manifest = options.manifest
        @index = options.index
        @_built_ins = ["loader"]
        @pretty = options.pretty ? false
        @assets = 
            appcache_template: path.join(__dirname, "assets/appcache.tmpl")
            index_template: path.join(__dirname, "assets/index.tmpl")
        for own name, value of options.assets
            @assets[name] = value
        @appcache = options.appcache
        @cached = options.cached
        @hash_func = options.hash_func ? "md5"
        @randomize_urls = options.randomize_urls ? true
        @coding_func = options.coding_func ? "identity"
        @_clear()

    filter: (filepath) ->
        expected = path.extname(filepath)
        return false unless _(@extensions).any (ext) -> expected is ext
        return true

    calc_hash: (content) -> 
        return hashers[@hash_func](content)

    calc_code: (content) ->
        return encoders[@coding_func](content, this)

    _clear: ->
        @_modules = []
        @_by_path = {}
        @_by_id = {}

    _relativate: (filepath) -> 
        return './' + filepath.split(path.sep).join('/')

    _enlist: (root) ->
        walked = walker.walkSync 
            root: root
            excludes: @excludes

        for data in walked
            continue unless @filter(data.relative)
            module =
                path: data.path
                relative: data.relative

            @_by_path[data.path] = module
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
                id = path.basename(root) + "/" + id
                newroot = path.dirname(root)
                break if newroot is root
                root = newroot 

            id = id.split(/[^a-zA-Z0-9]/g).join("_")

            while id of @_by_id
                id = "_" + id

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
            continue unless rule.test(module.relative)
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
            continue unless rule.test(filepath)
            return rule.transform(filepath)
        return

    _get_copying: (filepath) ->
        for rule in @copying
            continue unless rule.test(filepath)
            return rule.transform(filepath)
        return

    _create_manifest: ->
        modules = for module in @_modules
            id: module.id
            url: module.url
            hash: module.hash
            size: module.size
            type: module.type
            deps: module.deps_ids

        manifest = 
            version: packagejson.version
            hash_func: @hash_func
            modules: modules

        return JSON.stringify(manifest, null, if @pretty then "  ")

    _write_file: (destination, content) ->
        filepath = path.resolve(@root, destination)
        Logger.info("Writing #{filepath}. #{content.length} bytes.")
        fs.writeFileSync(filepath, content)

    _inject_inline: (relative) ->
        filepath = path.resolve(__dirname, "assets", relative)
        return fs.readFileSync(filepath, encoding: "utf8")

    _write_index: ->
        assets = {}
        namespace =
            assets: assets
        for own name, value of @assets
            content = fs.readFileSync(value, encoding: "utf8")
            namespace[name] = content
            assets[name] = content

        namespace["manifest_location"] = "manifest.json"
        namespace["randomize_urls"] = @randomize_urls
        namespace["inline"] = (relative) => @_inject_inline(relative)
        namespace["version"] = packagejson.version
        namespace["hash_name"] = @hash_func
        namespace["decoder_name"] = @coding_func
        if @manifest?
            filepath = path.resolve(@root, @manifest)
            relative = @_relativate(path.relative(@root, filepath))
            url = @_host(relative)
            if url?
                namespace["manifest_location"] = url
            else
                Logger.warn("Manifest file hosted as `manifest.json` and will be accesible relatively")
            
        compiled = ejs.compile(assets["index_template"])
        @_index_content = compiled(namespace)
        @_write_file(@index, @_index_content)

    _write_appcache: ->
        assets = {}
        for filename in @cached
            filepath = path.resolve(@root, filename)
            relative = @_relativate(path.relative(@root, filepath))
            url = @_host(relative)
            continue unless url?
            content = fs.readFileSync(filepath, encoding: "utf8")
            assets[url] = @calc_hash(content)
        if @index?
            filepath = path.resolve(@root, @index)
            relative = @_relativate(path.relative(@root, filepath))
            url = @_host(relative)
            if url?
                filename = path.resolve(@root, @index)
                assets[url] = @calc_hash(@_index_content)
        
        if Object.keys(assets).length == 0
            if @index?
                Logger.warn("No hosting rule for `#{@index}` file. AppCache manifest `#{@appcache}` appears to be empty")
            else
                Logger.warn("There are no assets to be included into AppCache manifest `#{@appcache}`")

        template = @assets["appcache_template"]
        compiled = ejs.compile(fs.readFileSync(template, encoding: "utf8"))
        content = compiled
            assets: assets
        @_write_file(@appcache, content)

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
            unless module.url?
                Logger.error("No hosting rules for `#{module.relative}`")
        for module in @_modules
            source = fs.readFileSync(module.path)
            destination = @_get_copying(module.relative)
            unless destination? or @coding_func is "identity"
                throw new NoCopyingRuleError(module.relative)

            output = @calc_code(source)
            if destination?
                @_write_file(destination, output)
                Logger.info("Writing #{destination}.")
            module.hash = @calc_hash(output)
            module.size = output.length

        manifest_content = @_create_manifest()
        @_write_file(@manifest, manifest_content) if @manifest?
        @_write_index() if @index?
        @_write_appcache() if @appcache?
        @_print_stats()
        return manifest_content

    _print_stats: ->
        total = 0
        for num, module of @_modules
            total += module.size
            message = _.sprintf "%(num)3s %(module.relative)-20s %(module.size)7s %(module.type)4s %(module.hash)s",
                num: parseInt(num) + 1
                module: module
            Logger.info(message)
        Logger.info("Total #{total} bytes in #{@_modules.length} files")

hasBOM = (data) ->
    return false if data.length < 3
    return false unless data[0] is 0xef
    return false unless data[1] is 0xbb
    return false unless data[2] is 0xbf
    return true

load_json = (filepath) ->
    return unless filepath?
    source = fs.readFileSync(filepath)
    return JSON.parse(source)

load_yaml = (filepath) ->
    return unless filepath?
    data = fs.readFileSync(filepath)
    source = data.toString("utf8", if hasBOM(data) then 3 else 0)
    return yaml.safeLoad(source)
    
get_config_content = (filepath) ->
    switch path.extname(filepath)
        when ".yaml", ".yml"
            return load_yaml(filepath)
        when ".json"
            return load_json(filepath)

Builder.from_config = (config_path) ->
    Logger.info("Reading config from #{config_path}")
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
