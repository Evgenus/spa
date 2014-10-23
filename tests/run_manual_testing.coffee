http = require('http')
connect = require("connect")
route = require('connect-route');
morgan = require('morgan')
serveStatic = require('serve-static')
serveIndex = require('serve-index')

mock = require("mock-fs")
fs = require("fs")
path = require("path")
yaml = require("js-yaml")
utils = require("./utils")

spa = require("../lib")

snapshot_0 = ->
    mock.restore()
    system = {}
    utils.mount(system, path.resolve(__dirname, "./testing_assets"))
    utils.mount(system, path.resolve(__dirname, "../lib/assets"))
    utils.mount(system, path.resolve(__dirname, "../node_modules/serve-index/public"))

    mock(system)

snapshot_1 = ->
    mock.restore()
    system = yaml.safeLoad("""
        /app:
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
                var loader = require("loader");
                var b = require("./b.js");
                loader.onApplicationReady = function() 
                {
                    document.title = "a" + b();
                    loader.checkUpdate();
                };
                loader.onUpdateCompleted = function(event) {
                    setTimeout(location.reload.bind(location), 0)
                    return true
                };
            spa.yaml: |
                root: "./"
                manifest: "./manifest.json"
                index: "./index.html"
                randomize_urls: true
                hosting:
                    "./(*.js)": "/app/$1"
        """)
    utils.mount(system, path.resolve(__dirname, "."))
    utils.mount(system, path.resolve(__dirname, "../lib/assets"))
    utils.mount(system, path.resolve(__dirname, "../node_modules/serve-index/public"))

    mock(system)

snapshot_2 = ->
    mock.restore()
    system = yaml.safeLoad("""
        /app:
            d.js: |
                module.exports = function() 
                {
                    return "d";
                };
            b.js: |
                var d = require("./d.js");
                module.exports = function() 
                {
                    return "B" + d();
                };
            a.js: |
                var loader = require("loader");
                var b = require("./b.js");
                loader.onApplicationReady = function() 
                {
                    document.title = "a" + b();
                    loader.checkUpdate();
                };
                loader.onUpdateCompleted = function(event) {
                    setTimeout(location.reload.bind(location), 0)
                    return true
                };
            spa.yaml: |
                root: "./"
                manifest: "./manifest.json"
                index: "./index.html"
                randomize_urls: true
                hosting:
                    "./(*.js)": "/app/$1"
        """)
    utils.mount(system, path.resolve(__dirname, "."))
    utils.mount(system, path.resolve(__dirname, "../lib/assets"))
    utils.mount(system, path.resolve(__dirname, "../node_modules/serve-index/public"))

    mock(system)

snapshot_3 = ->
    mock.restore()
    system = yaml.safeLoad("""
        /app:
            spa.yaml: |
                root: "./"
                index: "./index.html"
                assets:
                    index_template: /spa/tests/testing_assets/index.tmpl
                manifest: "./manifest.json"
                hosting:
                    "./(*.js)": "/app/$1"
        """)

    utils.mount(system, path.resolve(__dirname, "."))
    utils.mount(system, path.resolve(__dirname, "../lib/assets"))
    utils.mount(system, path.resolve(__dirname, "../node_modules/serve-index/public"))

    mock(system)

    c = "/"
    while c.length < 4000
        c = c + c

    NUM = 500

    for i in [1..NUM]
        fs.writeFileSync("/app/module_#{i}.js", """
            require("./module_#{i+1}");
            //#{c}
            """)
    fs.writeFileSync("/app/module_#{NUM}.js", """
            //#{c}
            """)
    fs.writeFileSync("/app/module_0.js", """
            var loader = require("loader");
            require("./module_1");
            loader.onApplicationReady = function() {
                document.title = loader._stats.evaluate_module_start[501] - loader._stats.evaluate_module_start[0];
            };
            """)

app = connect()
    .use morgan("dev")
    .use (req, res, next) ->
        if req.url == "/favicon.ico"
            res.statusCode = 404
            res.end()
        else
            next()

    .use "/", route (router) ->

        router.get '/activate/:snapshot', (req, res) ->
            try
                switch req.params.snapshot
                    when "1"
                        snapshot_1()
                    when "2"
                        snapshot_2()
                    when "3"
                        snapshot_3()
                    else 
                        res.statusCode = 404
                        res.end()
                        return
            catch error
                console.log(error)
                res.statusCode = 200
                res.send(error)
                return

            res.statusCode = 303;
            res.setHeader('Location', '/');
            res.end()

        router.get '/build', (req, res) ->
            spa.Builder.from_config("/app/spa.yaml").build()
            res.statusCode = 303;
            res.setHeader('Location', '/');
            res.end()

    .use serveStatic "/", 
        redirect: false
        etag: false
    .use serveIndex "/",
        icons: true
        stylesheet: path.join(__dirname, 'testing_assets', 'style.css')
        template: path.join(__dirname, 'testing_assets', 'directory.html')

snapshot_0()
http.createServer(app).listen(3332)