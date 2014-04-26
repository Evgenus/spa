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
            .to.have.deep.property("loop")
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
            .to.have.deep.property("loop")
                .that.deep.equals(_loop)

    after ->
        mock.restore()
        process.chdir(@old_cwd)

# describe 'Building modules with cyclic dependencies', ->

#     before ->
#         @old_cwd = process.cwd()
#         process.chdir("/")
#         mock(yaml.safeLoad("""
#             testimonial: 
#                 module1:
#                     a:
#                         c.js: |
#                             var m2 = require("../../module2");
#                     b.js: |
#                         var b2 = require("/module2/b");
#                         var ac = require("./a/c");
#                 module2:
#                     index.js: |
#                         var a1 = require("a1/../b");
#                     b.js: |
#                         var a1 = require("a1/c");
#                 spa.yaml: |
#                     root: "/testimonial/"
#                     extensions: 
#                         - .js
#                     paths:
#                         a1: "/module1/a"
#                     hosting:
#                         "/(**/*.js)": "http://127.0.0.1:8010/$1"
#                     manifest: "manifest.json"
#             """))

#     it 'should report loop in dependencies', ->
#         builder = spa.Builder.from_config("/testimonial/spa.yaml")
#         expect(builder.build.bind(builder))
#             .to.throw(spa.CyclicDependenciesError)

#     after ->
#         mock.restore()
#         process.chdir(@old_cwd)
