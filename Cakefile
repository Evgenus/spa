fs = require("fs")
path = require("path")
coffee = require("coffee-script")
uglify = require("uglify-js")
walk = require('fs-walk')

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

copy = (input, output) ->
    result = fs.readFileSync(input)
    fs.writeFileSync(output, result)


task "compile-builder", "compile builder coffee source into javascript", ->
    root = "./src/builder"
    walk.filesSync root, (basedir, filename, stat) =>
        ext = path.extname(filename)
        return unless ext is ".coffee"
        input = path.resolve(basedir, filename)
        output = path.resolve(
            "./lib"
            path.relative(root, basedir)
            path.basename(filename, ext) + ".js"
            )
    
        console.log("Compiling %s --> %s", input, output)
        result = fs.readFileSync(input, encoding: "utf8")
        result = coffee.compile(result, bare: true)
        fs.writeFileSync(output, result)

task "compile-loader", "compile loader coffee source into javascript", ->
    root = "./src/loader"
    walk.filesSync root, (basedir, filename, stat) =>
        ext = path.extname(filename)
        return unless ext is ".coffee"
        input = path.resolve(basedir, filename)
        output = path.resolve(
            "./lib/assets"
            path.relative(root, basedir)
            path.basename(filename, ext) + ".js"
            )
    
        console.log("Compiling %s --> Minifying --> %s", input, output)
        result = fs.readFileSync(input, encoding: "utf8")
        result = coffee.compile(result, bare: true)
        result = minify(result)
        fs.writeFileSync(output, result)

    root = "./contrib"
    walk.filesSync root, (basedir, filename, stat) =>
        ext = path.extname(filename)
        return unless ext is ".js"
        input = path.resolve(basedir, filename)
        output = path.resolve(
            "./lib/assets"
            path.relative(root, basedir)
            path.basename(filename, ext) + ".js"
            )
    
        console.log("Compiling %s --> Minifying --> %s", input, output)
        result = fs.readFileSync(input, encoding: "utf8")
        result = minify(result)
        fs.writeFileSync(output, result)

task "build", "compile all coffeescript files to javascript", ->
    invoke 'compile-builder'
    invoke 'compile-loader'

task "sbuild", "build routine for sublime", ->
    invoke 'build'
