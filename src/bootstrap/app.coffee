log = (args...) -> #loader.log("bootstrap", args...)

malfunction =
    start: ->
        @_timeout = setTimeout(@show.bind(this), 3000)

    stop: ->
        clearTimeout(@_timeout)

    reset: ->
        @stop()
        @start()

    show: ->
        $("#page-fail .error").text(@error)
        $("#loader .page").addClass("hide")
        $("#page-fail").removeClass("hide")
        
        $("#btn-retry").bind "click", (event) ->
            location.reload()

        $("#btn-force").bind "click", (event) ->
            loader.dropData()
            location.reload()

        return

    report: (@error) ->

malfunction.start()

loader.onNoManifest = (error) ->
    log("onNoManifest", error)

    loader.onUpdateFailed = (event, error) -> 
        log("onUpdateFailed", event, error)

        malfunction.report(error ? ("Error while downloading manifest file: " + event.target.statusText))
        $("#loader .page").addClass("hide")

    loader.onUpdateFound = (event, manifest) ->
        log("onUpdateFound", event, manifest)

        malfunction.reset()
        $("#loader .page").addClass("hide")
        $("#page-update").removeClass("hide")

        proto = $("#download-item-template")
        list = $("#page-update .items")
        for module in manifest.modules
            id = "module-" + module.id
            el = proto.clone().attr("id", id)
            el.find(".name").text(module.url)
            list.append(el)

        malfunction.report("Unknown error during update")
        loader.startUpdate()

    loader.onModuleBeginDownload = (module) -> 
        log("onModuleBeginDownload", module)

        malfunction.reset()
        el = $("#module-" + module.id)
        el.find(".state").addClass("hide")
        el.find(".progress").removeClass("hide")
        el.find(".bytes-loaded").text(0)
        el.find(".bytes-total").text(module.size)

    loader.onModuleDownloadFailed = (event, module, error) -> 
        log("onModuleDownloadFailed", event, module, error)

        message = event?.target?.statusText ? error

        malfunction.report(("Error while downloading module `#{module.id}` from url `#{module.url}`: " + message))
        el = $("#module-" + module.id)
        el.find(".state").addClass("hide")
        el.find(".error").text(message).removeClass("hide")

    loader.onModuleDownloadProgress = (event, module) -> 
        log("onModuleDownloadProgress", event, module)

        malfunction.reset()
        el = $("#module-" + module.id)
        el.find(".bytes-loaded").text(event.loaded)

    loader.onModuleDownloaded = (module) -> 
        log("onModuleDownloaded", module)

        malfunction.reset()
        el = $("#module-" + module.id)
        el.find(".state").addClass("hide")
        el.find(".success").removeClass("hide")

    loader.onTotalDownloadProgress = (progress) ->
        log(progress)

        malfunction.reset()
        $("#page-update .total-progress .modules-loaded").text(progress.loaded_count)
        $("#page-update .total-progress .modules-total").text(progress.total_count)
        $("#page-update .total-progress .bytes-loaded").text(progress.loaded_size)
        $("#page-update .total-progress .bytes-total").text(progress.total_size)

    loader.onUpdateCompleted = (manifest) -> 
        log("onUpdateCompleted", manifest)

        malfunction.reset()
        setTimeout(( -> location.reload() ), 0)
        return true

    loader.checkUpdate()

loader.onEvaluationStarted = (manifest) -> 
    log("onEvaluationStarted")

    malfunction.reset()
    $("#loader .page").addClass("hide")
    $("#page-load").removeClass("hide")

    proto = $("#evaluate-item-template")
    list = $("#page-load .items")
    for module in manifest.modules
        id = "module-" + module.id
        el = proto.clone().attr("id", id)
        el.find(".name").text(module.url)
        list.append(el)

    loader.onEvaluationError = (module, error) -> 
        log("onEvaluationError", module, error)

        malfunction.report(error)
        el = $("#module-" + module.id)
        el.find(".state").addClass("hide")
        el.find(".error").text(error).removeClass("hide")

    loader.onModuleEvaluated = (module) -> 
        log("onModuleEvaluated", module)

        malfunction.reset()
        el = $("#module-" + module.id)
        el.find(".state").addClass("hide")
        el.find(".success").removeClass("hide")

    loader.onApplicationReady = (manifest) ->
        log("onApplicationReady")

        malfunction.stop()
        @checkUpdate()

    malfunction.report("Unknown error occured while loading modules")
    return true