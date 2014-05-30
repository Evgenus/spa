selenium = require('selenium-standalone')
wd = require('wd')

chai = require('chai')
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised);
chai.should();
expect = chai.expect
assert = chai.assert

chaiAsPromised.transferPromiseness = wd.transferPromiseness

mock = require("mock-fs")
fs = require("fs")
path = require("path")
yaml = require("js-yaml")
connect = require("connect")
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
    @timeout(10000)

    DELAY = 200

    before ->
        @urls_log = urls_log = new UrlsLog()

        @server = selenium()

        @app = connect()
            .use connect.logger()
            .use (req, res, next) ->
                if req.url == "/favicon.ico"
                    res.statusCode = 404
                    res.end()
                else
                    next()
            .use (req, res, next) ->
                urls_log.add(req.url)
                next()
            .use connect.static("/", redirect: true)
        connect.createServer(@app).listen(3332)

        @browser = wd.promiseChainRemote()
            .init
                #browserName: 'firefox'
                browserName: 'chrome'

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
                                "/a.js": "/app/a.js"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(DELAY)
            .title().should.eventually.become("version_1")
            .refresh()
            .sleep(DELAY)
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
            .sleep(DELAY)
            .title().should.eventually.become("version_1")
            .then ->
                spa.Builder.from_config("/app/spa.yaml").build()
            .refresh()
            .sleep(2 * DELAY)
            .title().should.eventually.become("version_2")
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
                                "/a.js": "/app/a.js"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .clearLocalStorage()
            .setLocalStorageKey("test_item", "should_not be removed")
            .get('http://127.0.0.1:3332/app/')
            .sleep(DELAY)
            .title().should.eventually.become("version_1")
            .getLocalStorageKey("test_item").should.become("should_not be removed")
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
                            hosting:
                                "/(*.js)": "/app/$1"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .clearLocalStorage()
            .then => @urls_log.clear()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3 * DELAY)
            .title().should.eventually.become("abcd")
            .then =>
                urls = @urls_log.get()
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
            .nodeify(done)

    it 'no manifest file', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    fake:
                        app.js: |
                            var loader = require("loader");

                            loader.onUpdateCompleted = function(event) 
                            {
                                loader.log("onUpdateCompleted", arguments);
                                document.title = "UpdateCompleted";
                            };

                            loader.onApplicationReady = function() 
                            {
                                loader.log("onApplicationReady", arguments);
                                document.title = "ApplicationReady";
                                loader.checkUpdate();
                            };

                            loader.onUpdateFailed = function(event) 
                            {
                                loader.log("onUpdateFailed", arguments);
                                document.title = "UpdateFailed";
                            };
                            
                            loader.onUpToDate = function() 
                            {
                                loader.log("onUpToDate", arguments);
                                document.title = "UpToDate";
                            };
                            
                            loader.onEvaluationError = function(error) 
                            {
                                loader.log("onEvaluationError", arguments);
                                document.title = "EvaluationError";
                            };
                        spa.yaml: |
                            root: "./"
                            manifest: "./manifest.json"
                            hosting: 
                                "/(*)": "fake://$1"
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
                                fake_app: /fake/app.js
                            hosting:
                                "/a.js": "/app/a.js"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
                fs.unlinkSync("/app/manifest.json")
            .get('http://127.0.0.1:3332/')
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3*DELAY)
            .title().should.eventually.become("UpdateFailed")
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
                                "/a.js": "/app/a.js"
                                "/../(*.json)": "/$1"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3*DELAY)
            .title().should.eventually.become("version_4")
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
                                "/a.js": "/app/a.js"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3*DELAY)
            .title().should.eventually.become("version_5")
            .nodeify(done)

    it 'building files with BOM', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    fake:
                        app.js: |
                            var loader = require("loader");

                            loader.onUpdateCompleted = function(event) 
                            {
                                loader.log("onUpdateCompleted", arguments);
                                document.title = "UpdateCompleted";
                            };

                            loader.onApplicationReady = function() 
                            {
                                loader.log("onApplicationReady", arguments);
                                document.title = "ApplicationReady";
                                loader.checkUpdate();
                            };
                            
                            loader.onModuleDownloadFailed = function(module, event) 
                            {
                                loader.log("onModuleDownloadFailed", arguments);
                                document.title = "ModuleDownloadFailed";
                            };
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
                                fake_app: /fake/app.js
                            hosting:
                                "/a.js": "/app/a.js"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                content = new Buffer("""\xEF\xBB\xBF// empty""", "ascii")
                fs.writeFileSync("/app/a.js", content)
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(5*DELAY)
            .title().should.eventually.become("UpdateCompleted")
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
                                "/a.js": "/app/a.js"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)
                spa.Builder.from_config("/app/spa.yaml").build()
                manifest_content = fs.readFileSync("/app/manifest.json", encoding: "utf8")
                @manifest = JSON.parse(manifest_content)
                expect(@manifest).to.have.property("version")
                expect(@manifest.version).to.be.a("String")
            .get('http://127.0.0.1:3332/')
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(3*DELAY)
            .title()
            .then (title) =>
                expect(title).to.equal("VERSION-" + @manifest.version)
            .nodeify(done)

    it 'should load and update a lot of files', (done) ->
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
                                "/(*.js)": "/app/$1"
                    """)
                utils.mount(system, path.resolve(__dirname, "../lib/assets"))
                mock(system)

                NUM = 100

                for i in [1..100]
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
            .clearLocalStorage()
            .get('http://127.0.0.1:3332/app/')
            .sleep(20*DELAY)
            .title()
            .then (title) =>
                expect(title).to.equal("5050")
            .nodeify(done)
