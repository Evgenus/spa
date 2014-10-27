fs = require("fs")
mock = require("mock-fs")
yaml = require("js-yaml")
path = require("path")
expect = require("chai").expect
spa = require("../lib")
utils = require("./utils")
crypto = require("crypto")

beforeEach ->
    @old_cwd = process.cwd()
    process.chdir("/")

afterEach ->
    mock.restore()
    process.chdir(@old_cwd)

describe 'Building module with unknown dependency', ->

    base = ->
        it 'should report unresolved dependency', ->
            builder = spa.Builder.from_config("/testimonial/spa.yaml")
            
            expect(builder.build.bind(builder))
                .to.throw(spa.UnresolvedDependencyError)
                .that.deep.equals(new spa.UnresolvedDependencyError("./a.js", "/b"))

    describe 'in CommonJS format', ->
        base()
        beforeEach ->
            mock(yaml.safeLoad("""
                testimonial: 
                    a.js: |
                        var b = require("/b");
                    spa.yaml: |
                        root: "./"
                """))

    describe 'in AMD format', ->
        base()
        beforeEach ->
            mock(yaml.safeLoad("""
                testimonial: 
                    a.js: |
                        define(["/b"], function(b) {});
                    spa.yaml: |
                        manifest: manifest.json
                        root: "./"
                """))

describe 'Building module with external dependency', ->

    base = ->
        it 'should report dependency out of scope', ->
            builder = spa.Builder.from_config("/testimonial/spa.yaml")
            
            expect(builder.build.bind(builder))
                .to.throw(spa.ExternalDependencyError)
                .has.properties
                    alias: -> @equals("/b")
                    path: -> @equals("./a.js")

    describe 'in CommonJS format', ->
        base()
        beforeEach ->
            mock(yaml.safeLoad("""
                testimonial: 
                    a.js: |
                        var b = require("/b");
                    b.js: |
                        // empty
                    spa.yaml: |
                        root: "./"
                        excludes:
                            - ./b.js
                """))

    describe 'in AMD format', ->
        base()
        beforeEach ->
            mock(yaml.safeLoad("""
                testimonial: 
                    a.js: |
                        define(["/b"], function(b) {});
                    b.js: |
                        // empty
                    spa.yaml: |
                        root: "./"
                        excludes:
                            - ./b.js
                """))

describe 'Building module with cyclic dependencies', ->

    base = ->
        it 'should report loop in dependencies', ->
            builder = spa.Builder.from_config("/testimonial/spa.yaml")
            
            _loop = new spa.Loop()
                .prepend("./d.js", "/a")
                .prepend("./c.js", "/d")
                .prepend("./b.js", "/c")
                .prepend("./a.js", "/b")

            expect(builder.build.bind(builder))
                .to.throw(spa.CyclicDependenciesError)
                .to.have.property("loop")
                    .that.deep.equals(_loop)

    describe 'in CommonJS format', ->
        base()
        beforeEach ->
            mock(yaml.safeLoad("""
                testimonial:
                    a.js: |
                        var b = require("/b");
                    b.js: |
                        var c = require("/c");
                    c.js: |
                        var d = require("/d");
                    d.js: |
                        var a = require("/a");
                    spa.yaml: |
                        root: "./"
                """))

    describe 'in AMD format', ->
        base()
        beforeEach ->
            mock(yaml.safeLoad("""
                testimonial:
                    a.js: |
                        define(["/b"], function(b) {});
                    b.js: |
                        define(["/c"], function(c) {});
                    c.js: |
                        define(["/d"], function(d) {});
                    d.js: |
                        define(["/a"], function(a) {});
                    spa.yaml: |
                        root: "./"
                """))

describe 'Building module with cyclic dependencies and something else', ->

    base = ->
        it 'should report only loop', ->
            builder = spa.Builder.from_config("/testimonial/spa.yaml")
            
            _loop = new spa.Loop()
                .prepend("./e.js", "/c")
                .prepend("./d.js", "/e")
                .prepend("./c.js", "/d")

            expect(builder.build.bind(builder))
                .to.throw(spa.CyclicDependenciesError)
                .to.have.property("loop")
                    .that.deep.equals(_loop)

    describe 'in CommonJS format', ->
        base()
        beforeEach ->
            mock(yaml.safeLoad("""
                testimonial: 
                    a.js: |
                        // empty
                    b.js: |
                        var a = require("/a");
                    c.js: |
                        var d = require("/d");
                        var b = require("/b");
                    d.js: |
                        var e = require("/e");
                        var f = require("/f");
                        var b = require("/b");
                    e.js: |
                        var c = require("/c");
                        var f = require("/f");
                    f.js: |
                        var a = require("/a");
                    spa.yaml: |
                        root: "./"
                """))

    describe 'in AMD format', ->
        base()
        beforeEach ->
            mock(yaml.safeLoad("""
                testimonial: 
                    a.js: |
                        // empty
                    b.js: |
                        define(["/a"], function(a) {});
                    c.js: |
                        define(["/d", "/b"], function(d, b) {});
                    d.js: |
                        define(["/e", "/f", "/b"], function(e, f, b) {});
                    e.js: |
                        define(["/c", "/f"], function(c, f) {});
                    f.js: |
                        define(["/a"], function(a) {});
                    spa.yaml: |
                        root: "./"
                """))

