fs = require('fs')
walk = require('fs-walk')
path = require('path')
detective = require('detective')
resolve = require('resolve')
minimatch = require('minimatch')
crypto = require('crypto')
_  = require('underscore')
_.string =  require('underscore.string')
_.mixin(_.string.exports())

class Builder
    constructor: (options) ->
        @root = options.root
        @extensions = options.extensions
        @excludes = options.excludes
        @_clear()

    filter: (filepath) ->
        return false if not minimatch(filepath, @extensions, matchBase: true)
        return not _(@excludes).any (pattern) ->
            minimatch(filepath, pattern, matchBase: true)

    _clear: ->
        @_by_path = {}
        @_modules = {}
        @_by_id = {}

    _enlist: (root) ->
        walk.filesSync root, (basedir, filename, stat) =>
            filepath = path.join(basedir, filename)
            return if not @filter(filepath)

            module =
                path: filepath

            @_by_path[filepath] = module
            @_modules.push(module)

    _set_ids: ->
        for module in modules
            ext = path.extname(module.path)
            root = path.dirname(module.path)
            id = path.basename(module.path, ext)

            if id is "index"
                id = path.basename(root)
                root = path.dirname(root)

            while id in ids
                id = path.basename(root) + "|" + id
                root = path.dirname(root)

            @_by_id[id] = module
            module.id = id

    _analyze: (module) ->
        source = fs.readFileSync(filepath)
        module.md5 = crypto.createHash('md5').update(source).digest('hex');
        module.size = source.length
        module.local = []
        module.core = []
        module.external = []
        module.deps = []

        for dep in detective(source)
            try 
                resolved = resolve.sync(dep, basedir: basedir)
            catch
                continue
            if resolve.isCore(resolved)
                module.core.push(resolved)
            else if resolved in @by_path
                module.local.push(resolved)
                module.deps.push(@by_path[resolved].id)
            else
                module.external.push(resolved)

    build: () ->
        @_enlist(@root)
        @_set_ids()
        for module in @_modules
            @_analyze(module)


module.exports = Builder

builder = new Builder
    root: process.cwd()
    extensions: "*.js"
    excludes: [
        "**/node_modules/**"
    ]

console.log(builder.build())
