fs = require("fs")
mock = require("mock-fs")
yaml = require("js-yaml")
path = require("path")
expect = require("chai").expect
spa = require("../lib")
utils = require("./utils")

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

            expect(manifest)
                .to.have.property('modules')
                .to.be.an("Array").with.length(4)
            
            expect(manifest.modules[0]).to.have.properties
                id: -> @that.equals("c")
                deps: -> @that.deep.equals({})
                type: -> @that.equals(type)
                url: -> @that.equals("http://127.0.0.1:8010/module1/a/c.js")
            
            expect(manifest.modules[1]).to.have.properties
                id: -> @that.equals("b")
                deps: -> @that.deep.equals
                    "./a/c": "c"
                type: -> @that.equals(type)
                url: -> @that.equals("http://127.0.0.1:8010/module1/b.js")
            
            expect(manifest.modules[2]).to.have.properties
                id: -> @that.equals("d")
                deps: -> @that.deep.equals
                    "a1/c": "c"
                type: -> @that.equals(type)
                url: -> @that.equals("http://127.0.0.1:8010/module2/d.js")
            
            expect(manifest.modules[3]).to.have.properties
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

        expect(manifest)
            .to.have.property('modules')
            .to.be.an("Array").with.length(1)
        
        expect(manifest.modules[0]).to.have.properties
            id: -> @that.equals("a")
        expect(manifest.modules[0]).not.to.have.property("url")

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
                a.js: // empty
                spa.yaml: |
                    root: "/testimonial/"
                    index: index.html
                    appcache: main.appcache
                    cached:
                        - a.js
                    hosting:
                        "./(**/*.*)": "http://127.0.0.1:8010/$1"
            """)
        utils.mount(system, path.resolve(__dirname, "../lib/assets"))
        mock(system)

    it 'should produce appcache and index files', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        builder.build()

        expect(fs.existsSync("/testimonial/index.html")).to.be.true
        expect(fs.existsSync("/testimonial/main.appcache")).to.be.true

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
            modules: -> @to.be.an("Array").with.length(1)
            
        expect(manifest.modules[0]).to.have.properties
            id: -> @that.equals("a")
            deps: -> @that.deep.equals({})
            type: -> @that.equals("cjs")
            hash: -> @that.equals("1007f6da5acf8cc2643274276079bc3e")
            url: -> @that.equals("http://127.0.0.1:8010/a.js")

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

        expect(manifest)
            .to.have.property('modules')
            .to.be.an("Array").with.length(3)
        
        expect(manifest.modules[0]).to.have.properties
            id: -> @that.equals("a")
            deps: -> @that.deep.equals({})
            type: -> @that.equals("junk")

        expect(manifest.modules[1]).to.have.properties
            id: -> @that.equals("b")
            deps: -> @that.deep.equals
                "/a": "a"
            type: -> @that.equals("cjs")
        
        expect(manifest.modules[2]).to.have.properties
            id: -> @that.equals("c")
            deps: -> @that.deep.equals
                "/b": "b"
            type: -> @that.equals("amd")

        expect(manifest.modules[0]).not.to.have.property("url")
        expect(manifest.modules[1]).not.to.have.property("url")
        expect(manifest.modules[2]).not.to.have.property("url")

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

        expect(fs.existsSync("/build/a.js")).to.be.true
        expect(fs.existsSync("/build/b.js")).to.be.true
        expect(fs.existsSync("/build/c.js")).to.be.true
        expect(fs.existsSync("/build/d.js")).to.be.true

        expect(decoder(fs.readFileSync("/build/d.js"), "babuka", manifest.modules[0].decoding))
            .to.equal(fs.readFileSync("/testimonial/d.js", encoding: "utf8"))
        expect(decoder(fs.readFileSync("/build/c.js"), "babuka", manifest.modules[1].decoding))
            .to.equal(fs.readFileSync("/testimonial/c.js", encoding: "utf8"))
        expect(decoder(fs.readFileSync("/build/b.js"), "babuka", manifest.modules[2].decoding))
            .to.equal(fs.readFileSync("/testimonial/b.js", encoding: "utf8"))
        expect(decoder(fs.readFileSync("/build/a.js"), "babuka", manifest.modules[3].decoding))
            .to.equal(fs.readFileSync("/testimonial/a.js", encoding: "utf8"))