describe 'Building module with paths rewired', ->

    base = (type) ->
        it 'should successfully build', ->
            builder = spa.Builder.from_config("/testimonial/spa.yaml")
            builder.build()

            expect(fs.existsSync("/testimonial/manifest.json")).to.be.true

            manifest = JSON.parse(fs.readFileSync("/testimonial/manifest.json", encoding: "utf8"))

            expect(manifest).to.have.properties
                modules: -> @that.is.an("Array").with.length(4).and.properties
                    0: -> @that.have.properties
                id: -> @that.equals("c")
                deps: -> @that.deep.equals({})
                type: -> @that.equals(type)
                url: -> @that.equals("http://127.0.0.1:8010/module1/a/c.js")
                    1: -> @that.have.properties
                id: -> @that.equals("b")
                deps: -> @that.deep.equals
                    "./a/c": "c"
                type: -> @that.equals(type)
                url: -> @that.equals("http://127.0.0.1:8010/module1/b.js")
                    2: -> @that.have.properties
                id: -> @that.equals("d")
                deps: -> @that.deep.equals
                    "a1/c": "c"
                type: -> @that.equals(type)
                url: -> @that.equals("http://127.0.0.1:8010/module2/d.js")
                    3: -> @that.have.properties
                id: -> @that.equals("e")
                deps: -> @that.deep.equals
                    "a1/../b": "b"
                type: -> @that.equals(type)
                url: -> @that.equals("http://127.0.0.1:8010/module2/e.js")

    describe 'in CommonJS format', ->
        base("cjs")
        beforeEach ->
            mock(yaml.safeLoad("""
                testimonial: 
                    module1:
                        a:
                            c.js: |
                                // because loader is like builtin for browser code
                                var loader = require("loader")
                        b.js: |
                            var ac = require("./a/c");
                    module2:
                        e.js: |
                            var a1 = require("a1/../b");
                        d.js: |
                            var a1 = require("a1/c");
                    spa.yaml: |
                        root: "/testimonial/"
                        extensions: 
                            - .js
                        paths:
                            a1: "/module1/a"
                        hosting:
                            "./(**/*.js)": "http://127.0.0.1:8010/$1"
                        manifest: "manifest.json"
                        default_loader: raw
                """))

    describe 'in AMD format', ->
        base("amd")
        beforeEach ->
            mock(yaml.safeLoad("""
                testimonial: 
                    module1:
                        a:
                            c.js: |
                                define([], function() {});
                        b.js: |
                            define(["./a/c"], function(ac) {});
                    module2:
                        e.js: |
                            define(["a1/../b"], function(a1) {});
                        d.js: |
                            define(["a1/c"], function(a1) {});
                    spa.yaml: |
                        root: "/testimonial/"
                        extensions: 
                            - .js
                        paths:
                            a1: "/module1/a"
                        hosting:
                            "./(**/*.js)": "http://127.0.0.1:8010/$1"
                        manifest: "manifest.json"
                        default_loader: raw
                """))

describe 'Building module without manifest', ->
    beforeEach ->
        mock(yaml.safeLoad("""
            testimonial: 
                a.js: // empty
                spa.yaml: |
                    root: "/testimonial/"
                    extensions: 
                        - .js
            """))

    it 'should not produce manifest.json', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        builder.build()

        expect(fs.existsSync("/testimonial/manifest.json")).not.to.be.true

describe 'Building config with BOM', ->
    beforeEach ->
        mock(yaml.safeLoad("""
            testimonial: 
                "a.js": // empty
            """))
        content = new Buffer("""\xEF\xBB\xBF\nroot: "/testimonial/"\nmanifest: "manifest.json"\n""", "ascii")
        fs.writeFileSync("/testimonial/spa.yaml", content)

    it 'should not produce manifest.json', ->
        content = fs.readFileSync("/testimonial/spa.yaml")
        expect(content[0]).to.equals(0xEF)
        expect(content[1]).to.equals(0xBB)
        expect(content[2]).to.equals(0xBF)

        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        builder.build()

        expect(fs.existsSync("/testimonial/manifest.json")).to.be.true

        manifest = JSON.parse(fs.readFileSync("/testimonial/manifest.json", encoding: "utf8"))

        expect(manifest).to.have.properties
            modules: -> @that.is.an("Array").with.length(1).and.properties
                0: -> @that.not.have.property("url")

describe 'Building module with wierd name', ->
    beforeEach ->
        mock(yaml.safeLoad("""
            testimonial: 
                "[^]$().'{}'+!=#$.js": // empty
                spa.yaml: |
                    root: "/testimonial/"
                    manifest: "manifest.json"
            """))

    it 'should not produce manifest.json', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        builder.build()

describe 'Building module with appcache and index', ->
    beforeEach ->
        system = yaml.safeLoad("""
            testimonial: 
                a.js: "//empty"
                b.js: "///empty"
                spa.yaml: |
                    root: "/testimonial/"
                    index: index.html
                    hash_func: md5
                    appcache: main.appcache
                    cached:
                        - a.js
                        - b.js
                    hosting:
                        "./(**/*.*)": "http://127.0.0.1:8010/$1"
            """)
        utils.mount(system, path.resolve(__dirname, "../lib/assets"))
        mock(system)

    it 'should produce appcache and index files', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        builder.build()

        expect(fs.existsSync("/testimonial/index.html")).to.be.true
        expect(fs.readFileSync("/testimonial/index.html", "utf8"))
            .to.include.string('manifest.json')

        expect(fs.existsSync("/testimonial/main.appcache")).to.be.true
        expect(fs.readFileSync("/testimonial/main.appcache", "utf8"))
            .to.include.string(crypto.createHash('md5').update("//empty").digest("hex"))
            .to.include.string('http://127.0.0.1:8010/a.js')
            .to.include.string(crypto.createHash('md5').update("///empty").digest("hex"))
            .to.include.string('http://127.0.0.1:8010/b.js')
            .to.include.string('http://127.0.0.1:8010/index.html')

