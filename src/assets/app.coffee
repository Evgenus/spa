loader = require("loader")
$ = require("./ui")

loader.onApplicationReady = ->
    @log("onApplicationReady")
    $("#title-loading").addClass("hide")
    $("#title-done").removeClass("hide")

    loader.onUpdateCompleted = (manifest) -> 
        @log("onUpdateCompleted", manifest)
        setTimeout(location.reload.bind(location), 0)
        return true

    loader.onTotalDownloadProgress = (progress) ->
        @log(progress)
        $("#total-progress").text((progress.loaded_size / progress.total_size * 100) + "%")

    @checkUpdate()
