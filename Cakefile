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
        transform part, null, (input, _, data) ->
            console.log("Compiling %s -->", input)
            result = coffee.compile(data, bare: true)
            out.push(result)
            return

    bootstrap_path = "./lib/assets/bootstrap.js"
    bootstrap_data = out.join("")

    console.log("    --> Combining %s", bootstrap_path)
    write_file(bootstrap_path, bootstrap_data)

task "populate-assets", "prepare assets to be used by builder", ->

    transform "./bower_components/cryptojslib/rollups/(md5|sha224|sha3|sha384|ripemd160).js", "./lib/assets/hash/$1.js", (input, output, data, match) ->

        console.log("    Combining %s --> %s", input, output)
        hash_name = match[1]

        return minify_more("""
            (function() {
                #{data};
                return (function(data) {
                    var wa;
                    if (data instanceof String || typeof data === "string") {
                        wa = CryptoJS.enc.Utf8.parse(data);
                    } else {
                        var words = [];
                        var array;
                        if (data instanceof ArrayBuffer) {
                            array = new Uint8Array(data);
                        } else if(data instanceof Buffer) {
                            array = data;
                        } else {
                            throw Error("invalid input type");
                        }
                        var len = array.length;
                        for (var i = 0; i < len; i++) {
                            words[i >>> 2] |= (array[i] & 0xff) << (24 - (i % 4) * 8);
                        }
                        wa = CryptoJS.lib.WordArray.create(words, len);
                    }
                    var hash = CryptoJS.algo["#{hash_name.toUpperCase()}"].create();
                    hash.update(wa);
                    return hash.finalize().toString(CryptoJS.enc.Hex);
                });
            })();""")

    sjcl = fs.readFileSync("./bower_components/sjcl/core/sjcl.js", "utf8")
    bitArray = fs.readFileSync("./bower_components/sjcl/core/bitArray.js", "utf8")
    codecBytes = fs.readFileSync("./bower_components/sjcl/core/codecBytes.js", "utf8")
    codecString = fs.readFileSync("./bower_components/sjcl/core/codecString.js", "utf8")
    codecHex = fs.readFileSync("./bower_components/sjcl/core/codecHex.js", "utf8")

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
                return (function(data) {
                    var input;

                    if(data instanceof String || typeof data === "string") {
                        input = sjcl.codec.utf8String.toBits(data);
                    } else if(data instanceof ArrayBuffer) {
                        var view = new Uint8Array(data);
                        input = sjcl.codec.bytes.toBits(view);
                    } else if(data instanceof Buffer) {
                        input = sjcl.codec.bytes.toBits(data);
                    } else {
                        throw Error("invalid input type");
                    }

                    return sjcl.codec.hex.fromBits(sjcl.hash.#{hash_name}.hash(input))
                });
            })();""", /Copyright/)

    console.log("Combining --> %s", "./lib/assets/cypher/identity.js")
    write_file("./lib/assets/decode/identity.js", """
            (function() {
                #{sjcl};
                #{bitArray};
                #{codecBytes};
                #{codecString};

                return (function(data) {
                    var output;

                    if(data instanceof String || typeof data === "string") {
                        output = data;
                    } else if(data instanceof ArrayBuffer) {
                        var view = new Uint8Array(data);
                        output = sjcl.codec.utf8String.fromBits(sjcl.codec.bytes.toBits(view));
                    } else if(data instanceof Buffer) {
                        output = sjcl.codec.utf8String.fromBits(sjcl.codec.bytes.toBits(data));
                    } else {
                        throw Error("invalid input type");
                    }

                    return output;
                });
            })();""")

    aes = fs.readFileSync("./bower_components/sjcl/core/aes.js", "utf8")
    sha256 = fs.readFileSync("./bower_components/sjcl/core/sha256.js", "utf8")
    hmac = fs.readFileSync("./bower_components/sjcl/core/hmac.js", "utf8")
    pbkdf2 = fs.readFileSync("./bower_components/sjcl/core/pbkdf2.js", "utf8")
    random = fs.readFileSync("./bower_components/sjcl/core/random.js", "utf8")

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

                return (function(data, password, p) {
                    var ct;
                    if(data instanceof ArrayBuffer) 
                    {
                        var view = new Uint8Array(data);
                        ct = sjcl.codec.bytes.toBits(view);
                    } 
                    else if(data instanceof Buffer)
                    {
                        ct = sjcl.codec.bytes.toBits(data);
                    } 

                    var salt = sjcl.codec.hex.toBits(p.salt);
                    var iv = sjcl.codec.hex.toBits(p.iv);
                    var key = sjcl.misc.pbkdf2(password, salt, p.iter).slice(0, p.ks / 32);
                    var prp = new sjcl.cipher.aes(key);
                    var auth = sjcl.codec.utf8String.toBits(p.auth);
                    var text = sjcl.mode.#{mode_name}.decrypt(prp, ct, iv, auth, p.ts);
                    return sjcl.codec.utf8String.fromBits(text);
                });
            })();""", /Copyright/)

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
                var MODE = "#{mode_name}";

                var encoder = function(data, password, p) 
                {
                    var msg;
                    if(data instanceof String || typeof data === "string") 
                    {
                        msg = sjcl.codec.utf8String.toBits(data);
                    }
                    else if(data instanceof ArrayBuffer) 
                    {
                        var view = new Uint8Array(data);
                        msg = sjcl.codec.bytes.toBits(view);
                    } 
                    else if(data instanceof Buffer)
                    {
                        msg = sjcl.codec.bytes.toBits(data);
                    }

                    p.cipher = "aes";
                    p.mode = MODE;
                    var iv = sjcl.random.randomWords(4, 0);
                    p.iv = sjcl.codec.hex.fromBits(iv);
                    var salt = sjcl.random.randomWords(2, 0);
                    p.salt = sjcl.codec.hex.fromBits(salt);
                    var key = sjcl.misc.pbkdf2(password, salt, p.iter).slice(0, p.ks / 32);
                    var auth = sjcl.codec.utf8String.toBits(p.auth);
                    var prp = new sjcl.cipher.aes(key);
                    var ct = sjcl.mode[MODE].encrypt(prp, msg, iv, auth, p.ts);
                    return new Buffer(sjcl.codec.bytes.fromBits(ct));
                }

                return (function(content, module, builder) {
                    var result = {
                        iter: builder.coding_func.iter,
                        ks: builder.coding_func.ks,
                        ts: builder.coding_func.ts,
                        auth: module.url,
                    };
                    var data = encoder(content, builder.coding_func.password, result);
                    module.decoding = result;
                    return data;
                });
            })();""", /Copyright/)

    #28 ISSUE. Here you could build additional decoders for compression or encryption

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
        sass.renderFile
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