describe 'Building renamed manifest', ->
    beforeEach ->
        system = yaml.safeLoad("""
            testimonial: 
                a.js: // empty
                spa.yaml: |
                    root: "/testimonial/"
                    index: index.html
                    manifest: "../spa-loader.json"
                    cached:
                        - a.js
                    hosting:
                        "./(**/*.*)": "http://127.0.0.1:8010/$1"
                        "./../(*.json)": "/$1"
            """)
        utils.mount(system, path.resolve(__dirname, "../lib/assets"))
        mock(system)

    it 'should produce index and manifest files', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        builder.build()

        expect(fs.existsSync("/testimonial/index.html")).to.be.true
        expect(fs.existsSync("/spa-loader.json")).to.be.true

        manifest = JSON.parse(fs.readFileSync("/spa-loader.json", encoding: "utf8"))

        expect(manifest).to.have.properties
            version: -> @to.be.a("String")
            modules: -> @to.be.an("Array").with.length(1).and.properties
                0: -> @that.have.properties
            id: -> @that.equals("a")
            deps: -> @that.deep.equals({})
            type: -> @that.equals("cjs")
            hash: -> @that.equals("1007f6da5acf8cc2643274276079bc3e")
            url: -> @that.equals("http://127.0.0.1:8010/a.js")

        expect(manifest).not.to.have.property("decoder_func")
        expect(manifest.modules[0]).not.to.have.property("decoding")

describe 'Building mixed-formats modules', ->
    beforeEach ->
        mock(yaml.safeLoad("""
            testimonial: 
                a.js: // empty
                b.js: |
                    var a = require("/a");
                c.js: |
                    define(["/b"], function(b) {});
                spa.yaml: |
                    root: "/testimonial/"
                    extensions: 
                        - .js
                    manifest: "manifest.json"
                    default_loader: junk
            """))

    it 'should successfully build', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        builder.build()

        expect(fs.existsSync("/testimonial/manifest.json")).to.be.true

        manifest = JSON.parse(fs.readFileSync("/testimonial/manifest.json", encoding: "utf8"))

        expect(manifest).to.have.properties
            modules: -> @that.is.an("Array").with.length(3).and.properties
                0: -> @that.have.properties
            id: -> @that.equals("a")
            deps: -> @that.deep.equals({})
            type: -> @that.equals("junk")
                1: -> @that.have.properties
            id: -> @that.equals("b")
            deps: -> @that.deep.equals
                "/a": "a"
            type: -> @that.equals("cjs")
                2: -> @that.have.properties
            id: -> @that.equals("c")
            deps: -> @that.deep.equals
                "/b": "b"
            type: -> @that.equals("amd")

        expect(manifest).to.have.properties
            modules: -> @that.have.properties
                0: -> @that.not.have.property("url")
                1: -> @that.not.have.property("url")
                2: -> @that.not.have.property("url")

describe 'Building module with different hash function', ->
    hashes = 
        md5: "1007f6da5acf8cc2643274276079bc3e"
        ripemd160: "9eb50257b88aaf4f2dea2ab99108fb631845ed51"
        sha1: "da03efe4b6962871b780b3bfd5794325d11ab193"
        sha224: "48125fcd2addc22961b026524fea1c56cf4e06c2be12e98bf1c971c0"
        sha256: "ebe41801037df7a354b168593f4545e58fd4a15dc7c2252cf5c0e7f5a799c048"
        sha384: "70b68b5fc3774ec4e7d68d4db2f71d81548a486687e5e1c46314a8e9e79d104f6b6c52f19b6629df3b1d300a0ce7e713"
        sha512: "333cbe76073d26fdb480d005e01ba2de20ed781ca38d9c1e25adb12d5f0cb92c5b2bfeaeb63b3ae72683aa28a809732dab4055273781f5f4a3af25105128a228"
        sha3: "c37785c2a1ad86b547ec92f840f19a6ea19db65ed02b7307f45ceca8b1882540240c07e5defa72d931c149578f5e48b0cb7d211b69dca14184560a19afd46441"
    
    test = (hash_name, hash_value) ->
        it """should compute valid `#{hash_name}` hash""", ->
            mock(yaml.safeLoad("""
                testimonial: 
                    a.js: // empty
                    spa.yaml: |
                        root: "/testimonial/"
                        manifest: "manifest.json"
                        hash_func: #{hash_name}
                        hosting:
                            "./(**/*.*)": "http://127.0.0.1:8010/$1"
                """))
            builder = spa.Builder.from_config("/testimonial/spa.yaml")
            builder.build()
            expect(fs.existsSync("/testimonial/manifest.json")).to.be.true
            manifest = JSON.parse(fs.readFileSync("/testimonial/manifest.json", encoding: "utf8"))

            expect(manifest.modules[0]).to.have.properties
                id: -> @that.equals("a")
                hash: -> @that.equals(hash_value)

    for hash_name, hash_value of hashes
        test(hash_name, hash_value)

