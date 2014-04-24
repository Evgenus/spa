class Exception
class AbstractMethodException extends Exception
class UndeclaredRequireException extends Exception
    constructor: (@self_name, @require_name) ->
class ChangesInWindowObjectException extends Exception
    constructor: (@self_name, @props) ->

class BasicLoader
    constructor: (options) ->
        @id = options.id
        @source = options.source
        @deps = options.dependencies
        @this = {}
        @window = @get_window()
        @errors = []
    render: ->  throw new AbstractMethodException()
    load: ->
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
    get_require: -> throw new AbstractMethodException()
    _fail: (reason) ->
        @errors.push(reason)
        throw reason
    _check: (result) -> throw new AbstractMethodException()
    _make: -> throw new AbstractMethodException()

class CJSLoader extends BasicLoader
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
                @_fail(new UndeclaredRequireException(@id, name)) 
            return value
        return require.bind(this);
    _check: (result) ->
        # assert window unchanged
        # assert exports empty or exports === module.exports
        # assert result === undefined
        # assert this empty
    _make: ->
        return @module.exports

class AMDLoader extends BasicLoader
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

class PollutionLoader extends BasicLoader
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
        for name in Object.keys(@window)
            result[name] = @window[name]
        for name in Object.keys(@this)
            result[name] = @this[value]
        return result

class Loader
    constructor: (options) ->


window.onload = ->
    env = new CJSLoader
        name: "user-code-cjs"
        source: document.getElementById("user-code-cjs").text
        dependencies:
            test: console
    env.load()
    module = env.load()
    module.greetings();

    env = new AMDLoader
        name: "user-code-amd"
        source: document.getElementById("user-code-amd").text
        dependencies:
            test: console
    module = env.load()
    module.greetings();

    env = new PollutionLoader
        name: "user-code-pollution"
        source: document.getElementById("user-code-pollution").text
        dependencies:
            test: console
    module = env.load()
    module.greetings();
