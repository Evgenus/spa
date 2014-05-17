loader = require("loader")

loader.onUpdateCompletted = (event) -> 
    @log("onUpdateCompletted", arguments)
    setTimeout(location.reload.bind(location), 0)
    return true