describe 'Building with encoder', ->
    beforeEach ->
        system = yaml.safeLoad("""
            build:
                placeholder.txt: empty
            testimonial: 
                d.js: |
                    module.exports = function() 
                    {
                        return "d";
                    };
                c.js: |
                    var d = require("./d.js"); 
                    module.exports = function() 
                    { 
                        return "c" + d(); 
                    };
                b.js: |
                    var c = require("./c.js");
                    module.exports = function() 
                    {
                        return "b" + c();
                    };
                a.js: |
                    var b = require("./b.js");
                    module.exports = function() 
                    {
                        return "a" + b();
                    };
                spa.yaml: |
                    pretty: true
                    root: "/testimonial/"
                    manifest: "manifest.json"
                    hosting:
                        "./../build/bundle.js": "http://127.0.0.1:8010/bundle.js"
                        "./(**/*.*)": "http://127.0.0.1:8010/$1"
                    bundle: "/build/bundle.js"
                    coding_func:
                        name: aes-gcm
                        password: babuka
                        iter: 1000
                        ks: 128
                        ts: 128
                    copying:
                        "./(**/*.*)": "/build/$1"
            """)
        utils.mount(system, path.resolve(__dirname, "../lib/assets"))
        mock(system)

    sandbox =
        ArrayBuffer: Object.freeze(ArrayBuffer)
        Buffer: Object.freeze(Buffer)
        Uint8Array: Object.freeze(Uint8Array)

    vm = require("vm")
    eval_file = (p) ->
        return vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, p), "utf8"), sandbox)

    decoder = eval_file("../lib/assets/decode/aes-gcm.js")

    it 'should manifest and encrypted files', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        builder.build()

        expect(fs.existsSync("/testimonial/manifest.json")).to.be.true

        manifest = JSON.parse(fs.readFileSync("/testimonial/manifest.json", encoding: "utf8"))

        expect(manifest)
            .to.have.property("decoder_func")
            .that.equals("aes-gcm")

        expect(fs.existsSync("/build/bundle.js")).to.be.true

        expect(fs.existsSync("/build/a.js")).to.be.true
        expect(fs.existsSync("/build/b.js")).to.be.true
        expect(fs.existsSync("/build/c.js")).to.be.true
        expect(fs.existsSync("/build/d.js")).to.be.true

        expect(manifest.bundle).to.have.properties
            url: -> @that.to.be.a("String").equals("http://127.0.0.1:8010/bundle.js")

        expect(manifest.modules[0].decoding).to.have.properties
            cipher: -> @that.to.be.a("String").equals("aes")
            mode: -> @that.to.be.a("String").equals("gcm")
            iter: -> @that.to.be.a("Number").that.equals(1000)
            ks: -> @that.to.be.a("Number").that.equals(128)
            ts: -> @that.to.be.a("Number").that.equals(128)
            auth: -> @that.to.be.a("String")
            salt: -> @that.to.be.a("String").with.length(16)
            iv: -> @that.to.be.a("String").with.length(32)

        loader =
            options:
                password: "babuka"

        expect(decoder(fs.readFileSync("/build/d.js"), manifest.modules[0], loader))
            .to.equal(fs.readFileSync("/testimonial/d.js", encoding: "utf8"))
        expect(decoder(fs.readFileSync("/build/c.js"), manifest.modules[1], loader))
            .to.equal(fs.readFileSync("/testimonial/c.js", encoding: "utf8"))
        expect(decoder(fs.readFileSync("/build/b.js"), manifest.modules[2], loader))
            .to.equal(fs.readFileSync("/testimonial/b.js", encoding: "utf8"))
        expect(decoder(fs.readFileSync("/build/a.js"), manifest.modules[3], loader))
            .to.equal(fs.readFileSync("/testimonial/a.js", encoding: "utf8"))

describe 'Building updates with encoding', ->
    beforeEach ->
        system = yaml.safeLoad("""
            build:
                placeholder.txt: empty
            testimonial: 
                a.js: module.exports = function() { return "a1"; };
                spa.yaml: |
                    pretty: true
                    root: "/testimonial/"
                    manifest: "manifest.json"
                    hosting:
                        "./(**/*.*)": "http://127.0.0.1:8010/$1"
                    coding_func:
                        name: aes-gcm
                        password: babuka
                        iter: 1000
                        ks: 128
                        ts: 128
                    copying:
                        "./(**/*.*)": "/build/$1"
            """)
        utils.mount(system, path.resolve(__dirname, "../lib/assets"))
        mock(system)

    it 'should manifest and encrypted files', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")

        builder.build()
        expect(fs.existsSync("/testimonial/manifest.json")).to.be.true
        manifest = JSON.parse(fs.readFileSync("/testimonial/manifest.json", encoding: "utf8"))
        hash1 = manifest.modules[0].hash

        expect(manifest)
            .to.have.property("decoder_func")
            .that.equals("aes-gcm")

        expect(fs.existsSync("/build/a.js")).to.be.true

        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        builder.build()
        manifest = JSON.parse(fs.readFileSync("/testimonial/manifest.json", encoding: "utf8"))
        hash2 = manifest.modules[0].hash

        expect(hash1).to.equal(hash2)

        fs.writeFileSync("/testimonial/a.js",  """module.exports = function() { return "a2"; };""");

        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        builder.build()
        manifest = JSON.parse(fs.readFileSync("/testimonial/manifest.json", encoding: "utf8"))
        hash3 = manifest.modules[0].hash

        expect(hash3).not.to.equal(hash2)

