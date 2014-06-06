log = (args...) ->
    loader.log("bootstrap", args...)

loader.onNoManifest = ->
    log("onNoManifest")

    loader.onUpdateFailed = (event, error)-> 
        log("onUpdateFailed", event, error)

        $("#loader .page").addClass("hide")
        $("#page-fail").removeClass("hide")
        $("#page-fail .error").text(error ? event.target.statusText)

    loader.onUpdateFound = (event, manifest) ->
        log("onUpdateFound", event, manifest)
        $("#loader .page").addClass("hide")
        $("#page-update").removeClass("hide")

        proto = $("#download-item-template")
        list = $("#page-update .items")
        for module in manifest.modules
            id = "module-" + module.id
            el = proto.clone().attr("id", id)
            el.find(".name").text(module.url)
            list.append(el)

        loader.startUpdate()

    loader.onModuleBeginDownload = (module) -> 
        log("onModuleBeginDownload", module)

        el = $("#module-" + module.id)
        el.find(".state").addClass("hide")
        el.find(".progress").removeClass("hide")
        el.find(".bytes-loaded").text(0)
        el.find(".bytes-total").text(module.size)

    loader.onModuleDownloadFailed = (event, module) -> 
        log("onModuleDownloadFailed", event, module)

        el = $("#module-" + module.id)
        el.find(".state").addClass("hide")
        el.find(".error").text(event.target.statusText).removeClass("hide")

    loader.onModuleDownloadProgress = (event, module) -> 
        log("onModuleDownloadProgress", event, module)

        el = $("#module-" + module.id)
        el.find(".bytes-loaded").text(event.loaded)

    loader.onModuleDownloaded = (module) -> 
        log("onModuleDownloaded", module)

        el = $("#module-" + module.id)
        el.find(".state").addClass("hide")
        el.find(".success").removeClass("hide")

    loader.onTotalDownloadProgress = (progress) ->
        log(progress)

        $("#page-update .total-progress .modules-loaded").text(progress.loaded_count)
        $("#page-update .total-progress .modules-total").text(progress.total_count)
        $("#page-update .total-progress .bytes-loaded").text(progress.loaded_size)
        $("#page-update .total-progress .bytes-total").text(progress.total_size)

    loader.onUpdateCompleted = (manifest) -> 
        log("onUpdateCompleted", manifest)
        setTimeout(location.reload.bind(location), 0)
        return true

    loader.checkUpdate()

loader.onEvaluationStarted = (manifest) -> 
    log("onEvaluationStarted")

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

        el = $("#module-" + module.id)
        el.find(".state").addClass("hide")
        el.find(".error").text(error).removeClass("hide")

    loader.onModuleEvaluated = (module) -> 
        log("onModuleEvaluated", module)

        el = $("#module-" + module.id)
        el.find(".state").addClass("hide")
        el.find(".success").removeClass("hide")

    loader.onApplicationReady = (manifest) ->
        log("onApplicationReady")
        @checkUpdate()

