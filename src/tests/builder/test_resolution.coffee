fs = require("fs")
mock = require("mock-fs")
spa = require("spa")
yaml = require("js-yaml")
path = require("path")
expect = require('chai').expect

describe 'Modules resolution', ->

    before ->
        process.chdir("/")
        mock(yaml.safeLoad("""
            testimonial: 
                module1:
                    a:
                        c.js: |
                            var m2 = require("../../module2");
                    b.js: |
                        var b2 = require("/module2/b");
                        var ac = require("./a/c");
                module2:
                    index.js: |
                        var a1 = require("a1/../b");
                    b.js: |
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
        source = fs.readFileSync("/testimonial/spa.yaml", encoding: "utf8")
        config = yaml.safeLoad(source)
        builder = new spa.Builder(config)
        expect(builder.build.bind(builder))
            .to.throw(spa.CyclicDependenciesError)

    after ->
        mock.restore()