describe 'Building modules with syntax errors', ->
    beforeEach ->
        mock(yaml.safeLoad("""
            testimonial: 
                a.js: var 55;
                spa.yaml: |
                    root: "/testimonial/"
                    extensions: 
                        - .js
                    manifest: "manifest.json"
                    default_loader: junk
            """))

    it 'should successfully build', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")

        expect(builder.build.bind(builder))
            .to.throw(spa.ModuleTypeError)
            .that.has.property("path")
            .that.equals(path.resolve("/testimonial/a.js"))

describe 'Building modules with dependency from node_modules', ->
    beforeEach ->
        mock(yaml.safeLoad("""
            testimonial: 
                a.js: 
                    var m1 = require("m1");
                    var m2 = require("m2");
                    console.log(m1() + m2());
                node_modules:
                    m1:
                        node_modules:
                            m11:
                                other.js: //empty
                                index.js:
                                    module.exports = function() {
                                        return "m2";
                                    }
                        lib:
                            other.js: //empty
                            main.js:
                                var m11 = require("m11");
                                module.exports = function() {
                                    return "m1";
                                }
                        package.json: |
                            {
                                "name": "m1",
                                "main": "lib/main.js"
                            }
                    m2:
                        lib:
                            other.js: //empty
                            main.js:
                                module.exports = function() {
                                    return "m2";
                                }
                        package.json: |
                            {
                                "name": "m2",
                                "main": "lib/main.js"
                            }
                spa.yaml: |
                    pretty: true
                    root: "/testimonial/"
                    hosting:
                        "./(**/*.*)": "http://127.0.0.1:8010/$1"
                    extensions: 
                        - .js
                    excludes:
                        - "./node_modules/**"
                    manifest: "manifest.json"
                    grab: true
                    default_loader: junk
            """))

    it 'should successfully build', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")

        builder.build()
        expect(fs.existsSync("/testimonial/manifest.json")).to.be.true
        manifest = JSON.parse(fs.readFileSync("/testimonial/manifest.json", encoding: "utf8"))

        expect(manifest)
            .to.have.property('modules')
            .to.be.an("Array").with.length(4)

        expect(manifest.modules[0]).to.have.properties
            id: -> @that.equals("lib_main")
            deps: -> @that.deep.equals({})
            type: -> @that.equals("cjs")
            url: -> @that.equals("http://127.0.0.1:8010/node_modules/m2/lib/main.js")

        expect(manifest.modules[1]).to.have.properties
            id: -> @that.equals("m11")
            deps: -> @that.deep.equals({})
            type: -> @that.equals("cjs")
            url: -> @that.equals("http://127.0.0.1:8010/node_modules/m1/node_modules/m11/index.js")
        
        expect(manifest.modules[2]).to.have.properties
            id: -> @that.equals("main")
            deps: -> @that.deep.equals
                "m11": "m11"
            type: -> @that.equals("cjs")
            url: -> @that.equals("http://127.0.0.1:8010/node_modules/m1/lib/main.js")
        
        expect(manifest.modules[3]).to.have.properties
            id: -> @that.equals("a")
            deps: -> @that.deep.equals
                "m1": "main"
                "m2": "lib_main"
            type: -> @that.equals("cjs")
            url: -> @that.equals("http://127.0.0.1:8010/a.js")

describe 'Building modules with inexistent dependency from node_modules', ->
    beforeEach ->
        mock(yaml.safeLoad("""
            testimonial: 
                a.js: 
                    var m1 = require("m1");
                node_modules:
                    m1:
                        empty.txt: placeholder
                spa.yaml: |
                    pretty: true
                    root: "/testimonial/"
                    hosting:
                        "./(**/*.*)": "http://127.0.0.1:8010/$1"
                    extensions: 
                        - .js
                    excludes:
                        - "./node_modules/**"
                    manifest: "manifest.json"
                    grab: true
                    default_loader: junk
            """))

    it 'should report unresolved dependency', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")
            
        expect(builder.build.bind(builder))
            .to.throw(spa.UnresolvedDependencyError)
            .that.deep.equals(new spa.UnresolvedDependencyError("./a.js", "m1"))

