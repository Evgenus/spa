log = (args...) ->
    loader.log("bootstrap", args...)

loader.onNoManifest = ->
    log("onNoManifest")

    loader.onTotalDownloadProgress = (progress) ->
        log(progress)
        $("#total-progress").text((progress.loaded_size / progress.total_size * 100) + "%")

    loader.onUpdateCompleted = (manifest) -> 
        log("onUpdateCompleted", manifest)
        setTimeout(location.reload.bind(location), 0)
        return true

    loader.onUpdateFound = (event, manifest) ->
        log("onUpdateFound", event, manifest)
        loader.startUpdate()

    loader.checkUpdate()

loader.onEvaluationStarted = (manifest) -> 
    log("onEvaluationStarted")

    loader.onApplicationReady = (manifest) ->
        log("onApplicationReady")
        $("#title-loading").addClass("hide")
        $("#title-done").removeClass("hide")
        @checkUpdate()

    # loader.onUpdateFound = (event, manifest) -> 
    #     @log("onUpdateFound", event, manifest)
    #     @startUpdate()

    # loader.onUpdateCompleted = (manifest) -> 
    #     log("onUpdateCompleted", manifest)
    #     return true

