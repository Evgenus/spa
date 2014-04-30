connect = require('connect')
mock = require("mock-fs")
fs = require("fs")
yaml = require("js-yaml")
spa = require("../../lib")

process.chdir("/")
mock(yaml.safeLoad("""
    testimonial: 
        a.js: |
            var b = require("/b");
        b.js: |
            // empty
        spa.yaml: |
            root: "./"
            manifest: "manifest.json"
    """))

builder = spa.Builder.from_config("/testimonial/spa.yaml")
builder.build()
app = connect()
    .use(connect.static("/testimonial"))
connect.createServer(app).listen(8010)
