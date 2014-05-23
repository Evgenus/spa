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
    @timeout(20000)

    DELAY = 200

    beforeEach ->
        @old_cwd = process.cwd()
        process.chdir("/")

    afterEach ->
        mock.restore()
        process.chdir(@old_cwd)

    describe 'Simple update', ->

        before ->
            @server = selenium()

            @app = connect()
                .use connect.logger()
                .use connect.static("/", redirect: true)
            connect.createServer(@app).listen(3332)

            @browser = wd.promiseChainRemote()

        after (done) ->
            @browser
                .quit()
                .then =>
                    @server.kill()
                    @app.removeAllListeners()
                    done()

        it 'should update single file only after manifest regenerated', (done) ->
            @browser
                .init
                    browserName:'firefox'
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
                                assets:
                                    index_template: /assets/index.tmpl
                                    appcache_template: /assets/appcache.tmpl
                                    loader: /assets/loader.js
                                    md5: /assets/md5.js
                                    fake_app: /assets/fake/app.js
                                    fake_manifest: /assets/fake/manifest.json
                                hosting:
                                    "/a.js": "/app/a.js"
                        """)
                    utils.mount(system, "assets", path.resolve(__dirname, "../lib/assets"))
                    mock(system)
                    spa.Builder.from_config("/app/spa.yaml").build()
                .get('http://127.0.0.1:3332/')
                .clearLocalStorage()
                .setLocalStorageKey("test_item", "should_not be removed")
                .get('http://127.0.0.1:3332/app/')
                .sleep(DELAY)
                .title().should.eventually.become("version_1")
                .getLocalStorageKey("test_item").should.become("should_not be removed")
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
                .sleep(DELAY)
                .title().should.eventually.become("version_2")
                .then -> 
                    done()
