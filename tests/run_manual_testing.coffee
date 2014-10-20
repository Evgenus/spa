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
    system = {}
    utils.mount(system, path.resolve(__dirname, "./testing_assets"))
    utils.mount(system, path.resolve(__dirname, "../lib/assets"))
    utils.mount(system, path.resolve(__dirname, "../node_modules/serve-index/public"))

    mock(system)

snapshot_1 = ->
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
    utils.mount(system, path.resolve(__dirname, "./testing_assets"))
    utils.mount(system, path.resolve(__dirname, "../lib/assets"))
    utils.mount(system, path.resolve(__dirname, "../node_modules/serve-index/public"))

    mock(system)

snapshot_2 = ->
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
    utils.mount(system, path.resolve(__dirname, "./testing_assets"))
    utils.mount(system, path.resolve(__dirname, "../lib/assets"))
    utils.mount(system, path.resolve(__dirname, "../node_modules/serve-index/public"))

    mock(system)

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
            switch req.params.snapshot
                when "1"
                    snapshot_1()
                when "2"
                    snapshot_2()
                else 
                    res.statusCode = 404
                    res.end()
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