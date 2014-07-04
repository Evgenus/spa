path = require("path")
fs = require('fs')
expect = require("chai").expect
utils = require("./utils")
crypto = require("crypto")
vm = require("vm")

describe 'Testing hash functions from assets', ->

    sandbox =
        ArrayBuffer: Object.freeze(ArrayBuffer)
        Buffer: Object.freeze(Buffer)
        Uint8Array: Object.freeze(Uint8Array)

    _eval_file = (p) ->
        return vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, p), "utf8"), sandbox)

    toArrayBuffer = (buffer) ->
        ab = new ArrayBuffer(buffer.length)
        view = new Uint8Array(ab)
        for i in [0..buffer.length]
            view[i] = buffer[i];
        return ab

    sha1 = _eval_file("../lib/assets/hash/sha1.js")

    it "should compute valid `sha1` hash", ->
        expect(sha1("Hello World")).to.equals("0a4d55a8d778e5022fab701977c5d840bbc486d0")
        expect(sha1(new Buffer("Hello World"))).to.equals("0a4d55a8d778e5022fab701977c5d840bbc486d0")
        expect(sha1(toArrayBuffer(new Buffer("Hello World")))).to.equals("0a4d55a8d778e5022fab701977c5d840bbc486d0")

        expect(sha1("Hello Вася")).to.equals("65a6daf017d8b5f036c27d9fb03adadb8dec801e")

    sha256 = _eval_file("../lib/assets/hash/sha256.js")

    it "should compute valid `sha256` hash", ->
        expect(sha256("Hello World")).to.equals("a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e")
        expect(sha256("Hello Вася")).to.equals("07a2495337a70ed331c6228a971c613e766a0c1b88e4b16ab47257768b86b885")

    sha512 = _eval_file("../lib/assets/hash/sha512.js")

    it "should compute valid `sha512` hash", ->
        expect(sha512("Hello World")).to.equals("2c74fd17edafd80e8447b0d46741ee243b7eb74dd2149a0ab1b9246fb30382f27e853d8585719e0e67cbda0daa8f51671064615d645ae27acb15bfb1447f459b")
        expect(sha512("Hello Вася")).to.equals("93f287a0068b3de02010b96d758d5b48e777ea70e33457ed0b157ecc6c083477e7951962372d268bf3631f923f2eab2d95887c5fa8793c37b186d15c502cd751")

