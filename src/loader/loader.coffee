class AbstractMethodError extends Error
    constructor: (name) ->
        @name = "AbstractMethodError"
        @message = "Calling abstract method `#{name}` detected."

class UndeclaredRequireError extends Error
    constructor: (@self_name, @require_name) ->
        @name = "UndeclaredRequireError"
        @message = "Found unreserved attempt to require of `#{@require_name}` inside `#{@self_name}`"

class ChangesInWindowError extends Error
    constructor: (@self_name, @props) ->
        @name = "ChangesInWindowError"
        @message = "During `#{@self_name}` loading window object was polluted with: #{props}"

class DBError extends Error
    constructor: (@url, @error) ->
        @name = "DBError"
        @message = "Error #{@error} occured during loading of module #{@url}."

class NoSourceError extends Error
    constructor: (@url) ->
        @name = "NoSourceError"
        @message = "Module #{@url} source was not found in local database. Probably it was not loaded."

class ExportsViolationError extends Error
    constructor: (@self_name) ->
        @name = "ExportsViolationError"
        @message = "Modules `#{@self_name}` overrides own exports by replacing. `exports` != `module.exports`"

class ReturnPollutionError extends Error 
    constructor: (@self_name, @props) ->
        @name = "ReturnPollutionError"
        @message = "Code of `#{@self_name}` contains `return` statement in module scope."

class ThisPollutionError extends Error 
    constructor: (@self_name, @props) ->
        @name = "ThisPollutionError"
        @message = "Code of `#{@self_name}` trying to modify host object."

class AMDReturnsNothingError extends Error 
    constructor: (@self_name) ->
        @name = "AMDReturnsNothingError"
        @message = "AMD module `#{@self_name}` returns nothing. Should return empty object!"

class VersionMismatchedError extends Error 
    constructor: (@got, @expected) ->
        @name = "VersionMismatchedError"
        @message = "Invalid manifest version. Got: #{@got}. Expected: #{@expected}"

class HashFuncMismatchedError extends Error 
    constructor: (@got, @expected) ->
        @name = "HashFuncMismatchedError"
        @message = "Invalid manifest hash function. Got: #{@got}. Expected: #{@expected}"

class HashMismatchedError extends Error
    constructor: (@url, @got, @expected) ->
        @name = "HashMismatchedError"
        @message = "Downloaded from url `#{@url}` file has unexpected checksum hash. Got: #{@got}. Expected: #{@expected}"

waitAll = (array, reduce, map) ->
    items = array.concat()
    results = []
    received = []
    counter = 0
    items.forEach (item, index) ->
        map item, (result) ->
            counter++
            results[index] = result
            received[index] = true
            for i in [0..items.length-1]
                return if !received[i]
            return reduce(results)
        return
    return

XHR = -> new XMLHttpRequest()

class BasicEvaluator
    constructor: (options) ->
        @id = options.id
        @url = options.url
        @source = options.source
        @deps = options.dependencies
        @this = {}
        @window_props = []
        @window = @get_window()
        @errors = []
    render: ->  throw new AbstractMethodError("render")
    run: ->
        code = @render()
        func = new Function(code)
        result = func.call(this)
        @_check(result)
        return null if @errors.length > 0
        return @_make()
    get_window: ->
        WrapperType = -> return
        WrapperType.prototype = window
        wrapper = new WrapperType()
        @window_props = []
        for prop of window
            @window_props.push(prop)
            define_property = (prop) ->
                cell = 
                    value: window[prop]
                if typeof window[prop] is 'function'
                    Object.defineProperty wrapper, prop,
                        get: ->
                            return -> cell.value.apply(window, arguments)
                        set: (value) ->
                            cell.value = value
                else
                    Object.defineProperty wrapper, prop,
                        get: ->
                            return wrapper if window[prop] is window
                            return cell.value
                        set: (value) ->
                            if typeof value is 'function'
                                cell.value = -> value.apply(wrapper, arguments)
                            else
                                cell.value = value
                return
            define_property(prop)
        wrapper.addEventListener = (type, listener, useCapture) ->
            if 'message' is type
                wrap_listener = (originalListener) ->
                    return (event) ->
                        newEvent = document.createEvent('MessageEvent')
                        newEvent.initMessageEvent(
                            'message',
                            event.bubbles,
                            event.cancelable,
                            event.data,
                            event.origin,
                            event.lastEventId,
                            wrapper,
                            event.ports
                        )
                        originalListener(newEvent)
                listener = wrap_listener(listener)
            return window.addEventListener.call(window, type, listener, useCapture)
        return wrapper
    get_require: -> throw new AbstractMethodError("get_require")
    _fail: (reason) ->
        @errors.push(reason)
        throw reason
    _check: (result) -> throw new AbstractMethodError("_check")
    _check_window: (wrapper) ->
        added_props = (prop for prop of wrapper when prop not in @window_props)
        unless added_props.length == 0
            throw new ChangesInWindowError(@id, added_props)
        return
    _make: -> throw new AbstractMethodError("_make")
    get_require: ->
        require = (name) -> 
            if name not of @deps
                @_fail(new UndeclaredRequireError(@id, name)) 
            return @deps[name]
        return require.bind(this);

