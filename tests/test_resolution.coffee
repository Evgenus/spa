fs = require("fs")
mock = require("mock-fs")
yaml = require("js-yaml")
path = require("path")
chai = require("chai")
_ = require("underscore")

spa = require("../lib")

expect = chai.expect

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

describe 'Building module with unknown dependency', ->

    before ->
        @old_cwd = process.cwd()
        process.chdir("/")
        mock(yaml.safeLoad("""
            testimonial: 
                a.js: |
                    var b = require("/b");
                spa.yaml: |
                    root: "./"
            """))

    it 'should report unresolved dependency', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        
        expect(builder.build.bind(builder))
            .to.throw(spa.UnresolvedDependencyError)
            .that.deep.equals(new spa.UnresolvedDependencyError("/a.js", "/b"))

    after ->
        mock.restore()
        process.chdir(@old_cwd)

describe 'Building module with external dependency', ->

    before ->
        @old_cwd = process.cwd()
        process.chdir("/")
        mock(yaml.safeLoad("""
            testimonial: 
                a.js: |
                    var b = require("/b");
                b.js: |
                    // empty
                spa.yaml: |
                    root: "./"
                    excludes:
                        - /b.js
            """))

    it 'should report dependency out of scope', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        
        expect(builder.build.bind(builder))
            .to.throw(spa.ExternalDependencyError)
            .has.properties
                alias: -> @equals("/b")
                path: -> @equals("/a.js")

    after ->
        mock.restore()
        process.chdir(@old_cwd)

describe 'Building module with cyclic dependencies', ->

    before ->
        @old_cwd = process.cwd()
        process.chdir("/")
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

    it 'should report loop in dependencies', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        
        _loop = new spa.Loop()
            .prepend("/d.js", "/a")
            .prepend("/c.js", "/d")
            .prepend("/b.js", "/c")
            .prepend("/a.js", "/b")

        expect(builder.build.bind(builder))
            .to.throw(spa.CyclicDependenciesError)
            .to.have.property("loop")
                .that.deep.equals(_loop)

    after ->
        mock.restore()
        process.chdir(@old_cwd)

describe 'Building module with cyclic dependencies and something else', ->

    before ->
        @old_cwd = process.cwd()
        process.chdir("/")
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

    it 'should report only loop', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        
        _loop = new spa.Loop()
            .prepend("/e.js", "/c")
            .prepend("/d.js", "/e")
            .prepend("/c.js", "/d")

        expect(builder.build.bind(builder))
            .to.throw(spa.CyclicDependenciesError)
            .to.have.property("loop")
                .that.deep.equals(_loop)

    after ->
        mock.restore()
        process.chdir(@old_cwd)

describe 'Building module with paths rewired', ->

    before ->
        @old_cwd = process.cwd()
        process.chdir("/")
        mock(yaml.safeLoad("""
            testimonial: 
                module1:
                    a:
                        c.js: |
                            // empty
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
                        "/(**/*.js)": "http://127.0.0.1:8010/$1"
                    manifest: "manifest.json"
            """))

    it 'should successfully build', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        builder.build()
        manifest = JSON.parse(fs.readFileSync("/testimonial/manifest.json"), encoding: "utf8")

        expect(manifest).to.be.an("Array").with.length(4)
        
        expect(manifest[0]).to.have.properties
            id: -> @that.equals("c")
            deps: -> @that.deep.equals({})
        
        expect(manifest[1]).to.have.properties
            id: -> @that.equals("b")
            deps: -> @that.deep.equals
                "./a/c": "c"
        
        expect(manifest[2]).to.have.properties
            id: -> @that.equals("d")
            deps: -> @that.deep.equals
                "a1/c": "c"
        
        expect(manifest[3]).to.have.properties
            id: -> @that.equals("e")
            deps: -> @that.deep.equals
                "a1/../b": "b"

    after ->
        mock.restore()
        process.chdir(@old_cwd)

describe 'Building module without manifest', ->

    before ->
        @old_cwd = process.cwd()
        process.chdir("/")
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

    after ->
        mock.restore()
        process.chdir(@old_cwd)

describe 'Building module with appcache and index', ->

    before ->
        @old_cwd = process.cwd()
        process.chdir("/")
        system = yaml.safeLoad("""
            testimonial: 
                a.js: // empty
                spa.yaml: |
                    root: "/testimonial/"
                    index: index.html
                    appcache: main.appcache
                    assets:
                        index_template: /assets/index.tmpl
                        appcache_template: /assets/appcache.tmpl
                        loader: /assets/loader.js
                        md5: /assets/md5.js
                        fake_app: /assets/fake/app.js
                        fake_manifest: /assets/fake/manifest.json
                    cached:
                        - a.js
                    hosting:
                        "/(**/*.*)": "http://127.0.0.1:8010/$1"
            """)
        mount(system, "assets", path.resolve(__dirname, "../lib/assets"))
        mock(system)

    it 'should produce appcache file', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        builder.build()

        expect(fs.existsSync("/testimonial/index.html")).to.be.true
        expect(fs.existsSync("/testimonial/main.appcache")).to.be.true

        console.log(fs.readFileSync("/testimonial/main.appcache", encoding: "utf8"))

    after ->
        mock.restore()
        process.chdir(@old_cwd)
