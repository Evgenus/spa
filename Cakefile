fs = require("fs")
path = require("path")
coffee = require("coffee-script")
uglify = require("uglify-js")
mkdirpSync = require('mkdirp').sync
sass = require('node-sass')
walker = require('fs-walk-glob-rules')
{exec} = require('child_process')

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
        warnings      : false
        negate_iife   : false
        global_defs   : {}   

    compressed = ast.transform(compressor)
    minified = compressed.print_to_string()

    return minified

minify_more = (source, comments) ->
    ast = uglify.parse(source)
    ast.figure_out_scope()
    ast.compute_char_frequency()
    ast.mangle_names()

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
        warnings      : false
        negate_iife   : false
        global_defs: {}

    compressed = ast.transform(compressor)
    minified = compressed.print_to_string
        bracketize    : true
        comments      : comments ? /License/

    return minified

write_file = (relative, data) ->
    outpath = path.join(".", relative) 
    mkdirpSync(path.dirname(outpath))
    fs.writeFileSync(outpath, data)

transform = (source, destination, func, excludes) -> 
    rules = {}
    rules[source] = destination
    walked = walker.transformSync
        root: "."
        rules: rules
        excludes: [
            "./node_modules/**",
            "./.git/**"
        ]

    for data in walked
        content = fs.readFileSync(data.path, encoding: "utf8")
        result = func(data.relative, data.result, content, data.match)
        if destination? and result?
            write_file(data.result, result)

task "compile-builder", "compile builder coffee source into javascript", ->
    console.log("Compiling builder")
    transform "./src/builder/(**/*).coffee", "./lib/$1.js", (input, output, data) ->
        console.log("Compiling %s --> %s", input, output)
        return coffee.compile(data, bare: true)

task "compile-loader", "compile loader coffee source into javascript", ->
    console.log("Compiling loader")
    transform "./src/loader/(**/*).coffee", "./lib/assets/$1.js", (input, output, data) ->
        console.log("Compiling %s --> Minifying --> %s", input, output)
        result = coffee.compile(data, bare: true)
        return minify(result)

    parts = [ # order of this files is important
        "./src/bootstrap/ui.coffee",
        "./src/bootstrap/app.coffee",
    ]
    out = []

    for part in parts
        console.log("Compiling %s -->", part)
        compiled = coffee.compile(fs.readFileSync(part, "utf8"), bare: true)
        out.push(compiled)

    bootstrap_path = "./lib/assets/bootstrap.js"
    bootstrap_data = out.join("")

    console.log("    --> Combining %s", bootstrap_path)
    write_file(bootstrap_path, bootstrap_data)