class CJSEvaluator extends BasicEvaluator
    constructor: (options) ->
        super(options)
        @module = {}
        @exports = {}
        @module.exports = @exports
        @require = @get_require()
        @process = 
            env: {}
        @deps["exports"] = @exports
        @deps["module"] = @module
        @deps["require"] = @require
    render: -> return """
        return (function(module, exports, require, window, process) { 
            #{@source}; 
        }).call(this.this, this.module, this.exports, this.require, this.window, this.process);
        \n//# sourceURL=#{@url}\n
        """
    _check: (result) ->
        @_check_window(@window)
        unless @exports is @module.exports or Object.keys(@exports).length == 0
            throw new ExportsViolationError(@id) 
        if result?
            throw new ReturnPollutionError(@id, Object.keys(result)) 
        this_keys = Object.keys(@this)
        unless this_keys.length == 0
            throw new ThisPollutionError(@id, this_keys) 
    _make: ->
        return @module.exports

class AMDEvaluator extends BasicEvaluator
    constructor: (options) ->
        super(options)
        @define = @get_define()
    render: -> return """
        return (function(define, window) { 
            #{@source}; 
        }).call(this.this, this.define, this.window);
        \n//# sourceURL=#{@url}\n
        """
    _check: (result) ->
        @_check_window(@window)
        if result?
            throw new ReturnPollutionError(@id, Object.keys(result)) 
        this_keys = Object.keys(@this)
        unless this_keys.length == 0
            throw new ThisPollutionError(@id, this_keys)

class NodepsAMDEvaluator extends AMDEvaluator
    get_define: ->
        define = (exports) ->
            @result = exports
        return define.bind(this);
    _make: ->
        return @result

class FactoryAMDEvaluator extends AMDEvaluator
    constructor: (options) ->
        super(options)
        @require = @get_require()
    get_define: ->
        define = (func) ->
            @result = func.call(this.this, @require)
        return define.bind(this)
    _check: (result) ->
        super(result)
        unless @result?
            throw new AMDReturnsNothingError(@id)
    _make: ->
        return @result

class REMAMDEvaluator extends AMDEvaluator
    constructor: (options) ->
        super(options)
        @module = {}
        @exports = {}
        @module.exports = @exports
        @require = @get_require()
    get_define: ->
        define = (func) ->
            @result = func.call(this.this, @require, @exports, @module)
        return define.bind(this)
    _check: (result) ->
        super(result)
        unless @exports is @module.exports or Object.keys(@exports).length == 0
            throw new ExportsViolationError(@id) 
        if @result?
            throw new ReturnPollutionError(@id, Object.keys(@result)) 
    _make: ->
        return @module.exports

class DepsAMDEvaluator extends AMDEvaluator
    constructor: (options) ->
        super(options)
        @module = {}
        @exports = {}
        @module.exports = @exports
        @require = @get_require()
        @deps["exports"] = @exports
        @deps["module"] = @module
        @deps["require"] = @require
    get_define: ->
        define = (names, func) ->
            deps = (@deps[name] for name in names)
            @result = func.apply(this.this, deps)
        return define.bind(this)
    _check: (result) ->
        super(result)
        if @result?
            unless Object.keys(@exports).length == 0
                throw new ExportsViolationError(@id) 
            unless @module.exports is null or Object.keys(@module.exports).length == 0
                throw new ExportsViolationError(@id)
        else
            unless @exports is @module.exports or Object.keys(@exports).length == 0
                throw new ExportsViolationError(@id)
            if @exports is @module.exports and Object.keys(@exports).length == 0
                throw new AMDReturnsNothingError(@id)
    _make: ->
        return @result if @result?
        return @module.exports        

class NamedAMDEvaluator extends DepsAMDEvaluator
    get_define: ->
        define = (own_name, names, func) ->
            deps = (@deps[name] for name in names)
            @result = func.apply(this.this, deps)
        return define.bind(this)

