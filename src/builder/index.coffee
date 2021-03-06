fs = require('fs')
vm = require("vm")
walker = require('fs-walk-glob-rules')
globrules = require('glob-rules')
path = require('path')
clc = require('cli-color')
mkdirpSync = require('mkdirp').sync
detectiveCJS = require('detective')
detectiveAMD = require('detective-amd')
definition = require('module-definition').fromSource
amdType = require('get-amd-module-type').fromSource
yaml = require('js-yaml')
ejs = require("ejs")
_  = require('lodash')
_.string =  require('underscore.string')
_.mixin(_.string.exports())
crypto = require("crypto")
resolve = require("resolve")
console = require("./console")

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

class ModuleTypeError extends Error
    constructor: (@path, @error) ->
        @name = @constructor.name
        @message = "Can't determine type of module at `#{@path}`: #{@error?.toString()}"

class ModuleFileOverwritingError extends Error
    constructor: (@path) ->
        @name = @constructor.name
        @message = "Several modules are about to be wrote into `#{@path}`. Please revisit your `copying` rules."

class HostingUrlOverwritingError extends Error
    constructor: (@url) ->
        @name = @constructor.name
        @message = "Several modules are about to be hosted `#{@url}`. Please revisit your `hosting` rules."

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

class Logger
    constructor: (@prefix) ->

    info: (args...) ->
        console.info(args.join(" "))

    warn: (args...) ->
        console.warn(clc.bgYellow.bold(@prefix), clc.yellow(args.join(" ")))

    error: (args...) ->
        console.error(clc.bgRed.bold(@prefix), clc.red.bold(args.join(" ")))

class DB
    constructor: (@filename) ->
        if @filename? and fs.existsSync(@filename)
            @_data = JSON.parse(fs.readFileSync(@filename))
        else
            @_data = {}
    get: (key) ->
        content = @_data[key]
        if content?
            return JSON.parse(content)
    set: (key, value) -> 
        @_data[key] = JSON.stringify(value)
    del: (key) ->
        delete @_data[key]
    has: (key) ->
        return @_data.hasOwnProperty(key)
    flush: ->
        fs.writeFileSync(@filename, JSON.stringify(@_data))

sandbox = -> 
    window = {}
    window.window = window

    result = 
        ArrayBuffer: Object.freeze(ArrayBuffer)
        Buffer: Object.freeze(Buffer)
        Uint8Array: Object.freeze(Uint8Array)
        console: Object.freeze(console)
        window: Object.freeze(window)
        Uint32Array: Object.freeze(Uint32Array)

    return result

eval_file = (p, s) ->
    return vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, p), "utf8"), sandbox())

hashers = 
    md5: (data) -> crypto.createHash("md5").update(data).digest('hex')
    ripemd160: (data) -> crypto.createHash("ripemd160").update(data).digest('hex')
    sha1: (data) -> crypto.createHash("sha1").update(data).digest('hex')
    sha224: (data) -> crypto.createHash("sha224").update(data).digest('hex')
    sha256: (data) -> crypto.createHash("sha256").update(data).digest('hex')
    sha384: (data) -> crypto.createHash("sha384").update(data).digest('hex')
    sha512: (data) -> crypto.createHash("sha512").update(data).digest('hex')
    sha3: eval_file("./assets/hash/sha3.js")

encoders = 
    "aes-ccm": eval_file("./assets/encode/aes-ccm.js")
    "aes-gcm": eval_file("./assets/encode/aes-gcm.js")
    "aes-ocb2": eval_file("./assets/encode/aes-ocb2.js")

