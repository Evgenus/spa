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

    get: (name) ->
        return window.localStorage[name]

    onModuleBeginDownload
    onModuleDownloaded
    onModuleDownloadProgress
    onTotalDownloadProgress
    onApplicationReady
    onEvaluationError

    _start: ->
        manifest_source = @get("spa:manifest")
        if manifest_source?
            manifest = JSON.parse(manifest_source)
            for module in manifest
                module_source = @get("spa:" + module.md5 + ":" + module.url)
                if module_source?
                    deps = {}
                    for alias, dep of module.deps
                        deps[alias] = @_all_modules[dep]

                    evaluator = new CJSEvaluator
                        id: module.id
                        source: module_source
                        deps: deps

                    @_all_modules[module.id] = evaluator.run()

                else
                    #module somehow was not loaded

        @checkUpdate()

    checkUpdate: ->

window.onload = ->
    loader =  new Loader()
    loader.start()