class PollutionEvaluator extends BasicEvaluator
    render: ->
        names = ["window"]
            .concat(name for name of @deps)
            .join(", ")

        args = ["this.this", "this.window"]
            .concat("this.deps[\"#{name}\"]" for name of @deps)
            .join(", ")

        return """
            return (function(#{names}) {
                #{@source};
            }).call(#{args});
            \n//# sourceURL=#{@url}\n
        """
    _check: (result) ->
        if result?
            throw new ReturnPollutionError(@id, Object.keys(result)) 
    get_window: -> 
        result = super()
        for name, value of @deps
            result[name] = value
        return result
    _make: ->
        result = {}
        for own name, value of @window
            result[name] = value
        for own name, value of @this
            result[name] = value
        return result

class RawEvaluator extends BasicEvaluator
    render: -> return """
        #{@source}
        \n//# sourceURL=#{@url}\n
    """
    _check: (result) ->
    get_window: -> return window
    _make: -> return {}

SAFE_CHARS = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'

class Logger
    constructor: (@prefix) ->

    info: (args...) ->
        console.info(@prefix, args...)

    warn: (args...) ->
        console.warn(@prefix, args...)

    error: (args...) ->
        console.error(@prefix, args...)

class Loader
    constructor: (options) ->
        @_all_modules = {}

        @_current_manifest = null

        @_update_started = false

        @_modules_to_load = []
        @_new_manifest = null
        @_total_size = 0

        @_stats = 
            evaluate_module_start: []
            evaluate_module_loaded_from_db: []
            update_module_start: []
            update_module_loaded_from_db: []
            evaluate_module_decoded: []

        @version = options.version
        @prefix = options.prefix
        @hash_name = options.hash_name
        @hash_func = options.hash_func
        @decoder_func = options.decoder_func
        @randomize_urls = options.randomize_urls
        @manifest_location = options.manifest_location ? "manifest.json"

        @options = options
        @logger = options.logger ? new Logger("LOADER:#{@prefix}") 

        @manifest_key = @prefix + "::manifest"
        localforage.config
            name: @prefix + "-db"

    _get_evaluator: (module) ->
        return switch module.type ? "cjs"
            when "cjs" then CJSEvaluator
            when "amd" then switch module.amdtype ? "deps"
                when "nodeps" then NodepsAMDEvaluator
                when "factory" then FactoryAMDEvaluator
                when "rem" then REMAMDEvaluator
                when "deps" then DepsAMDEvaluator
                when "named" then NamedAMDEvaluator
                else throw new TypeError("Invalid amd-type module `#{module.amdtype}`")
            when "junk" then PollutionEvaluator
            when "raw" then RawEvaluator
            else throw new TypeError("Invalid module type `#{module.type}`")

    _prepare_url: (url) ->
        return escape(url) unless @randomize_urls
        result = ''
        for i in [0..16]
            result += SAFE_CHARS[Math.round(Math.random() * (SAFE_CHARS.length - 1))]
        return escape(url) + '?' + result
    
    _parse_manifest: (content) ->
        throw ReferenceError("Manifest was not defined") unless content?
        raw = JSON.parse(content)
        throw TypeError("Invalid manifest format") unless raw instanceof Object
        throw TypeError("Invalid manifest format") unless raw.modules?
        throw new VersionMismatchedError(raw.version, @version) unless raw.version is @version
        throw new HashFuncMismatchedError(raw.hash_func, @hash_name) unless raw.hash_func is @hash_name

        manifest = 
            content: content
            modules: raw.modules
            version: raw.version
            hash_func: raw.hash_func
            hash: @hash_func(content)

        if raw.bundle?
            manifest.bundle = 
                hash: raw.bundle.hash
                url: raw.bundle.url

        return manifest

    get_manifest: ->
        return @_parse_manifest(window.localStorage.getItem(@manifest_key))

    set_manifest: (manifest) ->
        window.localStorage.setItem(@manifest_key, manifest.content)
        return

    del_manifest: ->
        window.localStorage.removeItem(@manifest_key)
        return

    make_key: (module) ->
        return @prefix + ":" + module.hash + ":" + module.url

    get_content: (key, cb) -> 
        return localforage.getItem(key, cb)

    set_content: (key, content, cb) ->
        @logger.info("storing", key)
        return localforage.setItem(key, content, cb)

    get_contents_keys: (cb) ->
        localforage.keys()
            .then (keys) =>            
                for key in keys
                    cb(key)
                return
            .catch (err) =>
                return @logger.error(err)
        return

    del_content: (key, cb) ->
        @logger.warn("removing", key)
        return localforage.removeItem(key, cb)

    onNoManifest: (error) ->
    onUpToDate: (event, manifest) ->
    onUpdateFound: (event, manifest) -> @startUpdate()
    onUpdateFailed: (event, error)-> 
    onUpdateCompleted: (manifest) -> return true
    onModuleBeginDownload: (module) -> 
    onModuleDownloadFailed: (event, module, error) -> 
    onModuleDownloadProgress: (event, module) -> 
    onTotalDownloadProgress: (progress) -> 
    onModuleDownloaded: (module) -> 
    onEvaluationStarted: (manifest) -> return true
    onEvaluationError: (module, error) -> 
    onModuleEvaluated: (module) -> 
    onApplicationReady: (manifest) -> @checkUpdate()

    emit: (name, args...) ->
        @logger.info(name, args...)
        try
            return this["on" + name](args...)
        catch error
            @logger.error(error)

    load: ->
        try
            @_current_manifest = @get_manifest()
        catch error
            @emit("NoManifest", error)
            return

        @logger.info("Current manifest", @_current_manifest)

        unless @emit("EvaluationStarted", @_current_manifest) is false
            @evaluate(@_current_manifest.modules)
                .then => @_cleanUp()

        return

    evaluate: (queue) ->
        @_stats.evaluate_module_start.push(new Date().getTime())
        
        queue = queue.concat()
        if queue.length is 0
            @emit("ApplicationReady", @_current_manifest)
            return

        module = queue.shift()
        key = @make_key(module)
        return @get_content(key)
            .then (module_source) =>
                @_stats.evaluate_module_loaded_from_db.push(new Date().getTime())
                
                unless module_source?
                    @emit("EvaluationError", module, new NoSourceError(module.url))
                    return

                try
                    #28 ISSUE. Decoder function could take module specific parameters, manifest specific parameters or ask for some cooperation
                    module.source = @decoder_func(module_source, module, this)
                catch error
                    @emit("EvaluationError", module, error)
                    return
                
                @_stats.evaluate_module_decoded.push(new Date().getTime())

                deps = {}
                for alias, dep of module.deps
                    deps[alias] = @_all_modules[dep]
                deps["loader"] = this

                evaluator_type = @_get_evaluator(module)
                evaluator = new evaluator_type
                    id: module.id
                    source: module.source
                    dependencies: deps
                    url: module.url

                try
                    namespace = evaluator.run()
                catch error
                    @emit("EvaluationError", module, error)
                    return

                @_all_modules[module.id] = namespace
                module.namespace = namespace

                @emit("ModuleEvaluated", module)

                return @evaluate(queue)
            .catch (err) =>
                @emit("EvaluationError", module, new DBError(module.url, err))
                return

    checkUpdate: () ->
        return false if @_update_started
        @logger.info("Checking for update...")
        manifest_request = XHR()
        manifest_request.open("GET", @_prepare_url(@manifest_location), true)
        manifest_request.overrideMimeType("application/json; charset=utf-8")
        manifest_request.onload = (event) =>
            if event.target.status is 404
                @emit("UpdateFailed", event, null)
                return
            try 
                @_new_manifest = @_parse_manifest(event.target.response)
            catch error
                @emit("UpdateFailed", event, error)
                return

            @logger.info("New manifest", @_new_manifest)
            if @_current_manifest?
                if @_current_manifest.hash == @_new_manifest.hash
                    @emit("UpToDate", event, @_current_manifest)
                    return

            @emit("UpdateFound", event, @_new_manifest)

        manifest_request.onerror = (event) =>
            @emit("UpdateFailed", event, null)
        manifest_request.onabort = (event) =>
            @emit("UpdateFailed", event, null)

        manifest_request.send()
        return true

    startUpdate: ->
        return false if @_update_started
        @logger.info("Starting update...")
        @_update_started = true
        for module in @_new_manifest.modules
            module.loaded = 0
        @_modules_to_load = @_new_manifest.modules.concat()
        if not @_current_manifest? and @_new_manifest.bundle?
            @_downloadBundle()
        else
            for module in @_modules_to_load.splice(0, 4)
                @_updateModule(module)
        return true

    dropData: ->
        @del_manifest()

    _downloadBundle: ->
        bundle = @_new_manifest.bundle
        bundle_request = XHR()
        bundle_request.open("GET", @_prepare_url(bundle.url), true)
        bundle_request.responseType = "arraybuffer"
        bundle_request.onload = (event) =>
            bundle_source = event.target.response
            hash = @hash_func(bundle_source)
            if hash != bundle.hash
                @emit("UpdateFailed", event, new HashMismatchedError(bundle.url, hash, bundle.hash))
                return

            @_disassembleBundle(bundle_source)
            return 

        bundle_request.onprogress = (event) =>
            total_size = 0
            total_count = 0
            for module in @_new_manifest.modules
                total_size += module.size
                total_count++
            progress = 
                loaded_count: 0
                total_count: total_count
                loaded_size: event.loaded
                total_size: total_size
            @emit("TotalDownloadProgress", progress)
        bundle_request.onerror = (event) =>
            @emit("UpdateFailed", event, null)
        bundle_request.onabort = (event) =>
            @emit("UpdateFailed", event, null)
        bundle_request.send()
        return

    _disassembleBundle: (bundle) ->
        @_modules_to_load
        pointer = 0
        for module in @_new_manifest.modules
            module_source = bundle.slice(pointer, pointer + module.size)
            hash = @hash_func(module_source)
            if hash != module.hash
                @emit("ModuleDownloadFailed", event, module, new HashMismatchedError(module.url, hash, module.hash))
                return
            module.source = module_source
            module.loaded = module.size
            pointer += module.size

        @_storeModule(@_modules_to_load.shift())

    _storeModule: (module) ->
        onNextModule = (module) => @_storeModule(module)
        @set_content(@make_key(module), module.source)
            .then (content) =>
                @emit("ModuleDownloaded", module)
                @_reportTotalProgress()
                @_checkAllUpdated(onNextModule)
                return
            .catch (err) =>
                @emit("ModuleDownloadFailed", null, module, new DBError(module.url, err))
                return

    _updateModule: (module) ->
        @_stats.update_module_start.push(new Date().getTime())
        key = @make_key(module)
        onNextModule = (module) => @_updateModule(module)
        onDownload = => @_checkAllUpdated(onNextModule)
        @get_content(key)
            .then (module_source) =>
                @_stats.update_module_loaded_from_db.push(new Date().getTime())
                return @_downloadModule(module, onDownload) unless module_source?
               
                if @hash_func(module_source) != module.hash
                    @emit("ModuleDownloadFailed", null, module, new HashMismatchedError(module.url, hash, module.hash))
                    return
                module.source = module_source
                module.loaded = module.size
                @emit("ModuleDownloaded", module)
                @_reportTotalProgress()
                @_checkAllUpdated(onNextModule)
                return
            .catch (err) =>
                return @_downloadModule(module, onDownload)
        return

    _reportTotalProgress: ->
        loaded_size = 0
        total_size = 0
        loaded_count = 0
        total_count = 0
        for module in @_new_manifest.modules
            total_size += module.size
            loaded_size += module.loaded
            total_count++
            if module.source?
                loaded_count++
        progress = 
            loaded_count: loaded_count
            total_count: total_count
            loaded_size: loaded_size
            total_size: total_size
        @emit("TotalDownloadProgress", progress)

    _downloadModule: (module, cb) ->
        @emit("ModuleBeginDownload", module)
        module_request = XHR()
        module_request.open("GET", @_prepare_url(module.url), true)
        module_request.responseType = "arraybuffer"
        module_request.onload = (event) =>
            module_source = event.target.response

            hash = @hash_func(module_source)
            if hash != module.hash
                @emit("ModuleDownloadFailed", event, module, new HashMismatchedError(module.url, hash, module.hash))
                return
            @set_content(@make_key(module), module_source)
                .then (content) =>
                    module.source = module_source
                    module.loaded = module.size
                    @emit("ModuleDownloaded", module)
                    @_reportTotalProgress()
                    cb()
                    return
                .catch (err) =>
                    @emit("ModuleDownloadFailed", null, module, new DBError(module.url, err))
                    return

        module_request.onprogress = (event) =>
            module.loaded = event.loaded
            @emit("ModuleDownloadProgress", event, module)
            @_reportTotalProgress()
        module_request.onerror = (event) =>
            @emit("ModuleDownloadFailed", event, module, null)
        module_request.onabort = (event) =>
            @emit("ModuleDownloadFailed", event, module, null)
        module_request.send()
        return

    _checkAllUpdated: (cb) ->
        next = @_modules_to_load.shift()
        if next?
            cb(next)
            return

        for module in @_new_manifest.modules
            return unless module.source?

        if @emit("UpdateCompleted", @_new_manifest)
            @set_manifest(@_new_manifest)
            @_current_manifest = @_new_manifest
            @_new_manifest = null
        @_update_started = false
        return

    _cleanUp: ->
        useful = (@make_key(module) for module in @_current_manifest.modules)
        useful.push(@manifest_key)
        @get_contents_keys (key) =>
            return unless key? # wierd error
            return unless key.indexOf(@prefix) is 0
            return if key in useful
            @del_content(key)
                .catch (error) => @logger.error(error) 
            return
        return
