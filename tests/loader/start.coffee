connect = require('connect')
mock = require("mock-fs")
fs = require("fs")
path = require("path")
yaml = require("js-yaml")
spa = require("../../lib")

mount = (dirname) ->
    result = {}
    for name in fs.readdirSync(dirname)
        continue if name is "."
        continue if name is ".."
        child = path.join(dirname, name)
        stats = fs.statSync(child)
        if stats.isDirectory()
            result[name] = mount(child)
        if stats.isFile()
            result[name] = fs.readFileSync(child)
    return result

system = yaml.safeLoad("""
    testimonial: 
        test1:
            phase1:
                a.js: |
                    var b = require("/b");
                b.js: |
                    var loader = require("loader")
                    loader.onApplicationReady = function() {
                        console.log("Now I'm ready!");
                        loader.checkUpdate();
                    }
                spa.yaml: |
                    root: "./"
                    manifest: "/testimonial/manifest.json"
                    index: "/testimonial/index.html"
                    assets:
                        template: /assets/index.tmpl
                        loader: /assets/loader.js
                        md5: /assets/md5.js
                    hosting:
                        "/(**/*.js)": "http://127.0.0.1:8010/test1/phase1/$1"
    """)
system["assets"] = mount(path.resolve(__dirname, "../../lib/assets"))

process.chdir("/")
mock(system)

builder = spa.Builder.from_config("/testimonial/test1/phase1/spa.yaml")
builder.build()

app = connect()
    .use (req, res, next) ->
        console.log(req.method + " " + req.url)
        try
        finally
            next()
    .use(connect.static("/testimonial"))
connect.createServer(app).listen(8010)
