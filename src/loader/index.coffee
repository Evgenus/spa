class AbstractMethodError extends Error
    constructor: ->
        @name = @constructor.name
        @message = "Calling abstract method detected."

class UndeclaredRequireError extends Error
    constructor: (@self_name, @require_name) ->
        @name = @constructor.name
        @message = "Found unreserved attempt to require of `#{@require_name}` inside `#{@self_name}`"

class ChangesInWindowError extends Error
    constructor: (@self_name, @props) ->
        @name = @constructor.name
        @message = "During `#{@self_name}` loading window object was polluted with: #{props}"

class NoSourceError extends Error
    constructor: (@module_md5, @module_url) ->
        @name = @constructor.name
        @message = "Module source with checksum of `#{@module_md5}` was not found in localStorage. Probably it was not loaded from #{module_url}."

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
        try 
            result = func.call(this)
        catch error
            console.log(error)
        
        try
            @_check(result)
        catch error 
            console.log(error)

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
        # assert window unchanged
        # assert exports empty or exports === module.exports
        # assert result === undefined
        # assert this empty
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
        # assert window unchanged
        # assert result is undefined
        # assert @result contains module
        # assert this empty
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
        # assert result is undefined
        # assert @result contains module
        # assert this empty
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

class Storage
    get: (name) -> throw new AbstractMethodError()
    set: (name, value) -> throw new AbstractMethodError()

class Loader
    constructor: (options) ->
        @_all_modules = {}
        @_modules_in_update = []
        @_update_started = false

    get: (name) ->
        return window.localStorage.getItem(name)

    set: (name, value) ->
        console.log("setting key", name)
        window.localStorage.setItem(name, value)

    onUpdateFound: (event) -> 
        console.log("onUpdateFound", arguments) # when downloaded manifest varies from found in localStorage
        @startUpdate()
    onUpToDate: -> console.log("onUpToDate", arguments) # when downloaded manifest equals to found in localStorage
    onUpdateFailed: -> console.log("onUpdateFailed", arguments) # when somehow it is impossible to download any file from the web
    onUpdateCompletted: (event) -> console.log("onUpdateCompletted", arguments) # when downloaded manifest varies from found in localStorage

    onModuleBeginDownload: -> console.log("onModuleBeginDownload", arguments) 
    onModuleDownloaded: -> console.log("onModuleDownloaded", arguments) 
    onModuleDownloadFailed: -> console.log("onModuleDownloadFailed", arguments) 
    onModuleDownloadProgress: -> console.log("onModuleDownloadProgress", arguments) 
    onTotalDownloadProgress: -> console.log("onTotalDownloadProgress", arguments) 

    onApplicationReady: -> console.log("onApplicationReady", arguments) 
    onEvaluationError: -> console.log("onEvaluationError", arguments) #last version of application can't be runned

    start: ->
        manifest_source = @get("spa::manifest")
        if manifest_source?
            manifest = JSON.parse(manifest_source)
            for module in manifest
                module_source = @get("spa:" + module.md5 + ":" + module.url)
                unless module_source?
                    @onEvaluationError(new NoSourceError(module.md5, module.url))
                    # no source found in localStorage

                deps = {}
                for alias, dep of module.deps
                    deps[alias] = @_all_modules[dep]

                evaluator = new CJSEvaluator
                    id: module.id
                    source: module_source
                    deps: deps

                try
                    @_all_modules[module.id] = evaluator.run()
                catch error
                    @onEvaluationError(error)
            @onApplicationReady()
            @checkUpdate(manifest_source)
        else
            @checkUpdate()

    checkUpdate: (current) ->
        return if @_update_started
        manifest_request = XHR()
        manifest_request.open("GET", "manifest.json", true)
        manifest_request.overrideMimeType("application/json; charset=utf-8")
        manifest_request.onload = (event) =>
            next = event.target.response;
            if current?
                if md5(current) == md5(next)
                    @onUpToDate()
                    return
            @_modules_in_update = JSON.parse(next)
            @onUpdateFound(event)

        manifest_request.onerror = (event) =>
            @onUpdateFailed(event)
        manifest_request.send()

    startUpdate: ->
        @_update_started = true
        for module in @_modules_in_update
            @_updateModule(module)

    _updateModule: (module) ->
        key = "spa:" + module.md5 + ":" + module.url
        module_source = @get(key)
        if module_source?
            module.content = module_source
            @onUpdateCompletted() if @_checkAllUpdated()
        else
            @_downloadModule(module)

    _downloadModule: (module) ->
        @onModuleBeginDownload(module)
        module_request = XHR()
        module_request.open("GET", module.url, true)
        module_request.onload = (event) =>
            module_source = event.target.response
            if md5(module_source) != module.md5
                @onModuleDownloadFailed(module, event)
            key = "spa:" + module.md5 + ":" + module.url
            @set(key, event.target.response)
            @onModuleDownloaded(event)
            module.content = module_source
            @onUpdateCompletted() if @_checkAllUpdated()
        module_request.onerror = (event) =>
            @oModuleDownloadFailed(module, event)
        module_request.send()

    _checkAllUpdated: ->
        for module in @_modules_in_update
            return false unless module.content?
        return true

window.onload = ->
    loader =  new Loader()
    loader.start()
