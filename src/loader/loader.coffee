class AbstractMethodError extends Error
    constructor: ->
        @name = "AbstractMethodError"
        @message = "Calling abstract method detected."

class UndeclaredRequireError extends Error
    constructor: (@self_name, @require_name) ->
        @name = "UndeclaredRequireError"
        @message = "Found unreserved attempt to require of `#{@require_name}` inside `#{@self_name}`"

class ChangesInWindowError extends Error
    constructor: (@self_name, @props) ->
        @name = "ChangesInWindowError"
        @message = "During `#{@self_name}` loading window object was polluted with: #{props}"

class NoSourceError extends Error
    constructor: (@key) ->
        @name = "NoSourceError"
        @message = "Module #{@key} source was not found in localStorage. Probably it was not loaded."

class ExportsViolationError extends Error
    constructor: (@self_name) ->
        @name = "ExportsViolationError"
        @message = ""

class ReturnPollutionError extends Error 
    constructor: (@self_name, @props) ->
        @name = "ReturnPollutionError"
        @message = ""

class ThisPollutionError extends Error 
    constructor: (@self_name, @props) ->
        @name = "ThisPollutionError"
        @message = ""

class AMDReturnsNothingError extends Error 
    constructor: (@self_name) ->
        @name = "AMDReturnsNothingError"
        @message = ""

XHR = ->
    try return new XMLHttpRequest()
    catch
    try return new ActiveXObject("Msxml3.XMLHTTP")
    catch
    try return new ActiveXObject("Msxml2.XMLHTTP.6.0")
    catch
    try return new ActiveXObject("Msxml2.XMLHTTP.3.0")
    catch
    try return new ActiveXObject("Msxml2.XMLHTTP")
    catch
    try return new ActiveXObject("Microsoft.XMLHTTP")
    catch
    return null

class BasicEvaluator
    constructor: (options) ->
        @id = options.id
        @source = options.source
        @deps = options.dependencies
        @this = {}
        @window = @get_window()
        @errors = []
    render: ->  throw new AbstractMethodError()
    run: ->
        func = new Function(@render())
        result = func.call(this)
        @_check(result)
        return null if @errors.length > 0
        return @_make()
    get_window: -> return __proto__: window
    get_require: -> throw new AbstractMethodError()
    _fail: (reason) ->
        @errors.push(reason)
        throw reason
    _check: (result) -> throw new AbstractMethodError()
    _make: -> throw new AbstractMethodError()

class CJSEvaluator extends BasicEvaluator
    constructor: (options) ->
        super(options)
        @module = {}
        @exports = {}
        @module.exports = @exports
        @require = @get_require()
    render: -> return """
        return (function(module, exports, require, window) { 
            #{@source}; 
        }).call(this.this, this.module, this.exports, this.require, this.window);
        """
    get_require: ->
        require = (name) -> 
            value = @deps[name]
            if not value?
                @_fail(new UndeclaredRequireError(@id, name)) 
            return value
        return require.bind(this);
    _check: (result) ->
        window_keys = Object.keys(@window)
        unless window_keys.length == 0
            throw new ChangesInWindowError(@id, window_keys) 
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
        """
    get_define: ->
        define = (names, func) ->
            deps = (@deps[name] for name in names)
            @result = func.apply(this.this, deps)
        return define.bind(this);
    _check: (result) ->
        window_keys = Object.keys(@window)
        unless window_keys.length == 0
            throw new ChangesInWindowError(@id, window_keys) 
        if result?
            throw new ReturnPollutionError(@id, Object.keys(result)) 
        this_keys = Object.keys(@this)
        unless this_keys.length == 0
            throw new ThisPollutionError(@id, this_keys)
        unless @result?
            throw new AMDReturnsNothingError(@id)
    _make: ->
        return @result

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
        """
    _check: (result) ->
        if result?
            throw new ReturnPollutionError(@id, Object.keys(result)) 
    get_window: -> 
        result = 
            __proto__: super()
        for name, value of @deps
            result[name] = value
        return __proto__: result
    _make: ->
        result = {}
        for own name, value of @window
            result[name] = value
        for own name, value of @this
            result[name] = value
        return result

class RawEvaluator extends BasicEvaluator
    render: -> return @source
    _check: (result) ->
    get_window: -> return window
    _make: -> return {}

class Storage
    get: (name) -> throw new AbstractMethodError()
    set: (name, value) -> throw new AbstractMethodError()