describe 'Building modules with dependency from node_modules (multifile module)', ->
    beforeEach ->
        mock(yaml.safeLoad("""
            testimonial:
                lib: 
                    a.js: |
                        var b = require("b");
                node_modules:
                    b:
                        index.js: |
                            var c = require("./c");
                        c.js: |
                            module.exports = 1;
                spa.yaml: |
                    pretty: true
                    root: "/testimonial/"
                    hosting:
                        "./(**/*.*)": "http://127.0.0.1:8010/$1"
                    extensions: 
                        - .js
                    excludes:
                        - "./node_modules/**"
                    manifest: "manifest.json"
                    grab: true
                    default_loader: junk
            """))

    it 'should successfully build', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")

        builder.build()
        expect(fs.existsSync("/testimonial/manifest.json")).to.be.true
        manifest = JSON.parse(fs.readFileSync("/testimonial/manifest.json", encoding: "utf8"))
        
        expect(manifest)
            .to.have.property('modules')
            .to.be.an("Array").with.length(3)

        expect(manifest.modules[0]).to.have.properties
            id: -> @that.equals("c")
            deps: -> @that.deep.equals({})
            type: -> @that.equals("cjs")
            url: -> @that.equals("http://127.0.0.1:8010/node_modules/b/c.js")

        expect(manifest.modules[1]).to.have.properties
            id: -> @that.equals("b")
            deps: -> @that.deep.equals
                "./c": "c"
            type: -> @that.equals("cjs")
            url: -> @that.equals("http://127.0.0.1:8010/node_modules/b/index.js")
        
        expect(manifest.modules[2]).to.have.properties
            id: -> @that.equals("a")
            deps: -> @that.deep.equals
                "b": "b"
            type: -> @that.equals("cjs")
            url: -> @that.equals("http://127.0.0.1:8010/lib/a.js")


describe 'Building modules with dependency from node_modules (import from the deep)', ->
    beforeEach ->
        mock(yaml.safeLoad("""
            testimonial:
                lib: 
                    a.js: |
                        var b = require("b");
                node_modules:
                    b:
                        index.js: |
                            var c = require("c");
                        node_modules:
                            c:
                                index.js: |
                                    var d = require("d");
                                node_modules:
                                    d:
                                        index.js: |
                                            var e = require("e");
                    e:
                        index.js: |
                            module.exports = 1;
                spa.yaml: |
                    pretty: true
                    root: "/testimonial/"
                    hosting:
                        "./(**/*.*)": "http://127.0.0.1:8010/$1"
                    extensions: 
                        - .js
                    excludes:
                        - "./node_modules/**"
                    manifest: "manifest.json"
                    grab: true
                    default_loader: junk
            """))

    it 'should successfully build', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")

        builder.build()
        expect(fs.existsSync("/testimonial/manifest.json")).to.be.true
        manifest = JSON.parse(fs.readFileSync("/testimonial/manifest.json", encoding: "utf8"))
        
        expect(manifest)
            .to.have.property('modules')
            .to.be.an("Array").with.length(5)

        expect(manifest.modules[0]).to.have.properties
            id: -> @that.equals("e")
            deps: -> @that.deep.equals({})
            type: -> @that.equals("cjs")
            url: -> @that.equals("http://127.0.0.1:8010/node_modules/e/index.js")

        expect(manifest.modules[1]).to.have.properties
            id: -> @that.equals("d")
            deps: -> @that.deep.equals
                "e": "e"
            type: -> @that.equals("cjs")
            url: -> @that.equals("http://127.0.0.1:8010/node_modules/b/node_modules/c/node_modules/d/index.js")
        
        expect(manifest.modules[2]).to.have.properties
            id: -> @that.equals("c")
            deps: -> @that.deep.equals
                "d": "d"
            type: -> @that.equals("cjs")
            url: -> @that.equals("http://127.0.0.1:8010/node_modules/b/node_modules/c/index.js")
        
        expect(manifest.modules[3]).to.have.properties
            id: -> @that.equals("b")
            deps: -> @that.deep.equals
                "c": "c"
            type: -> @that.equals("cjs")
            url: -> @that.equals("http://127.0.0.1:8010/node_modules/b/index.js")
        
        expect(manifest.modules[4]).to.have.properties
            id: -> @that.equals("a")
            deps: -> @that.deep.equals
                "b": "b"
            type: -> @that.equals("cjs")
            url: -> @that.equals("http://127.0.0.1:8010/lib/a.js")

describe 'Remaping standart-like modules inside dependencies from node_modules', ->
    beforeEach ->
        mock(yaml.safeLoad("""
            testimonial: 
                a.js:
                    var uuid = require("node-uuid");
                    console.log(uuid.v4());
                node_modules:
                    node-uuid:
                        uuid.js:
                            var crypto = require("crypto");
                            module.exports.v4 = function(data) {
                                return "blah";
                            }                            
                        package.json: |
                            {
                                "name": "node-uuid",
                                "main": "./uuid.js"
                            }
                    crypto-replacement:
                        index.js: // blah
                spa.yaml: |
                    pretty: true
                    root: "/testimonial/"
                    hosting:
                        "./(**/*.*)": "http://127.0.0.1:8010/$1"
                    extensions: 
                        - .js
                    excludes:
                        - "./node_modules/**"
                    manifest: "manifest.json"
                    grab: true
                    default_loader: junk
                    paths:
                        crypto: "crypto-replacement"
            """))


    it 'should successfully build', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")

        builder.build()
        expect(fs.existsSync("/testimonial/manifest.json")).to.be.true
        manifest = JSON.parse(fs.readFileSync("/testimonial/manifest.json", encoding: "utf8"))

