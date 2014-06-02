loader = require("loader")
$ = require("./ui")

loader.onUpdateCompleted = (manifest) -> 
    @log("onUpdateCompleted", manifest)
    setTimeout(location.reload.bind(location), 0)
    return true

loader.onApplicationReady = ->
    @log("onApplicationReady")
    $("#title-loading").addClass("hide")
    $("#title-done").removeClass("hide")
    @checkUpdate()
