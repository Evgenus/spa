loader = require("loader")

loader.onUpdateCompletted = (event) -> 
    @log("onUpdateCompletted", arguments)
    setTimeout(( -> location.reload()), 0)
    return true