task "populate-assets", "prepare assets to be used by builder", ->

    cryptojs_hash = coffee.compile(fs.readFileSync("./src/assets/cryptojs-hash.coffee", "utf8"), bare: true)

    transform "./bower_components/cryptojslib/rollups/(md5|sha224|sha3|sha384|ripemd160).js", "./lib/assets/hash/$1.js", (input, output, data, match) ->

        console.log("Combining %s --> %s", input, output)
        hash_name = match[1]

        return minify_more("""
            (function() {
                #{data};
                var factory = #{cryptojs_hash};
                return factory("#{hash_name.toUpperCase()}");
            })();""")

    sjcl = fs.readFileSync("./bower_components/sjcl/core/sjcl.js", "utf8")
    bitArray = fs.readFileSync("./bower_components/sjcl/core/bitArray.js", "utf8")
    codecBytes = fs.readFileSync("./bower_components/sjcl/core/codecBytes.js", "utf8")
    codecString = fs.readFileSync("./bower_components/sjcl/core/codecString.js", "utf8")
    codecHex = fs.readFileSync("./bower_components/sjcl/core/codecHex.js", "utf8")

    sjcl_hash = coffee.compile(fs.readFileSync("./src/assets/sjcl-hash.coffee", "utf8"), bare: true)

    transform "./bower_components/sjcl/core/(sha1|sha256|sha512).js", "./lib/assets/hash/$1.js", (input, output, hash_func, match) ->

        console.log("Combining %s --> %s", input, output)
        hash_name = match[1]

        return minify_more("""
            (function() {
                #{sjcl};
                #{bitArray};
                #{codecBytes};
                #{codecString};
                #{codecHex};

                #{hash_func};
                var factory = #{sjcl_hash};
                return factory("#{hash_name}");
            })();""", /Copyright/)

    sjcl_identity = coffee.compile(fs.readFileSync("./src/assets/sjcl-identity.coffee", "utf8"), bare: true)

    console.log("Combining --> %s", "./lib/assets/cypher/identity.js")
    write_file("./lib/assets/decode/identity.js", minify_more("""
            (function() {
                #{sjcl};
                #{bitArray};
                #{codecBytes};
                #{codecString};

                var factory = #{sjcl_identity};
                return factory();
            })();""", /Copyright/))

    aes = fs.readFileSync("./bower_components/sjcl/core/aes.js", "utf8")
    sha256 = fs.readFileSync("./bower_components/sjcl/core/sha256.js", "utf8")
    hmac = fs.readFileSync("./bower_components/sjcl/core/hmac.js", "utf8")
    pbkdf2 = fs.readFileSync("./bower_components/sjcl/core/pbkdf2.js", "utf8")
    random = fs.readFileSync("./bower_components/sjcl/core/random.js", "utf8")

    #28 ISSUE. Here you could build additional decoders for compression or encryption

    sjcl_encoder = coffee.compile(fs.readFileSync("./src/assets/sjcl-encoder.coffee", "utf8"), bare: true)

    transform "./bower_components/sjcl/core/(ccm|ocb2|gcm).js", "./lib/assets/encode/aes-$1.js", (input, output, block_mode, match) ->

        console.log("Combining %s --> %s", input, output)
        mode_name = match[1]

        return minify_more("""
            (function() {
                #{sjcl};
                #{bitArray};
                #{codecBytes};
                #{codecString};
                #{codecHex};

                #{aes};
                #{sha256};
                #{hmac};
                #{pbkdf2};
                #{random};

                #{block_mode};
                var factory = #{sjcl_encoder};
                return factory("#{mode_name}");
            })();""", /Copyright/)

    #28 ISSUE. Here you could build additional decoders for compression or encryption

    sjcl_decoder = coffee.compile(fs.readFileSync("./src/assets/sjcl-decoder.coffee", "utf8"), bare: true)

    transform "./bower_components/sjcl/core/(ccm|ocb2|gcm).js", "./lib/assets/decode/aes-$1.js", (input, output, block_mode, match) ->

        console.log("Combining %s --> %s", input, output)
        mode_name = match[1]

        return minify_more("""
            (function() {
                #{sjcl};
                #{bitArray};
                #{codecBytes};
                #{codecString};
                #{codecHex};

                #{aes};
                #{sha256};
                #{hmac};
                #{pbkdf2};

                #{block_mode};
                var factory = #{sjcl_decoder};
                return factory("#{mode_name}");
            })();""", /Copyright/)

    transform "./bower_components/localforage/dist/(localforage).min.js", "./lib/assets/$1.js", (input, output, data) ->
        console.log("Copying %s --> %s", input, output)
        return data

    transform "./src/builder/index.tmpl", "lib/assets/index.tmpl", (input, output, data) ->
        console.log("Copying %s --> %s", input, output)
        return data

    transform "./src/builder/appcache.tmpl", "lib/assets/appcache.tmpl", (input, output, data) ->
        console.log("Copying %s --> %s", input, output)
        return data

    transform "./src/bootstrap/style.scss", "lib/assets/bootstrap.css", (input, output, data) ->
        console.log("Compiling %s --> %s", input, output)
        sass.renderSync
            file: path.join('.', input)
            outputStyle: 'compressed'
            outFile: output
            success: (x) -> console.log("Success", x)
            error: console.log.bind(console)
        return

task "test", "run unittests", ->
    cmd = ["npm", "run", "test:unit:short"].join(" ")
    console.log(cmd)
    exec cmd, (err, stdout, stderr) ->
        console.log stdout + stderr

task "build", "compile all coffeescript files to javascript", ->
    invoke 'compile-builder'
    invoke 'compile-loader'
    invoke 'populate-assets'

task "sbuild", "build routine for sublime", ->
    invoke 'build'
    #invoke 'test'

