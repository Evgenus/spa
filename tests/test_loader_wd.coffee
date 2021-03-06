selenium = require('selenium-standalone')
wd = require('wd')

chai = require('chai')
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised);
chai.should()
expect = chai.expect
assert = chai.assert

chaiAsPromised.transferPromiseness = wd.transferPromiseness

http = require('http')
connect = require("connect")
morgan = require('morgan')
serveStatic = require('serve-static')

mock = require("mock-fs")
fs = require("fs")
path = require("path")
yaml = require("js-yaml")
spa = require("../lib")
utils = require("./utils")

class UrlsLog
    constructor: ->
        @_items = []
    add: (item) ->
        @_items.push(item)
        return
    clear: ->
        @_items = []
        return
    get: ->
        return @_items.slice()

describe "WD.js", ->
    @timeout(20000)

    DELAY = 200
    MALFUNCTION_DELAY = 3000

    before ->
        @urls_log = urls_log = new UrlsLog()

        @server = selenium()

        @app = connect()
            .use morgan("dev")
            .use (req, res, next) ->
                if req.url == "/favicon.ico"
                    res.statusCode = 404
                    res.end()
                else
                    next()
            .use (req, res, next) ->
                urls_log.add(req.url)
                next()
            .use serveStatic "/", 
                redirect: true
                etag: false

        http.createServer(@app).listen(3332)

        @browser = wd.promiseChainRemote()
            .init
                browserName: 'firefox'
                #browserName: 'chrome'

    after (done) ->
        @browser
            .quit()
            .then =>
                @server.kill()
                @app.removeAllListeners()
                done()

    beforeEach ->
        @old_cwd = process.cwd()
        process.chdir("/")

    afterEach ->
        mock.restore()
        process.chdir(@old_cwd)

    it 'should update single file only after manifest regenerated', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
                        a.js: |
                            var loader = require("loader");
                            loader.onApplicationReady = function() {
                                document.title = "version_1";
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
                            hosting:
                                "./a.js": "/app/a.js"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3 * DELAY)
            .title().should.eventually.become("version_1")
            .refresh()
            .sleep(2 * DELAY)
            .title().should.eventually.become("version_1")
            .then ->
                content = """
                    var loader = require("loader");
                    loader.onApplicationReady = function() {
                        document.title = "version_2";
                    };
                    """
                fs.writeFileSync("/app/a.js", content)
            .refresh()
            .sleep(2 * DELAY)
            .title().should.eventually.become("version_1")
            .then ->
                spa.Builder.from_config("/app/spa.yaml").build()
            .refresh()
            .sleep(3 * DELAY)
            .title().should.eventually.become("version_2")
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'should not remove not owning keys from localstorage', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
                        a.js: |
                            var loader = require("loader");
                            loader.onApplicationReady = function() {
                                document.title = "version_1";
                            };
                        spa.yaml: |
                            root: "./"
                            manifest: "./manifest.json"
                            index: "./index.html"
                            hosting:
                                "./a.js": "/app/a.js"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .setLocalStorageKey("test_item", "should_not be removed")
            .get('http://127.0.0.1:3332/app/')
            .sleep(DELAY)
            .title().should.eventually.become("version_1")
            .getLocalStorageKey("test_item").should.become("should_not be removed")
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'multiple files loading and updating', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
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
                            randomize_urls: false
                            hosting:
                                "./(*.js)": "/app/$1"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                utils.mount(system, path.resolve(__dirname, "../tests"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .then => @urls_log.clear()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3 * DELAY)
            .title().should.eventually.become("abcd")
            .then =>
                urls = @urls_log.get()
                expect(urls).to.be.an("Array").with.length(8)
                expect(urls[0]).to.equal("/app/")
                expect(urls[1]).to.equal("/app/manifest.json")
                expect(urls.slice(2, 6)).to.consist([
                    "/app/a.js",
                    "/app/b.js",
                    "/app/c.js",
                    "/app/d.js",
                    ])
                expect(urls[6]).to.equal("/app/")
                expect(urls[7]).to.equal("/app/manifest.json")
            .safeExecute("localforage.keys( function(err, keys) { window.forage_keys = keys; } )")
            .sleep(DELAY)
            .safeEval("window.forage_keys")
            .then (keys) =>
                expect(keys.map((key) => key.split(":")[2])).to.consist([
                    "/app/a.js",
                    "/app/b.js",
                    "/app/c.js",
                    "/app/d.js",
                    ])
            .then ->
                content = """
                    var d = require("./d.js");
                    module.exports = function() 
                    {
                        return "B" + d();
                    };
                    """
                fs.writeFileSync("/app/b.js", content)
                fs.unlinkSync("/app/c.js")
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .then => @urls_log.clear()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3 * DELAY)
            .title().should.eventually.become("aBd")
            .then =>
                urls = @urls_log.get()
                expect(urls[0]).to.equal("/app/")
                expect(urls[1]).to.equal("/app/manifest.json")
                expect(urls[2]).to.equal("/app/b.js")
                expect(urls[3]).to.equal("/app/")
                expect(urls[4]).to.equal("/app/manifest.json")
            .safeExecute("localforage.keys( function(err, keys) { window.forage_keys = keys; } )")
            .sleep(DELAY)
            .safeEval("window.forage_keys")
            .then (keys) =>
                expect(keys.map((key) => key.split(":")[2])).to.consist([
                    "/app/a.js",
                    "/app/b.js",
                    "/app/d.js",
                    ])
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'multiple files loading and updating with bundle', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
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
                            bundle: "./bundle.js"
                            randomize_urls: false
                            excludes: 
                                - "./bundle.js"
                            hosting:
                                "./(*.js)": "/app/$1"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                utils.mount(system, path.resolve(__dirname, "../tests"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .then => @urls_log.clear()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3 * DELAY)
            .title().should.eventually.become("abcd")
            .then =>
                urls = @urls_log.get()
                expect(urls).to.be.an("Array").with.length(5)
                expect(urls[0]).to.equal("/app/")
                expect(urls[1]).to.equal("/app/manifest.json")
                expect(urls[2]).to.equal("/app/bundle.js")
                expect(urls[3]).to.equal("/app/")
                expect(urls[4]).to.equal("/app/manifest.json")
            .safeExecute("localforage.keys( function(err, keys) { window.forage_keys = keys; } )")
            .sleep(DELAY)
            .safeEval("window.forage_keys")
            .then (keys) =>
                expect(keys.map((key) => key.split(":")[2])).to.consist([
                    "/app/a.js",
                    "/app/b.js",
                    "/app/c.js",
                    "/app/d.js",
                    ])
            .then ->
                content = """
                    var d = require("./d.js");
                    module.exports = function() 
                    {
                        return "B" + d();
                    };
                    """
                fs.writeFileSync("/app/b.js", content)
                fs.unlinkSync("/app/c.js")
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .then => @urls_log.clear()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3 * DELAY)
            .title().should.eventually.become("aBd")
            .then =>
                urls = @urls_log.get()
                expect(urls[0]).to.equal("/app/")
                expect(urls[1]).to.equal("/app/manifest.json")
                expect(urls[2]).to.equal("/app/b.js")
                expect(urls[3]).to.equal("/app/")
                expect(urls[4]).to.equal("/app/manifest.json")
            .safeExecute("localforage.keys( function(err, keys) { window.forage_keys = keys; } )")
            .sleep(DELAY)
            .safeEval("window.forage_keys")
            .then (keys) =>
                expect(keys.map((key) => key.split(":")[2])).to.consist([
                    "/app/a.js",
                    "/app/b.js",
                    "/app/d.js",
                    ])
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'no manifest file', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    index.tmpl: |
                        <!DOCTYPE html>
                        <html>
                        <head>

                        <script type="text/javascript">
                        (function() {
                            var hash_func = <%- inline("./hash/" + hash_name + ".js") %>
                            <%- inline("./localforage.js") %>
                            <%- inline("./loader.js") %>

                            var loader = new Loader({
                                "version": "<%- version %>",
                                "manifest_location": "<%- manifest_location %>",
                                "prefix": "spa",
                                "hash_name": "<%- hash_name %>",
                                "hash_func": hash_func,
                            });

                            loader.onUpdateCompleted = function() 
                            {
                                document.title = "UpdateCompleted";
                            };

                            loader.onNoManifest = function() 
                            {
                                document.title = "NoManifest";
                                loader.checkUpdate();
                            };

                            loader.onApplicationReady = function() 
                            {
                                document.title = "ApplicationReady";
                            };

                            loader.onUpdateFailed = function() 
                            {
                                document.title = "UpdateFailed";
                            };
                            
                            loader.onUpToDate = function() 
                            {
                                document.title = "UpToDate";
                            };
                            
                            loader.onEvaluationError = function() 
                            {
                                document.title = "EvaluationError";
                            };

                            window.onload = function() 
                            {
                                loader.load();
                            }
                        })();
                        </script>

                        </head>
                        <body>
                        </body>
                        </html>

                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
                        a.js: |
                            var loader = require("loader");
                            loader.onApplicationReady = function() {
                                document.title = "ClientApplicationReady";
                            };
                        spa.yaml: |
                            root: "./"
                            index: "./index.html"
                            manifest: "./manifest.json"
                            assets:
                                index_template: /index.tmpl
                            hosting:
                                "./a.js": "/app/a.js"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
                fs.unlinkSync("/app/manifest.json")
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3*DELAY)
            .title().should.eventually.become("UpdateFailed")
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'renamed manifest file', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
                        a.js: |
                            var loader = require("loader");
                            loader.onApplicationReady = function() {
                                document.title = "version_4";
                            };
                        spa.yaml: |
                            root: "./"
                            index: "./index.html"
                            manifest: "../spa-loader.json"
                            hosting:
                                "./a.js": "/app/a.js"
                                "./../(*.json)": "/$1"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3*DELAY)
            .title().should.eventually.become("version_4")
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'manifest with alternated hash function', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
                        a.js: |
                            var loader = require("loader");
                            loader.onApplicationReady = function() {
                                document.title = "version_5";
                            };
                        spa.yaml: |
                            root: "./"
                            index: "./index.html"
                            manifest: "./manifest.json"
                            hash_func: sha256
                            hosting:
                                "./a.js": "/app/a.js"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3*DELAY)
            .title().should.eventually.become("version_5")
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'building files with BOM', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    index.tmpl: |
                        <!DOCTYPE html>
                        <html>
                        <head>

                        <script type="text/javascript">
                        (function() {
                            var hash_func = <%- inline("./hash/" + hash_name + ".js") %>
                            var decoder_func = <%- inline("./decode/" + decoder_name + ".js") %>
                            <%- inline("./localforage.js") %>
                            <%- inline("./loader.js") %>

                            var loader = new Loader({
                                "version": "<%- version %>",
                                "manifest_location": "<%- manifest_location %>",
                                "prefix": "spa",
                                "hash_name": "<%- hash_name %>",
                                "hash_func": hash_func,
                                "decoder_func": decoder_func,
                            });

                            loader.onUpdateCompleted = function() 
                            {
                                document.title = "UpdateCompleted";
                                return true;
                            };

                            loader.onNoManifest = function() 
                            {
                                document.title = "NoManifest";
                                loader.checkUpdate();
                            };

                            loader.onApplicationReady = function() 
                            {
                                document.title = "ApplicationReady";
                            };

                            loader.onUpdateFailed = function() 
                            {
                                document.title = "UpdateFailed";
                            };
                            
                            loader.onUpToDate = function() 
                            {
                                document.title = "UpToDate";
                            };
                            
                            loader.onEvaluationError = function() 
                            {
                                document.title = "EvaluationError";
                            };
                            
                            loader.onModuleDownloadFailed = function(module, event) 
                            {
                                document.title = "ModuleDownloadFailed";
                            };

                            window.onload = function() 
                            {
                                loader.load();
                            }
                        })();
                        </script>

                        </head>
                        <body>
                        </body>
                        </html>
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
                        spa.yaml: |
                            root: "./"
                            index: "./index.html"
                            manifest: "./manifest.json"
                            assets:
                                index_template: /index.tmpl
                            hosting:
                                "./a.js": "/app/a.js"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                content = new Buffer("""\xEF\xBB\xBF// empty""", "ascii")
                fs.writeFileSync("/app/a.js", content)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(5*DELAY)
            .title().should.eventually.become("UpdateCompleted")
            .refresh()
            .sleep(DELAY)
            .title().should.eventually.become("ApplicationReady")
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'should be same manifest version and loader version', (done) ->
        return @browser
            .then =>
                system = yaml.safeLoad("""
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
                        a.js: |
                            var loader = require("loader");
                            loader.onApplicationReady = function() {
                                document.title = "VERSION-" + loader.version;
                            };
                        spa.yaml: |
                            root: "./"
                            index: "./index.html"
                            manifest: "./manifest.json"
                            hosting:
                                "./a.js": "/app/a.js"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
                manifest_content = fs.readFileSync("/app/manifest.json", encoding: "utf8")
                @manifest = JSON.parse(manifest_content)
                expect(@manifest).to.have.property("version")
                expect(@manifest.version).to.be.a("String")
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3*DELAY)
            .title()
            .then (title) =>
                expect(title).to.equal("VERSION-" + @manifest.version)
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'should load a lot of files', (done) ->
        return @browser
            .then =>
                system = yaml.safeLoad("""
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
                        spa.yaml: |
                            root: "./"
                            index: "./index.html"
                            manifest: "./manifest.json"
                            hosting:
                                "./(*.js)": "/app/$1"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)

                NUM = 100

                for i in [1..NUM]
                    fs.writeFileSync("/app/module_#{i}.js", """
                        var next = require("./module_#{i+1}");
                        module.exports = function() {
                            return next() + #{i};
                        };
                        """)
                fs.writeFileSync("/app/module_#{NUM}.js", """
                        module.exports = function() {
                            return #{NUM};
                        };
                        """)
                fs.writeFileSync("/app/module_0.js", """
                        var loader = require("loader");
                        var next = require("./module_1");
                        loader.onApplicationReady = function() {
                            document.title = next();
                        };
                        """)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(30*DELAY)
            .title().should.eventually.become("5050")
            .safeExecute("localforage.clear()")
            .sleep(10 * DELAY)
            .nodeify(done)

    it 'should load big files', (done) ->
        return @browser
            .then =>
                system = yaml.safeLoad("""
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
                        spa.yaml: |
                            root: "./"
                            index: "./index.html"
                            manifest: "./manifest.json"
                            hosting:
                                "./(*.js)": "/app/$1"
                            hash_func: sha256
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)

                c = "7"
                for i in [1..5]
                    c = "(#{c} + #{c})"
                q = c
                for i in [1..11]
                    q = "(#{q} + #{q})"

                NUM = 10

                for i in [1..10]
                    fs.writeFileSync("/app/module_#{i}.js", """
                        var next = require("./module_#{i+1}");
                        module.exports = function() {
                            return next() + #{c} + "#{q}".length;
                        };
                        """)
                fs.writeFileSync("/app/module_#{NUM}.js", """
                        module.exports = function() {
                            return #{c} + "#{q}".length;
                        };
                        """)
                fs.writeFileSync("/app/module_0.js", """
                        var loader = require("loader");
                        var next = require("./module_1");
                        loader.onApplicationReady = function() {
                            document.title = next();
                        };
                        """)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(40 * DELAY)
            .title().should.eventually.become("3934350")
            .safeExecute("localforage.clear()")
            .sleep(10 * DELAY)
            .nodeify(done)

    it 'building files with wierd names', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
                        "[^](). '{}'+!=#$.js": |
                            var loader = require("loader");
                            loader.onApplicationReady = function() {
                                document.title = "version_6";
                            };
                        spa.yaml: |
                            root: "./"
                            manifest: "./manifest.json"
                            index: "./index.html"
                            hosting:
                                "./(*.js)": "/app/$1"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3*DELAY)
            .title().should.eventually.become("version_6")
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'could not break loader', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    index.tmpl: |
                        <!DOCTYPE html>
                        <html>
                        <head>

                        <script type="text/javascript">
                        (function() {
                            var hash_func = <%- inline("./hash/" + hash_name + ".js") %>
                            var decoder_func = <%- inline("./decode/" + decoder_name + ".js") %>
                            <%- inline("./localforage.js") %>
                            <%- inline("./loader.js") %>

                            var loader = new Loader({
                                "version": "<%- version %>",
                                "manifest_location": "<%- manifest_location %>",
                                "prefix": "spa",
                                "hash_name": "<%- hash_name %>",
                                "hash_func": hash_func,
                                "decoder_func": decoder_func,
                            });

                            loader.onNoManifest = function() 
                            {
                                loader.checkUpdate();
                            };

                            loader.onUpdateCompleted = function() 
                            {
                                setTimeout(location.reload.bind(location), 0)
                                return true;
                            }
                            
                            loader.onModuleBeginDownload = function() 
                            {
                                throw Error("HAHA1!");
                            };

                            loader.onModuleDownloadProgress = function() 
                            {
                                throw Error("HAHA2!");
                            };
                            
                            loader.onTotalDownloadProgress = function() 
                            {
                                throw Error("HAHA3!");
                            };

                            loader.onTotalDownloadProgress = function() 
                            {
                                throw Error("HAHA4!");
                            };

                            loader.onModuleDownloaded = function() 
                            {
                                throw Error("HAHA5!");
                            };

                            loader.onEvaluationStarted = function() 
                            {
                                throw Error("HAHA6!");
                            };

                            loader.onModuleEvaluated = function() 
                            {
                                throw Error("HAHA7!");
                            };

                            window.onload = function() 
                            {
                                loader.load();
                            }
                        })();
                        </script>

                        </head>
                        <body>
                        </body>
                        </html>
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
                        c.js: | 
                            module.exports = 1
                        b.js: | 
                            module.exports = require("./c");
                        a.js: |
                            var b = require("./b");
                            var loader = require("loader");
                            loader.onApplicationReady = function() {
                                document.title = "version_7";
                            };
                        spa.yaml: |
                            root: "./"
                            index: "./index.html"
                            manifest: "./manifest.json"
                            assets:
                                index_template: /index.tmpl
                            hosting:
                                "./(*.js)": "/app/$1"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3*DELAY)
            .title().should.eventually.become("version_7")
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'malfunction while updating', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
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
                            randomize_urls: false
                            hosting:
                                "./(*.js)": "/app/$1"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .then ->
                content = """
                    var c = require("./c.js");
                    module.exports = function() 
                    {
                        return "bb" + c();
                    };
                    """
                fs.writeFileSync("/app/b.js", content)
                content = """var d = require("./d.js"); module.exports = function() { return "cc" + d(); };"""
                fs.writeFileSync("/app/c.js", content)
                spa.Builder.from_config("/app/spa.yaml").build()
                fs.unlinkSync("/app/c.js")
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .then => @urls_log.clear()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3 * DELAY)
            .then =>
                urls = @urls_log.get()
                expect(urls).to.be.an("Array").with.length(6)
                expect(urls[0]).to.equal("/app/")
                expect(urls[1]).to.equal("/app/manifest.json")
                expect(urls.slice(2, 6)).to.consist([
                    "/app/a.js",
                    "/app/b.js",
                    "/app/c.js",
                    "/app/d.js",
                    ])
            .elementById("btn-retry").isDisplayed().should.become(false)
            .sleep(MALFUNCTION_DELAY + 2 * DELAY)
            .elementById("btn-retry").isDisplayed().should.become(true)
            .elementById("btn-retry").click()
            .sleep(MALFUNCTION_DELAY + 2 * DELAY)
            .elementById("btn-retry").isDisplayed().should.become(true)
            .then ->
                content = """var d = require("./d.js"); module.exports = function() { return "cc" + d(); };"""
                fs.writeFileSync("/app/c.js", content)
            .then => @urls_log.clear()
            .elementById("btn-retry").click()
            .sleep(3 * DELAY)
            .then =>
                urls = @urls_log.get()
                expect(urls).to.be.an("Array").with.length(5)
                expect(urls[0]).to.equal("/app/")
                expect(urls[1]).to.equal("/app/manifest.json")
                expect(urls[2]).to.equal("/app/c.js")
                expect(urls[3]).to.equal("/app/")
                expect(urls[4]).to.equal("/app/manifest.json")
            .title().should.eventually.become("abbccd")
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'malfunction while evaluating', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
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
                            randomize_urls: false
                            hosting:
                                "./(*.js)": "/app/$1"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .then => @urls_log.clear()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3 * DELAY)
            .title().should.eventually.become("abcd")
            .then =>
                urls = @urls_log.get()
                expect(urls).to.be.an("Array").with.length(8)
                expect(urls[0]).to.equal("/app/")
                expect(urls[1]).to.equal("/app/manifest.json")
                expect(urls.slice(2, 6)).to.consist([
                    "/app/a.js",
                    "/app/b.js",
                    "/app/c.js",
                    "/app/d.js",
                    ])
                expect(urls[6]).to.equal("/app/")
                expect(urls[7]).to.equal("/app/manifest.json")
            .then ->
                content = """
                    var d = require("./d.js");
                    throw Error("error in loading");
                    """
                fs.writeFileSync("/app/c.js", content)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .then => @urls_log.clear()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3 * DELAY)
            .then =>
                urls = @urls_log.get()
                expect(urls).to.be.an("Array").with.length(4)
                expect(urls[0]).to.equal("/app/")
                expect(urls[1]).to.equal("/app/manifest.json")
                expect(urls[2]).to.equal("/app/c.js")
                expect(urls[3]).to.equal("/app/")
            .elementById("btn-force").isDisplayed().should.become(false)
            .sleep(MALFUNCTION_DELAY + 2 * DELAY)
            .elementById("btn-force").isDisplayed().should.become(true)
            .then ->
                content = """
                    var d = require("./d.js");
                    module.exports = function() 
                    {
                        return "b" + d();
                    };
                    """
                fs.writeFileSync("/app/b.js", content)
                fs.unlinkSync("/app/c.js")
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .then => @urls_log.clear()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3 * DELAY)
            .then =>
                urls = @urls_log.get()
                expect(urls).to.be.an("Array").with.length(1)
                expect(urls[0]).to.equal("/app/")
            .then => @urls_log.clear()
            .sleep(MALFUNCTION_DELAY + 2 * DELAY)
            .elementById("btn-retry").isDisplayed().should.become(true)
            .elementById("btn-retry").click()
            .sleep(MALFUNCTION_DELAY + 2 * DELAY)
            .then =>
                urls = @urls_log.get()
                expect(urls).to.be.an("Array").with.length(1)
                expect(urls[0]).to.equal("/app/")
            .then => @urls_log.clear()
            .elementById("btn-force").isDisplayed().should.become(true)
            .elementById("btn-force").click()
            .sleep(5 * DELAY)
            .then =>
                urls = @urls_log.get()
                expect(urls).to.be.an("Array").with.length(5)
                expect(urls[0]).to.equal("/app/")
                expect(urls[1]).to.equal("/app/manifest.json")
                expect(urls[2]).to.equal("/app/b.js")
                expect(urls[3]).to.equal("/app/")
                expect(urls[4]).to.equal("/app/manifest.json")
            .title().should.eventually.become("abd")
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'passcode test', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    build:
                        placeholder.txt: yo
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
                        a.js: |
                            var loader = require("loader");
                            loader.onApplicationReady = function() 
                            {
                                document.title = "version_8";
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
                            randomize_urls: false
                            hosting:
                                "./(*.js)": "/build/$1"
                            copying:
                                "./(*.js)": "/build/$1"
                            coding_func:
                                name: aes-gcm
                                password: babuka
                                iter: 1000
                                ks: 128
                                ts: 128
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .then => @urls_log.clear()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3 * DELAY)
            .elementByCss("input[type=password]").isDisplayed().should.become(true)
            .elementByCss("input[type=password]")
                .sendKeys("passpass")
                .getValue().should.become("passpass");
            .elementByCss("input[type=submit]")
                .click()
            .sleep(DELAY)
            .elementByCss("input[type=password]").isDisplayed().should.become(false)
            .elementByCss("input[type=submit]").isDisplayed().should.become(false)
            .sleep(MALFUNCTION_DELAY)
            .elementById("btn-retry").isDisplayed().should.become(true)
            .elementById("btn-retry").click()
            .sleep(DELAY)
            .elementByCss("input[type=password]").isDisplayed().should.become(true)
            .elementByCss("input[type=password]")
                .sendKeys("babuka")
                .getValue().should.become("babuka");
            .elementByCss("input[type=submit]")
                .click()
            .sleep(DELAY)
            .title().should.become("version_8")
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'fix for #59: cjs evaluator missing process from node environment', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
                        a.js: |
                            if ("production" !== process.env.NODE_ENV) {
                            }
                            var loader = require("loader");
                            loader.onApplicationReady = function() {
                                document.title = "version_1";
                            };
                        spa.yaml: |
                            root: "./"
                            manifest: "./manifest.json"
                            index: "./index.html"
                            hosting:
                                "./a.js": "/app/a.js"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3*DELAY)
            .title().should.eventually.become("version_1")
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'fix for #62: loading modules with no exports', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
                        a.js: |
                            require("./b");
                            require("./c");
                            require("./d");
                            require("./e");
                            var loader = require("loader");
                            loader.onApplicationReady = function() {
                                document.title = "version_1";
                            };
                        b.js: |
                            module.exports = false;
                        c.js: |
                            module.exports = null;
                        d.js: |
                            module.exports = 0;
                        e.js: |
                            module.exports = undefined;
                        spa.yaml: |
                            root: "./"
                            manifest: "./manifest.json"
                            index: "./index.html"
                            hosting:
                                "./(**/*.js)": "/app/$1"
                            default_loader: cjs
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3*DELAY)
            .title().should.eventually.become("version_1")
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'fix for #64, #69: test windows wrapper', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app:
                        a.js: |
                            var loader = require("loader");
                            loader.onApplicationReady = function() {
                                var buff = new ArrayBuffer(5);
                                var view = new Uint8Array(buff);
                                window.crypto.getRandomValues(view);
                                // #69
                                var obj = new window.Object();
                                window.onload = function() {
                                    console.log(this);
                                }
                                window.addEventListener("click", function() {
                                    document.title = "fixed_64";
                                });
                            };
                        spa.yaml: |
                            root: "./"
                            index: "./index.html"
                            manifest: "./manifest.json"
                            hash_func: sha256
                            hosting:
                                "./a.js": "/app/a.js"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3*DELAY)
            .elementByCss("body").click()
            .sleep(DELAY)
            .title().should.eventually.become("fixed_64")
            .safeExecute("localforage.clear()")
            .nodeify(done)

    it 'loads modules of various AMD types', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    index.html: |
                        <html>
                            <head>
                                <title></title>
                            </head>
                            <body>
                                <h1>Testing</h1>
                            </body>
                        </html>
                    app: 
                        a.js: |
                            // amd/nodeps
                            define({ 
                                a: "a"
                                });
                        b.js: |
                            // amd/factory
                            define(function(require) { 
                                return "b" + require("./a").a
                                });
                        c.js: |
                            // amd/rem
                            define(function(require, exports, module) { 
                                module.exports = "c" + require("./b");
                            });
                        d.js: |
                            // amd/deps
                            define(["./c"], function(c) { 
                                return "d" + c;
                                });
                        e.js: |
                            // amd/named
                            define("e", ["./d"], function(d) { 
                                return "e" + d;
                                });
                        f.js: |
                            // amd/deps with require from dependencies
                            define(["require"], function(require) {
                                var e = require("./e");
                                return "f" + e;
                                });
                        g.js: |
                            // amd/named with require and module from dependencies
                            define("g", ["require", "module"], function(require, module) {
                                var f = require("./f");
                                module.exports = "g" + f;
                                });
                        start.js: |
                            // commonjs
                            var loader = require("loader"); 
                            var g = require("./g");
                            loader.onApplicationReady = function() {
                                document.title = g;
                                };
                        spa.yaml: |
                            root: "./"
                            index: "./index.html"
                            manifest: "./manifest.json"
                            hosting:
                                "./(*.js)": "/app/$1"
                    """)
                try
                    utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                    mock(system)
                    spa.Builder.from_config("/app/spa.yaml").build()        
                catch e
                    console.log e
                
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3*DELAY)
            .title().should.eventually.become("gfedcba")
            .safeExecute("localforage.clear()")
            .nodeify(done)
