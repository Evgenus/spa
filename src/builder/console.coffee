silent = -> null

context = 
    enabled: null

setEnabled = (enabled) ->
    return if @enabled is enabled
    @enabled = enabled

    if @enabled
        @log = console.log.bind(console)
        @info = console.info.bind(console)
        @warn = console.warn.bind(console)
        @error = console.error.bind(console)
        @dir = console.dir.bind(console)
        @trace = console.trace.bind(console)
        @assert = console.assert.bind(console)
    else
        @log = silent
        @info = silent
        @warn = silent
        @error = silent
        @dir = silent
        @trace = silent
        @assert = silent

setEnabled.call(context, true)

exports.isEnabled = -> return context.enabled
exports.disable = -> setEnabled.call(context, false)
exports.enable = -> setEnabled.call(context, true)
exports.log = -> context.log.apply(context, arguments)
exports.info = -> context.info.apply(context, arguments)
exports.warn = -> context.warn.apply(context, arguments)
exports.error = -> context.error.apply(context, arguments)
exports.dir = -> context.dir.apply(context, arguments)
exports.trace = -> context.trace.apply(context, arguments)
exports.assert = -> context.assert.apply(context, arguments)
exports.setEnabled = setEnabled.bind(context)
