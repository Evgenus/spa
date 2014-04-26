fs = require("fs")
mock = require("mock-fs")
spa = require("spa")
yaml = require("js-yaml")
path = require("path")
expect = require('chai').expect

describe 'Building modules with cyclic dependencies', ->

    before ->
        @old_cwd = process.cwd()
        process.chdir("/")
        mock(yaml.safeLoad("""
            testimonial: 
                a.js: |
                    var b2 = require("/b");
                b.js: |
                    var b2 = require("/c");
                c.js: |
                    var b2 = require("/d");
                d.js: |
                    var b2 = require("/a");
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

describe 'Building modules with cyclic dependencies and something else', ->

    before ->
        @old_cwd = process.cwd()
        process.chdir("/")
        mock(yaml.safeLoad("""
            testimonial: 
                a.js: |
                    // empty
                b.js: |
                    var b2 = require("/a");
                c.js: |
                    var b2 = require("/d");
                    var b2 = require("/b");
                d.js: |
                    var b2 = require("/e");
                    var b2 = require("/f");
                    var b2 = require("/b");
                e.js: |
                    var b2 = require("/c");
                    var b2 = require("/f");
                f.js: |
                    var b2 = require("/a");
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

describe 'Building modules with paths rewired', ->

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

    it 'should report loop in dependencies', ->
        builder = spa.Builder.from_config("/testimonial/spa.yaml")
        builder.build()
        manifest = JSON.parse(fs.readFileSync("/testimonial/manifest.json"), encoding: "utf8")

        expect(manifest).to.be.an("Array").with.length(4)
        
        expect(manifest[0])
            .to.have.property("id").that.equals("c")
        expect(manifest[0])
            .and.to.have.property("deps").that.deep.equals({})
        
        expect(manifest[1])
            .to.have.property("id").that.equals("b")
        expect(manifest[1])
            .to.have.property("deps").that.deep.equals
                "./a/c": "c"
        
        expect(manifest[2])
            .to.have.property("id").that.equals("d")
        expect(manifest[2])
            .and.to.have.property("deps").that.deep.equals
                "a1/c": "c"

        expect(manifest[3])
            .to.have.property("id").that.equals("e")
        expect(manifest[3])
            .and.to.have.property("deps").that.deep.equals
                "a1/../b": "b"

    after ->
        mock.restore()
        process.chdir(@old_cwd)
