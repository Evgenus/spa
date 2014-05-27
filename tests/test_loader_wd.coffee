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

describe "WD.js", ->
    @timeout(10000)

    DELAY = 200

    before ->
        @server = selenium()

        @app = connect()
            .use connect.logger()
            .use connect.static("/", redirect: true)
        connect.createServer(@app).listen(3332)

        @browser = wd.promiseChainRemote()
            .init
                browserName:'firefox'

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
                            loader.onUpdateCompletted = function(event) {
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
                                document.title = "version_3";
                            };
                        c.js: |
                            var d = require("./d.js");
                            module.exports = function() 
                            {
                                d();
                            };
                        b.js: |
                            var c = require("./c.js");
                            module.exports = function() 
                            {
                                c();
                            };
                        a.js: |
                            var loader = require("loader");
                            var b = require("./b.js");
                            loader.onApplicationReady = function() 
                            {
                                b();
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
            .get('http://127.0.0.1:3332/app/')
            .sleep(3 * DELAY)
            .title().should.eventually.become("version_3")
            .then ->
                content = """
                    var d = require("./d.js");
                    module.exports = function() 
                    {
                        d();
                    };
                    """
                fs.writeFileSync("/app/b.js", content)
                fs.unlinkSync("/app/c.js")
                spa.Builder.from_config("/app/spa.yaml").build()
            .get('http://127.0.0.1:3332/')
            .sleep(DELAY)
            .get('http://127.0.0.1:3332/app/')
            .sleep(3 * DELAY)
            .title().should.eventually.become("version_3")
            .nodeify(done)

    it 'no manifest file', (done) ->
        return @browser
            .then ->
                system = yaml.safeLoad("""
                    fake:
                        app.js: |
                            var loader = require("loader");

                            loader.onUpdateCompletted = function(event) 
                            {
                                loader.log("onUpdateCompletted", arguments);
                                document.title = "UpdateCompletted";
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

                            loader.onUpdateCompletted = function(event) 
                            {
                                loader.log("onUpdateCompletted", arguments);
                                document.title = "UpdateCompletted";
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
                            hash_func: sha256
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
            .title().should.eventually.become("UpdateCompletted")
            .nodeify(done)
