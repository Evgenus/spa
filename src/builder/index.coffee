fs = require('fs')
walk = require('fs-walk')
path = require('path')
detective = require('detective')
crypto = require('crypto')
_  = require('underscore')
_.string =  require('underscore.string')
_.mixin(_.string.exports())

preg_quote = (str, delimiter) ->
    return (str + '')
        .replace(new RegExp('[.\\\\+*?\\[\\^\\]${}=!<>|:\\' + (delimiter || '') + '-]', 'g'), '\\$&')

globStringToRegex = (str) ->
    return new RegExp(
        preg_quote(str)
            .replace(/\\\*\\\*/g, '[^/]*(?:/[^/]+)*')
            .replace(/\\\*/g, '[^/]*')
            .replace(/\\\?/g, '[^/]')
        , 'm')

class Builder
    constructor: (options) ->
        @root = options.root
        @extensions = options.extensions
        @excludes = _(options.excludes).map(globStringToRegex)
        @paths = options.paths
        @hosting = for pattern, template of options.hosting
            pattern: globStringToRegex(pattern)
            template: template
        @_clear()

    filter: (filepath) ->
        return false if not _(@extensions).any((ext) -> path.extname(filepath) is ext)
        return not _(@excludes).any((pattern) -> pattern.test(filepath))

    _clear: ->
        @_modules = []
        @_by_path = {}
        @_by_id = {}

    _enlist: (root) ->
        walk.filesSync root, (basedir, filename, stat) =>
            filepath = path.join(basedir, filename)
            relative = '/' + path.relative(root, filepath).split(path.sep).join('/')

            return if not @filter(relative)

            module =
                path: filepath
                relative: relative

            @_by_path[filepath] = module
            @_modules.push(module)
        return

    _set_ids: ->
        for module in @_modules
            ext = path.extname(module.path)
            root = path.dirname(module.path)
            id = path.basename(module.path, ext)

            if id is "index"
                id = path.basename(root)
                root = path.dirname(root)

            while id of @_by_id
                id = path.basename(root) + "|" + id
                root = path.dirname(root)

            @_by_id[id] = module
            module.id = id
        return

    _resolve_to_file: (filepath) ->
        if fs.existsSync(filepath)
            stats = fs.statSync(filepath)
            if stats.isFile()
                return filepath
        return

    _resolve_to_directory: (dirpath) ->
        if fs.existsSync(dirpath)
            stats = fs.statSync(dirpath)
            if stats.isDirectory()
                return @_resolve_to_file(path.join(dirpath, "index.js"))
        return

    _resolve: (module, dep) ->
        for alias, prefix of @paths
            if _(dep).startsWith(alias)
                dep = dep.replace(alias, prefix)
                break

        if _(dep).startsWith("/")
            dep = path.join(@root, dep)
        else if _(dep).startsWith("./") or _(dep).startsWith("../")
            basedir = path.dirname(module.path)
            dep = path.resolve(basedir, dep)

        return @_resolve_to_file(dep) ? 
               @_resolve_to_file(dep + ".js") ? 
               @_resolve_to_directory(dep)

    _analyze: (module) ->
        source = fs.readFileSync(module.path)
        module.md5 = crypto.createHash('md5').update(source).digest('hex');
        module.size = source.length
        module.deps_paths = {}

        for dep in detective(source)
            resolved = @_resolve(module, dep)
            resolved = resolved?.split(path.sep).join('/')
            module.deps_paths[dep] = resolved
    
    _link: ->
        for module in @_modules
            module.deps_ids = {}
            for dep, resolved of module.deps_paths
                if @_by_path[resolved]?
                    module.deps_ids[dep] = @_by_path[resolved].id

    _host: (module) ->
        for rule in @hosting
            continue unless rule.pattern.test(module.relative)
            module.url = module.relative.replace(rule.pattern, rule.template)
            break
        return

    build: () ->
        @_enlist(@root)
        @_set_ids()
        for module in @_modules
            @_analyze(module)
        @_link()
        for module in @_modules
            @_host(module)
        return

module.exports = Builder

builder = new Builder
    root: path.resolve(process.cwd(), "./") 
    extensions: [".js"]
    excludes: [
        "**/node_modules/**"
        ]
    paths:
        "a1": "/module1/a"
    hosting:
        "/lib/(**/*.js)": "http://127.0.0.1:8010/$1"

builder.build()
console.log(builder._modules)
