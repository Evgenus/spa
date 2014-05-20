fs = require("fs")
path = require("path")
chai = require("chai")

chai.Assertion.addMethod 'properties', (expectedPropertiesObj) ->
    for own key, func of expectedPropertiesObj
        func.call(new chai.Assertion(this._obj).property(key))

mount = (target, name, dirname) ->
    result = target[name] ?= {}
    for name in fs.readdirSync(dirname)
        continue if name is "."
        continue if name is ".."
        child = path.join(dirname, name)
        stats = fs.statSync(child)
        if stats.isDirectory()
            mount(result, name, child)
        if stats.isFile()
            result[name] = fs.readFileSync(child)
    return result

exports.mount = mount
