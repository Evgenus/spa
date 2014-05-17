mock = require("mock-fs")
fs = require("fs")
path = require("path")
yaml = require("js-yaml")
connect = require("connect")
http = require("http")
route = require("connect-route")

spa = require("../../lib")

http.ServerResponse.prototype.redirect = (target) ->
    @statusCode = 307
    @setHeader('Location', target)
    @end('Redirecting to ' + connect.utils.escape(target));

http.ServerResponse.prototype.fail = () ->
    @session.state = "failed"
    @statusCode = 307
    @setHeader('Location', "/")
    @end('Redirecting to ' + connect.utils.escape(target));

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

app = connect()
    .use connect.logger()
    .use connect.cookieParser()
    .use connect.cookieSession
        secret: 'spa:test!'
        cookie: 
            maxAge: 1000

    .use route (router) ->

        router.get '/', (req, res, next) ->
            unless req.session.state?
                req.session.results ?= []
                req.session.state = "do_next"
                return res.redirect("/next")

            state = req.session.state
            test = req.session.test
            phase = req.session.phase

            console.log("\n## -- >> #{state}:#{test}:#{phase}\n")

            switch state
                when "do_before"
                    req.session.state = "before_done"
                    filename = path.join("/testimonial", test, "before.html")
                    fs.readFile filename, (error, data) ->
                        throw error if error?
                        res.end(data)
                when "do_run", "run_done"
                    req.session.state = "run_done"
                    filename = path.join("/testimonial", test, phase, "index.html")
                    fs.readFile filename, (error, data) ->
                        throw error if error?
                        res.end(data)
                when "success"
                    req.session.results.push("success:#{test}:#{phase}")
                    req.session.state = "do_next"
                    res.redirect("/next")
                when "failed"
                    req.session.results.push("failed:#{test}:#{phase}")
                    req.session.state = "do_next"
                    res.redirect("/next")
                when "all_done"
                    req.session.state = null
                    res.end(JSON.stringify(req.session.results, null, "  "))

        router.get "/manifest.json", (req, res, next) ->
            return res.fail() unless req.session.state is "run_done"
            test = req.session.test
            phase = req.session.phase
            filename = path.join("/testimonial", test, phase, "manifest.json")
            fs.readFile filename, encoding: "utf-8", (error, data) ->
                throw error if error?
                console.log("\nMANIFEST\n#{data}\n")
                res.end(data)

        router.get "/before", (req, res, next) ->
            return res.fail() unless req.session.state is "before_done"
            req.session.state = "do_run"
            res.redirect("/")

        router.get "/next", (req, res, next) ->
            test = req.session.test
            phase = req.session.phase

            unless test?
                req.session.state = "do_before"
                req.session.test = "test1"
                req.session.phase = "phase1"

            switch test
                when "test1" 
                    switch phase
                        when "phase1"
                            req.session.state = "do_run"
                            req.session.phase = "phase2"
                        when "phase2"
                            req.session.state = "all_done"

            res.redirect("/")

        router.get "/test1/phase1", (req, res, next) ->
            return res.fail() unless req.session.state is "run_done"
            return res.fail() unless req.session.test is "test1"
            return res.fail() unless req.session.phase is "phase1"
            req.session.state = "success"
            res.redirect("/")

        router.get "/test1/phase2", (req, res, next) ->
            return res.fail() unless req.session.state is "run_done"
            return res.fail() unless req.session.test is "test1"
            return res.fail() unless req.session.phase is "phase2"
            req.session.state = "success"
            res.redirect("/")

        router.get "/favicon.ico", (req, res, next) ->
            res.statusCode = 404
            res.end()

    .use connect.static("/testimonial", redirect: false)

    .use (req, res, next) -> res.fail()

system = yaml.safeLoad("""

    testimonial: 
        test1:
            before.html: |
                <script>
                    window.onload = function() {
                        localStorage.clear();
                        location.replace("/before");
                        };
                </script>
            phase1:
                a.js: |
                    var loader = require("loader");
                    var phase = "/test1/phase1";
                    loader.onApplicationReady = function() {
                        console.log(phase, "onApplicationReady");
                        loader.checkUpdate();
                    };
                    loader.onUpdateFound = function() {
                        // This time we run code of previously loaded phase1
                        // at startup of phase2. How to check this WTF???
                        console.log(phase, "onUpdateFound");
                        loader.startUpdate();
                    };
                    loader.onUpToDate = function() {
                        console.log(phase, "onUpToDate");
                        location.replace(phase);
                    };
                    loader.onUpdateCompletted = function() {
                        location.reload();
                    };
                spa.yaml: |
                    root: "./"
                    manifest: "./manifest.json"
                    index: "./index.html"
                    assets:
                        template: /assets/index.tmpl
                        loader: /assets/loader.js
                        md5: /assets/md5.js
                        fake_app: /assets/fake-app.fjs
                        fake_manifest: /assets/fake-manifest.json
                    hosting:
                        "/a.js": "/test1/phase1/a.js"
            phase2:
                a.js: |
                    var loader = require("loader");
                    var phase = "/test1/phase2";
                    loader.onApplicationReady = function() {
                        console.log(phase, "onApplicationReady");
                        loader.checkUpdate();
                    };
                    loader.onUpdateFound = function() {
                        console.log(phase, "onUpdateFound", "FAIL!!");
                    };
                    loader.onUpToDate = function() {
                        console.log(phase, "onUpToDate");
                        location.replace(phase)
                    };
                    loader.onUpdateCompletted = function() {
                        location.reload();
                    };
                spa.yaml: |
                    root: "./"
                    manifest: "./manifest.json"
                    index: "./index.html"
                    assets:
                        template: /assets/index.tmpl
                        loader: /assets/loader.js
                        md5: /assets/md5.js
                        fake_app: /assets/fake-app.fjs
                        fake_manifest: /assets/fake-manifest.json
                    hosting:
                        "/a.js": "/test1/phase2/a.js"
    """)
mount(system, "assets", path.resolve(__dirname, "../../lib/assets"))

process.chdir("/")
mock(system)

spa.Builder.from_config("/testimonial/test1/phase1/spa.yaml").build()
spa.Builder.from_config("/testimonial/test1/phase2/spa.yaml").build()

connect.createServer(app).listen(8010)
