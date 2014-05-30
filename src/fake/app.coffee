loader = require("loader")

loader.onUpdateCompleted = (event) -> 
    @log("onUpdateCompleted", arguments)
    setTimeout(location.reload.bind(location), 0)
    return true