describe 'Hosting output', ->
    beforeEach ->
        mock(yaml.safeLoad("""
            testimonial: 
                a.js: 
                    var m1 = require("m1");
                    var m2 = require("m2");
                    console.log(m1() + m2());
                node_modules:
                    m1:
                        node_modules:
                            m11:
                                other.js: //empty
                                index.js:
                                    module.exports = function() {
                                        return "m2";
                                    }
                        lib:
                            other.js: //empty
                            main.js:
                                var m11 = require("m11");
                                module.exports = function() {
                                    return "m1";
                                }
                        package.json: |
                            {
                                "name": "m1",
                                "main": "lib/main.js"
                            }
                    m2:
                        lib:
                            other.js: //empty
                            main.js:
                                module.exports = function() {
                                    return "m2";
                                }
                        package.json: |
                            {
                                "name": "m2",
                                "main": "lib/main.js"
                            }
                spa.yaml: |
                    pretty: true
                    root: "/testimonial/"
                    hosting:
                        "./(**/*.*)": "$1"
                    hosting_map: "hosting.json"

                    extensions: 
                        - .js
                    excludes:
                        - "./node_modules/**"
                    grab: true
                    default_loader: junk
            """))

    it 'should output hosting structure', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")

        builder.build()
        expect(fs.existsSync("/testimonial/hosting.json")).to.be.true
        hosting = JSON.parse(fs.readFileSync("/testimonial/hosting.json", encoding: "utf8"))

        expect(hosting).to.have.properties
            version: -> @that.to.be.a("String")
            files: -> @that.to.deep.equal
                "node_modules/m2/lib/main.js": "./node_modules/m2/lib/main.js"
                "node_modules/m1/node_modules/m11/index.js": "./node_modules/m1/node_modules/m11/index.js"
                "node_modules/m1/lib/main.js": "./node_modules/m1/lib/main.js"
                "a.js": "./a.js"

describe 'Hosting output with encoder', ->
    beforeEach ->
        system = yaml.safeLoad("""
            build:
                placeholder.txt: empty
            testimonial: 
                d.js: |
                    module.exports = function() 
                    {
                        return "d";
                    };
                c.js: |
                    var d = require("./d.js"); 
                    module.exports = function() 
                    { 
                        return "c" + d(); 
                    };
                b.js: |
                    var c = require("./c.js");
                    module.exports = function() 
                    {
                        return "b" + c();
                    };
                a.js: |
                    var b = require("./b.js");
                    module.exports = function() 
                    {
                        return "a" + b();
                    };
                spa.yaml: |
                    pretty: true
                    root: "/testimonial/"
                    hosting:
                        "./(**/*.*)": "http://127.0.0.1:8010/$1"
                    hosting_map: "hosting.json"
                    coding_func:
                        name: aes-gcm
                        password: babuka
                        iter: 1000
                        ks: 128
                        ts: 128
                    copying:
                        "./(**/*.*)": "/build/$1"
            """)
        utils.mount(system, path.resolve(__dirname, "../lib/assets"))
        mock(system)

    it 'should output hosting structure', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")

        builder.build()
        expect(fs.existsSync("/testimonial/hosting.json")).to.be.true
        hosting = JSON.parse(fs.readFileSync("/testimonial/hosting.json", encoding: "utf8"))

        expect(hosting).to.have.properties
            version: -> @that.to.be.a("String")
            files: -> @that.to.deep.equal
                "http://127.0.0.1:8010/a.js": "./a.js"
                "http://127.0.0.1:8010/b.js": "./b.js"
                "http://127.0.0.1:8010/c.js": "./c.js"
                "http://127.0.0.1:8010/d.js": "./d.js"

describe.only 'Hosting output with bundle', ->
    beforeEach ->
        system = yaml.safeLoad("""
            testimonial: 
                d.js: |
                    module.exports = function() 
                    {
                        return "d";
                    };
                c.js: |
                    var d = require("./d.js"); 
                    module.exports = function() 
                    { 
                        return "c" + d(); 
                    };
                b.js: |
                    var c = require("./c.js");
                    module.exports = function() 
                    {
                        return "b" + c();
                    };
                a.js: |
                    var b = require("./b.js");
                    module.exports = function() 
                    {
                        return "a" + b();
                    };
                spa.yaml: |
                    pretty: true
                    root: "/testimonial/"
                    hosting:
                        "./(**/*.*)": "http://127.0.0.1:8010/$1"
                    hosting_map: "hosting.json"
                    manifest: "manifest.json"
                    index: "index.html"
                    bundle: "bundle.js"
            """)
        utils.mount(system, path.resolve(__dirname, "../lib/assets"))
        mock(system)

    it 'should output hosting structure', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")

        builder.build()

        expect(fs.existsSync("/testimonial/manifest.json")).to.be.true
        manifest = JSON.parse(fs.readFileSync("/testimonial/manifest.json", encoding: "utf8"))

        expect(manifest).to.have.properties
            modules: -> @that.to.be.an("Array").with.length(4).and.properties
                0: -> @that.to.have.properties
                    id: -> @that.equals("d")
                    deps: -> @that.deep.equals({})
                    type: -> @that.equals("cjs")
                    url: -> @that.equals("http://127.0.0.1:8010/d.js")
                1: -> @that.to.have.properties
                    id: -> @that.equals("c")
                    deps: -> @that.deep.equals
                        "./d.js": "d"
                    type: -> @that.equals("cjs")
                    url: -> @that.equals("http://127.0.0.1:8010/c.js")
                2: -> @that.to.have.properties
                    id: -> @that.equals("b")
                    deps: -> @that.deep.equals
                        "./c.js": "c"
                    type: -> @that.equals("cjs")
                    url: -> @that.equals("http://127.0.0.1:8010/b.js")
                3: -> @that.to.have.properties
                    id: -> @that.equals("a")
                    deps: -> @that.deep.equals
                        "./b.js": "b"
                    type: -> @that.equals("cjs")
                    url: -> @that.equals("http://127.0.0.1:8010/a.js")
            bundle: -> @that.to.have.properties
                hash: -> @that.equals("e260fa41f30a6999b14fcd135cb93b0d")
                url: -> @that.equals("http://127.0.0.1:8010/bundle.js")

        expect(fs.existsSync("/testimonial/hosting.json")).to.be.true
        hosting = JSON.parse(fs.readFileSync("/testimonial/hosting.json", encoding: "utf8"))

        expect(hosting).to.have.properties
            version: -> @that.to.be.a("String")
            files: -> @that.to.deep.equal
                "http://127.0.0.1:8010/a.js": "./a.js"
                "http://127.0.0.1:8010/b.js": "./b.js"
                "http://127.0.0.1:8010/c.js": "./c.js"
                "http://127.0.0.1:8010/d.js": "./d.js"
            bundle: -> @that.to.deep.equal
                url: "http://127.0.0.1:8010/bundle.js"
                path: "./bundle.js"
            manifest: -> @that.to.deep.equal
                url: "http://127.0.0.1:8010/manifest.json"
                path: "./manifest.json"
            index: -> @that.to.deep.equal
                url: "http://127.0.0.1:8010/index.html"
                path: "./index.html"