class Builder
    constructor: (options) ->
        @_built_ins = ["loader", "require", "module", "exports"]

        @options = options
        @options.logger ?= "SPA"
        if _.isString(options.logger)
            @logger = @_create_logger()
        else 
            @logger = options.logger
        @root = path.resolve(process.cwd(), options.root) + "/"
        @extensions = options.extensions ? [".js"]
        @excludes = options.excludes ? []
        @paths = options.paths ? {}
        @hosting = for pattern, template of options.hosting ? {}
            test: globrules.tester(pattern)
            transform: globrules.transformer(pattern, template)
        @hosting_map = options.hosting_map
        @copying = for pattern, template of options.copying ? {}
            test: globrules.tester(pattern)
            transform: globrules.transformer(pattern, template)
        @default_loader = options.default_loader ? "cjs"
        @loaders = for pattern, type of options.loaders ? {}
            test: globrules.tester(pattern)
            type: type
        @bundle = options.bundle
        @manifest = options.manifest
        @index = options.index
        @pretty = options.pretty ? false
        @grab = options.grab ? false
        @print_stats = options.print_stats ? true
        @print_roots = options.print_roots ? true
        @assets = 
            appcache_template: path.join(__dirname, "assets/appcache.tmpl")
            index_template: path.join(__dirname, "assets/index.tmpl")
        for own name, value of options.assets
            @assets[name] = value
        @appcache = options.appcache
        @cached = options.cached ? []
        @hash_func = options.hash_func ? "md5"
        @randomize_urls = options.randomize_urls ? true
        @coding_func = options.coding_func
        @cache = @_create_db(path.resolve(@root, options.cache_file ? ".spacache"))

    # ________________________________ UTILS _________________________________ #

    _create_db: (path) -> return new DB(path)
    _create_logger: (name) -> return new Logger(name)

    _filter: (filepath) ->
        expected = path.extname(filepath)
        return false unless _(@extensions).any (ext) -> expected is ext
        return true

    calc_hash: (content) -> 
        return hashers[@hash_func](content)

    encode: (content, module) ->
        encoder = encoders[@coding_func.name]
        return encoder(content, module, this)

    _relativate: (filepath) -> 
        return @walker.normalize(filepath)

    _get_copying: (filepath) ->
        for rule in @copying
            continue unless rule.test(filepath)
            return rule.transform(filepath)
        return

    _host_path: (relative)->
        for rule in @hosting
            continue unless rule.test(relative)
            return rule.transform(relative)

        @logger.error("No hosting rules for `#{relative}`")

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

    _get_type: (module, source) ->
        for rule in @loaders
            continue unless rule.test(module.relative)
            return rule.type
        try
            return switch definition(module.source)
                when "commonjs" then "cjs"
                when "amd" then "amd"
        catch error
            throw new ModuleTypeError(module.path, error)
        return @default_loader

    _resolve: (module, dep) ->
        for alias, prefix of @paths
            continue unless _.startsWith(dep, alias)
            if (dep[alias.length] || "/") is "/"
                dep = dep.replace(alias, prefix)
                break

        if _.startsWith(dep, "/")
            dep = path.join(@root, dep)
        else if _.startsWith(dep, "./") or _.startsWith(dep, "../")
            basedir = path.dirname(module.path)
            dep = path.resolve(basedir, dep)
        else
            try
                return resolve.sync dep,
                    basedir: path.dirname(module.path)
                    extensions: @extensions
            catch
                return null

        return @_resolve_to_file(dep) ? 
               @_resolve_to_file(dep + ".js") ? 
               @_resolve_to_directory(dep)

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

    _write_file: (destination, content) ->
        filepath = path.resolve(@root, destination)
        @logger.info("Writing #{filepath}. #{content.length} bytes.")
        mkdirpSync(path.dirname(filepath))
        fs.writeFileSync(filepath, content)

    _stringify_json: (data) ->
        return JSON.stringify(data, null, if @pretty then "  ")

    _inject_inline: (relative) ->
        filepath = path.resolve(__dirname, "assets", relative)
        return fs.readFileSync(filepath, encoding: "utf8")

    # _______________________________ STAGES _________________________________ #

    _clear: ->
        @_modules = []
        @_by_path = {}
        @_by_id = {}
        @_manifest_content = undefined
        @_index_content = undefined

    _enlist: () ->
        @walker = new walker.SyncWalker
            root: @root
            excludes: @excludes

        for data in @walker.walk() 
            continue unless @_filter(data.relative)
            module =
                path: data.path
                relative: data.relative

            @_by_path[data.path] = module
            @_modules.push(module)
        return

    _analyze: ->
        modules = @_modules.concat()
        while modules.length > 0
            module = modules.shift()
            source = fs.readFileSync(module.path)
            module.source = source.toString('utf8')
            module.deps_paths = {}
            module.type = @_get_type(module)
            switch module.type
                when "amd"
                    module.amdtype = amdType(module.source)
            module.source_hash = @calc_hash(source)
            module.source_length = source.length

            deps = switch module.type
                when "cjs" then detectiveCJS(module.source)
                when "amd" then detectiveAMD(module.source)
                else []

            #3 ISSUE. Add hardcoded dependencies from config here

            for dep in deps
                continue if dep in @_built_ins
                resolved = @_resolve(module, dep)
                unless resolved?
                    throw new UnresolvedDependencyError(module.relative, dep)
                module.deps_paths[dep] = resolved

                if @grab and not @_by_path[resolved]
                    submodule =
                        path: resolved
                        relative: @_relativate(resolved)

                    @_by_path[resolved] = submodule
                    @_modules.push(submodule)
                    modules.push(submodule)
        return

    _host: ->
        urls = {}
        for module in @_modules
            url = @_host_path(module.relative)
            continue unless url
            if url of urls #TODO: maybe better comparison will be needed
                throw new HostingUrlOverwritingError(url)

            urls[url] = module
            module.url = url
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

    _link: ->
        for module in @_modules
            module.deps_ids = {}
            for dep, resolved of module.deps_paths
                if @_by_path[resolved]?
                    module.deps_ids[dep] = @_by_path[resolved].id
                else
                    throw new ExternalDependencyError(module.relative, dep, resolved)

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

    _encode: ->
        _contents = []
        if @coding_func?
            paths = {}
            for module in @_modules
                destination = @_get_copying(module.relative)
                
                unless destination?
                    throw new NoCopyingRuleError(module.relative)
                
                if destination of paths #TODO: maybe better comparison will be needed
                    throw new ModuleFileOverwritingError(destination)

                paths[destination] = module

                source = fs.readFileSync(module.path)
                output = @encode(source, module)
                if @bundle
                    _contents.push(output)
                @_write_file(destination, output)
                module.hash = @calc_hash(output)
                module.size = output.length
        else
            for module in @_modules
                module.hash = module.source_hash
                module.size = module.source_length
                if @bundle
                    source = fs.readFileSync(module.path)
                    _contents.push(source)
        @_bundle_content = _contents.join("")
        return 

    _create_manifest: ->
        modules = for module in @_modules
            id: module.id
            url: module.url
            hash: module.hash
            size: module.size
            type: module.type
            amdtype: module.amdtype
            deps: module.deps_ids
            decoding: module.decoding

        @_manifest_content = 
            version: packagejson.version
            hash_func: @hash_func
            modules: modules

        if @bundle
            filepath = path.resolve(@root, @bundle)
            relative = @_relativate(filepath)
            url = @_host_path(relative)

            bundle = 
                hash: @calc_hash(new Buffer(@_bundle_content, "utf8"))
                url: url

            @_manifest_content.bundle = bundle

        if @coding_func?
            @_manifest_content.decoder_func = @coding_func.name

        return @_manifest_content

    _create_hosting_map: ->
        files = {}
        for module in @_modules
            files[module.url] = module.relative
        map =
            version: packagejson.version
            files: files

        if @bundle
            filepath = path.resolve(@root, @bundle)
            relative = @_relativate(filepath)
            url = @_host_path(relative)
            if url?
                map.bundle =
                    path: relative 
                    url: url

        if @manifest
            filepath = path.resolve(@root, @manifest)
            relative = @_relativate(filepath)
            url = @_host_path(relative)
            if url?
                map.manifest =
                    path: relative 
                    url: url

        if @index
            filepath = path.resolve(@root, @index)
            relative = @_relativate(filepath)
            url = @_host_path(relative)
            if url?
                map.index =
                    path: relative 
                    url: url

        if @appcache?
            filepath = path.resolve(@root, @appcache)
            relative = @_relativate(filepath)
            url = @_host_path(relative)
            if url?
                map.appcache =
                    path: relative 
                    url: url

        return map

    _create_index: ->
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
        namespace["decoder_name"] = if @coding_func? then @coding_func.name else "identity"
        namespace["passcode_required"] = @coding_func?

        if @manifest?
            filepath = path.resolve(@root, @manifest)
            relative = @_relativate(filepath)
            url = @_host_path(relative)
            if url?
                namespace["manifest_location"] = url
            else
                @logger.warn("Manifest file hosted as `#{relative}` and will be accesible relatively")

        if @appcache?
            filepath = path.resolve(@root, @appcache)
            relative = @_relativate(filepath)
            url = @_host_path(relative)
            if url?
                namespace["appcache_location"] = url
            else
                @logger.warn("AppCache manifest file location can't be automatically calculated for index.html")
            
        compiled = ejs.compile(assets["index_template"])
        @_index_content = compiled(namespace)
        return @_index_content

    _create_appcache: ->
        assets = {}
        for filename in @cached
            filepath = path.resolve(@root, filename)
            relative = @_relativate(filepath)
            url = @_host_path(relative)
            continue unless url?
            content = fs.readFileSync(filepath, encoding: "utf8")
            assets[url] = @calc_hash(content)
        if @index?
            filepath = path.resolve(@root, @index)
            relative = @_relativate(filepath)
            url = @_host_path(relative)
            if url?
                filename = path.resolve(@root, @index)
                assets[url] = @calc_hash(@_index_content)
        
        if Object.keys(assets).length == 0
            if @index?
                @logger.warn("No hosting rule for `#{@index}` file. AppCache manifest `#{@appcache}` appears to be empty")
            else
                @logger.warn("There are no assets to be included into AppCache manifest `#{@appcache}`")

        template = @assets["appcache_template"]
        compiled = ejs.compile(fs.readFileSync(template, encoding: "utf8"))
        content = compiled
            cached: assets
        return content

    _print_roots: ->
        all_deps = []
        for module in @_modules
            for dep_path, dep of module.deps_ids
                all_deps.push(dep)

        roots = []
        for module in @_modules
            continue if module.id in all_deps
            roots.push(module)

        return if roots.length == 0
        @logger.info("Possible roots: ")
        for num, module of roots
            message = _.sprintf "%(num)3s %(module.relative)s",
                num: parseInt(num) + 1
                module: module
            @logger.info(message)

    _print_stats: ->
        @logger.info("Statistics: ")
        total = 0
        for num, module of @_modules
            total += module.size
            message = _.sprintf "%(num)3s %(module.relative)-40s %(module.size)7s %(type)-11s %(module.hash)s",
                num: parseInt(num) + 1
                module: module
                type: if module.type == "amd" then module.type + "/" + module.amdtype else module.type
            @logger.info(message)
        @logger.info("Total #{total} bytes in #{@_modules.length} files")

    build: ->
        @_clear()
        @_enlist()
        @_analyze()
        @_host()
        @_set_ids()
        @_link()

        @_print_roots() if @print_roots

        @_sort()
        @_encode()

        @_write_file(@manifest, @_stringify_json(@_create_manifest())) if @manifest?
        @_write_file(@hosting_map, @_stringify_json(@_create_hosting_map())) if @hosting_map?
        @_write_file(@index, @_create_index()) if @index?
        @_write_file(@appcache, @_create_appcache()) if @appcache?
        @_write_file(@bundle, @_bundle_content) if @bundle?

        @_print_stats() if @print_stats
        @cache.flush()
        return @_manifest_content

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

# ________________________________ EXPORTS ___________________________________ #

Builder.from_config = (config_path, options) ->
    basedir = path.dirname(config_path)
    config = get_config_content(config_path)

    for own name, value of options ? {}
        config[name] = value

    config.root ?= "."
    config.root = path.resolve(basedir, config.root)
    return new Builder(config)

exports.Builder = Builder
exports.CyclicDependenciesError = CyclicDependenciesError
exports.UnresolvedDependencyError = UnresolvedDependencyError
exports.ExternalDependencyError = ExternalDependencyError
exports.ModuleTypeError = ModuleTypeError
exports.ModuleFileOverwritingError = ModuleFileOverwritingError
exports.HostingUrlOverwritingError = HostingUrlOverwritingError
exports.Loop = Loop
exports.Logger = Logger
exports.DB = DB
exports.hashers = hashers
exports.encoders = encoders