class Loader
    constructor: (options) ->
        @_all_modules = {}

        @_modules_running = []
        @_current_manifest = null

        @_update_started = false

        @_modules_in_update = []
        @_new_manifest = null
        @_total_size = 0
        @_loaded_sizes = {}

        @_evaluators =
            cjs: CJSEvaluator
            amd: AMDEvaluator
            junk: PollutionEvaluator
            raw: RawEvaluator

        @manifest_key = (LOADER_PREFIX ? "spa") + "::manifest"
    
    make_key: (module) ->
        return (LOADER_PREFIX ? "spa") + ":" + module.md5 + ":" + module.url

    get: (key) ->
        return window.localStorage.getItem(key)

    set: (key, value) ->
        @log("storing", key)
        window.localStorage.setItem(key, value)

    log: (args...) -> 
        console.log(args...)

    onUpdateFound: (event) -> 
        @log("onUpdateFound", arguments)
        @startUpdate()
    onUpToDate: -> 
        @log("onUpToDate", arguments)
    onUpdateFailed: -> 
        @log("onUpdateFailed", arguments)
    onUpdateCompletted: (event) -> 
        @log("onUpdateCompletted", arguments)
        return true

    onModuleBeginDownload: -> 
        @log("onModuleBeginDownload", arguments) 
    onModuleDownloaded: -> 
        @log("onModuleDownloaded", arguments) 
    onModuleDownloadFailed: -> 
        @log("onModuleDownloadFailed", arguments) 
    onModuleDownloadProgress: -> 
        @log("onModuleDownloadProgress", arguments) 
    onTotalDownloadProgress: -> 
        @log("onTotalDownloadProgress", arguments) 

    onEvaluationError: -> 
        @log("onEvaluationError", arguments)
    onApplicationReady: -> 
        @log("onApplicationReady", arguments)
        @checkUpdate()

    write_fake: ->
        manifest = JSON.parse(FAKE_MANIFEST)
        @set(@manifest_key, FAKE_MANIFEST)
        module = manifest[0]
        key = @make_key(module)
        @set(key, FAKE_APP)

    start: ->
        @_current_manifest = @get(@manifest_key)
        @log("Current manifest", @_current_manifest)
        unless @_current_manifest?
            @log("Writing fake application")
            @write_fake()
            @_current_manifest = @get(@manifest_key)

        @_cleanUp()

        @_modules_running = JSON.parse(@_current_manifest)
        for module in @_modules_running
            key = @make_key(module)
            module_source = @get(key)
            unless module_source?
                @onEvaluationError(new NoSourceError(key))

            module.source = module_source

            deps = {}
            for alias, dep of module.deps
                deps[alias] = @_all_modules[dep]
            deps["loader"] = this

            evaluator = new @_evaluators[module.type ? "cjs"]
                id: module.id
                source: module.source
                dependencies: deps

            try
                 @_all_modules[module.id] = evaluator.run()
            catch error
                 @onEvaluationError(error)
        @onApplicationReady()
        return

    checkUpdate: () ->
        return if @_update_started
        @log("Checking for update...")
        manifest_request = XHR()
        manifest_request.open("GET", "manifest.json", true)
        manifest_request.overrideMimeType("application/json; charset=utf-8")
        manifest_request.onload = (event) =>
            @_new_manifest = event.target.response;
            if @_current_manifest?
                if md5(@_current_manifest) == md5(@_new_manifest)
                    @onUpToDate()
                    return
            @onUpdateFound(event)
        manifest_request.onerror = (event) =>
            @onUpdateFailed(event)
        manifest_request.send()
        return

    startUpdate: ->
        @log("Starting update...")
        @_update_started = true
        @_modules_in_update = JSON.parse(@_new_manifest)
        @_total_size = 0
        for module in @_modules_in_update
            @_total_size += module.size
            @_loaded_sizes[module.id] = 0
        for module in @_modules_in_update
            @_updateModule(module)
        return

    _updateModule: (module) ->
        key = @make_key(module)
        module_source = @get(key)
        if module_source?
            module.source = module_source
            @onTotalDownloadProgress
                loaded: @_getLoadedSize()
                total: @_total_size 
            @_checkAllUpdated()
        else
            @_downloadModule(module)
        return

    _getLoadedSize: ->
        loaded_size = 0
        for name, size of @_loaded_sizes
            loaded_size += size
        return loaded_size

    _downloadModule: (module) ->
        @onModuleBeginDownload(module)
        module_request = XHR()
        module_request.open("GET", module.url, true)
        module_request.onload = (event) =>
            module_source = event.target.response
            if md5(module_source) != module.md5
                @onModuleDownloadFailed(module, event)
            key = @make_key(module)
            module.source = module_source
            @set(key, module_source)
            @_loaded_sizes[module.id] = module.size
            @onModuleDownloaded(event)
            @onTotalDownloadProgress
                loaded: @_getLoadedSize()
                total: @_total_size 
            @_checkAllUpdated()
        module_request.onprogress = (event) =>
            @_loaded_sizes[module.id] = event.loaded
            @onModuleDownloadProgress
                loaded: event.loaded
                total: module.size
            @onTotalDownloadProgress
                loaded: @_getLoadedSize()
                total: @_total_size 
        module_request.onerror = (event) =>
            @onModuleDownloadFailed(module, event)
        module_request.onabort = (event) =>
            @onModuleDownloadFailed(module, event)
        module_request.send()
        return

    _checkAllUpdated: ->
        for module in @_modules_in_update
            return unless module.source?
        if @onUpdateCompletted()
            @set(@manifest_key, @_new_manifest)
            @_current_manifest = @_new_manifest
            @_new_manifest = null
            @_cleanUp()
        @_update_started = false
        @_modules_in_update = []
        return

    _cleanUp: ->
        prefix = (LOADER_PREFIX ? "spa")
        modules = JSON.parse(@_current_manifest)
        useful = (@make_key(module) for module in modules)
        useful.push(@manifest_key)
        @log(useful)
        for i in [0..localStorage.length-1]
            key = localStorage.key(i)
            continue if key in useful
            @log("removing", key)
            localStorage.removeItem(key)
        return


window.onload = ->
    loader =  new Loader()
    loader.start()
    return true
