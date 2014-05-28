fs = require("fs")
path = require("path")
chai = require("chai")
_ = require("underscore")

chai.Assertion.addMethod 'properties', (expectedPropertiesObj) ->
    for own key, func of expectedPropertiesObj
        func.call(new chai.Assertion(this._obj).property(key))

chai.Assertion.addMethod "consist", (b) ->
    this.assert(_.isArray(this._obj), "Should be array")
    this.assert(this._obj.length == b.length, "Should be same size")
    ourB = b.concat()
    return this._obj.every (item) =>
        index = ourB.indexOf(item)
        if index < 0
            this.assert(false, "#{item} was not found in #{b}")
            return false
        else
            ourB.splice(index, 1)
            return true

mount = (target, name, dirname) ->
    dirname ?= name
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
