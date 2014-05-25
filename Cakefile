fs = require("fs")
path = require("path")
coffee = require("coffee-script")
uglify = require("uglify-js")
walk = require('fs-walk')
mkdirpSync = require('mkdirp').sync

preg_quote = (str, delimiter) ->
    return (str + '')
        .replace(new RegExp('[.\\\\+*?\\[\\^\\]${}=!<>:\\' + (delimiter || '') + '-]', 'g'), '\\$&')

globStringToRegex = (str) ->
    return new RegExp(
        preg_quote(str)
            .replace(/\\\*\\\*\//g, '(?:[^/]+/)*')
            .replace(/\\\*/g, '[^/]*')
            .replace(/\\\?/g, '[^/]')
        , 'm')

minify = (source) -> 
    ast = uglify.parse(source)
    ast.figure_out_scope()
    compressor = uglify.Compressor
        sequences     : true
        properties    : true
        dead_code     : true
        drop_debugger : true
        unsafe        : false
        conditionals  : true
        comparisons   : true
        evaluate      : true
        booleans      : true
        loops         : true
        unused        : true
        hoist_funs    : true
        hoist_vars    : false
        if_return     : true
        join_vars     : true
        cascade       : true
        side_effects  : true
        warnings      : true
        global_defs   : {}   

    compressed = ast.transform(compressor)
    minified = compressed.print_to_string()

    return minified

transform = (source, destination, func) -> 
    source = globStringToRegex(source)
    walk.filesSync ".", (basedir, filename, stat) =>
        filepath = path.join(basedir, filename)
        input = '/' + path.relative(".", filepath).split(path.sep).join('/')
        return unless source.test(input)
        output = input.replace(source, destination)
        result = fs.readFileSync(filepath, encoding: "utf8")
        result = func(input, output, result)
        outpath = path.join(".", output)
        mkdirpSync(path.dirname(outpath))
        fs.writeFileSync(outpath, result)

task "compile-builder", "compile builder coffee source into javascript", ->
    console.log("Compiling builder")
    transform "/src/builder/(**/*).coffee", "/lib/$1.js", (input, output, data) ->
        console.log("Compiling %s --> %s", input, output)
        return coffee.compile(data, bare: true)

task "compile-loader", "compile loader coffee source into javascript", ->
    console.log("Compiling loader")
    transform "/src/loader/(**/*).coffee", "/lib/assets/$1.js", (input, output, data) ->
        console.log("Compiling %s --> Minifying --> %s", input, output)
        result = coffee.compile(data, bare: true)
        return result#minify(result)

    transform "/src/fake/(**/*).coffee", "/lib/assets/fake/$1.js", (input, output, data) ->
        console.log("Compiling %s --> Minifying --> %s", input, output)
        result = coffee.compile(data, bare: true)
        return minify(result)

task "populate-assets", "prepare assets to be used by builder", ->
    transform "/bower_components/cryptojslib/rollups/(md5|sha1|sha224|sha256|sha3|sha384|sha512|ripemd160).js", "/lib/assets/hash/$1.js", (input, output, data) ->
        console.log("Copying %s --> %s", input, output)
        return data

    transform "/bower_components/localforage/dist/(localforage).min.js", "/lib/assets/$1.js", (input, output, data) ->
        console.log("Copying %s --> %s", input, output)
        return data

    transform "/src/builder/index.tmpl", "lib/assets/index.tmpl", (input, output, data) ->
        console.log("Copying %s --> %s", input, output)
        return data

    transform "/src/builder/appcache.tmpl", "lib/assets/appcache.tmpl", (input, output, data) ->
        console.log("Copying %s --> %s", input, output)
        return data

    console.log("Building fake manifest")
    Builder = require("./lib").Builder
    builder = new Builder
        root: "./lib/assets/fake"
        manifest: "manifest.json"
        hosting: 
            "/(*)": "fake://$1"
    builder.build()

task "build", "compile all coffeescript files to javascript", ->
    invoke 'compile-builder'
    invoke 'compile-loader'
    invoke 'populate-assets'

task "sbuild", "build routine for sublime", ->
    invoke 'build'