describe 'Building updates with encoding and ambiguous copying', ->
    beforeEach ->
        system = yaml.safeLoad("""
            build:
                placeholder.txt: empty
            testimonial: 
                a.js: module.exports = function() { return "a1"; };
                b.js: module.exports = function() { return "b1"; };
                spa.yaml: |
                    pretty: true
                    root: "/testimonial/"
                    manifest: "manifest.json"
                    hosting:
                        "./(**/*.*)": "http://127.0.0.1:8010/$1"
                    coding_func:
                        name: aes-gcm
                        password: babuka
                        iter: 1000
                        ks: 128
                        ts: 128
                    copying:
                        "./a.js": "/build/file.js"
                        "./b.js": "/build/file.js"
            """)
        utils.mount(system, path.resolve(__dirname, "../lib/assets"))
        mock(system)

    it 'should manifest and encrypted files', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")

        expect(builder.build.bind(builder))
            .to.throw(spa.ModuleFileOverwritingError)
            .that.deep.equals(new spa.ModuleFileOverwritingError("/build/file.js"))

describe 'Building modules with ambiguous hosting', ->
    beforeEach ->
        system = yaml.safeLoad("""
            testimonial: 
                a.js: // empty
                b.js: // empty
                spa.yaml: |
                    root: "/testimonial/"
                    index: index.html
                    appcache: main.appcache
                    hosting:
                        "./a.js": "http://127.0.0.1:8010/file.js"
                        "./b.js": "http://127.0.0.1:8010/file.js"
            """)
        utils.mount(system, path.resolve(__dirname, "../lib/assets"))
        mock(system)

    it 'should produce appcache and index files', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")

        expect(builder.build.bind(builder))
            .to.throw(spa.HostingUrlOverwritingError)
            .that.deep.equals(new spa.HostingUrlOverwritingError("http://127.0.0.1:8010/file.js"))

describe 'fix for #65: remapping modules should not affect modules which are extensions to this module', ->
    beforeEach ->
        system = yaml.safeLoad("""
            testimonial: 
                k.js: |
                    require("a");
                    require("a/b");
                    require("ac");
                    require("ac/b");
                node_modules:
                    ac:
                        index.js: // empty
                        b.js: //empty
                    ab:
                        index.js: // empty 
                        b.js: //empty
                spa.yaml: |
                    root: "/testimonial/"
                    manifest: "manifest.json"
                    grab: true
                    excludes:
                        - "./node_modules/**"
                    paths:
                        a: ab
            """)
        utils.mount(system, path.resolve(__dirname, "../lib/assets"))
        mock(system)

    it 'should successfully build', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")

        builder.build()
        expect(fs.existsSync("/testimonial/manifest.json")).to.be.true
        manifest = JSON.parse(fs.readFileSync("/testimonial/manifest.json", encoding: "utf8"))
        
        expect(manifest)
            .to.have.property('modules')
            .to.be.an("Array").with.length(5)

        expect(manifest.modules[0]).to.have.properties
            id: -> @that.equals("ab")
            deps: -> @that.deep.equals({})
            type: -> @that.equals("cjs")

        expect(manifest.modules[1]).to.have.properties
            id: -> @that.equals("b")
            deps: -> @that.deep.equals({})
            type: -> @that.equals("cjs")

        expect(manifest.modules[2]).to.have.properties
            id: -> @that.equals("ac")
            deps: -> @that.deep.equals({})
            type: -> @that.equals("cjs")

        expect(manifest.modules[3]).to.have.properties
            id: -> @that.equals("ac_b")
            deps: -> @that.deep.equals({})
            type: -> @that.equals("cjs")

        expect(manifest.modules[4]).to.have.properties
            id: -> @that.equals("k")
            deps: -> @that.deep.equals
                "a": "ab"
                "a/b": "b"
                "ac": "ac"
                "ac/b": "ac_b"            
            type: -> @that.equals("cjs")
