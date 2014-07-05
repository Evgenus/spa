path = require("path")
fs = require('fs')
expect = require("chai").expect
utils = require("./utils")
vm = require("vm")

gen = (size) ->
    result = "-"
    for i in [0..size]
        result = result + "|" + result
    return result

eval_file = (p, s) ->
    return vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, p), "utf8"), s)

sandbox =
    ArrayBuffer: Object.freeze(ArrayBuffer)
    Buffer: Object.freeze(Buffer)
    Uint8Array: Object.freeze(Uint8Array)

describe 'Testing hash functions from assets', ->

    toArrayBuffer = (buffer) ->
        ab = new ArrayBuffer(buffer.length)
        view = new Uint8Array(ab)
        for i in [0..buffer.length]
            view[i] = buffer[i];
        return ab

    sha1 = eval_file("../lib/assets/hash/sha1.js", sandbox)

    it "should compute valid `sha1` hash", ->
        expect(sha1("Hello World")).to.equals("0a4d55a8d778e5022fab701977c5d840bbc486d0")
        expect(sha1(new Buffer("Hello World"))).to.equals("0a4d55a8d778e5022fab701977c5d840bbc486d0")
        expect(sha1(toArrayBuffer(new Buffer("Hello World")))).to.equals("0a4d55a8d778e5022fab701977c5d840bbc486d0")

        expect(sha1("Hello Вася")).to.equals("65a6daf017d8b5f036c27d9fb03adadb8dec801e")

    sha256 = eval_file("../lib/assets/hash/sha256.js", sandbox)

    it "should compute valid `sha256` hash", ->
        expect(sha256("Hello World")).to.equals("a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e")
        expect(sha256("Hello Вася")).to.equals("07a2495337a70ed331c6228a971c613e766a0c1b88e4b16ab47257768b86b885")

    sha512 = eval_file("../lib/assets/hash/sha512.js", sandbox)

    it "should compute valid `sha512` hash", ->
        expect(sha512("Hello World")).to.equals("2c74fd17edafd80e8447b0d46741ee243b7eb74dd2149a0ab1b9246fb30382f27e853d8585719e0e67cbda0daa8f51671064615d645ae27acb15bfb1447f459b")
        expect(sha512("Hello Вася")).to.equals("93f287a0068b3de02010b96d758d5b48e777ea70e33457ed0b157ecc6c083477e7951962372d268bf3631f923f2eab2d95887c5fa8793c37b186d15c502cd751")

describe 'Testing cypher functions from assets', ->
    it "sjcl decrypt", ->
        decrypt = eval_file("../lib/assets/decode/aes-ccm.js", sandbox)

        params = 
            cipher: "aes"
            mode: "ccm"
            iter: 1000
            ks: 128
            ts: 64
            iv: "0d9e71975ce5b84732bc9ea325786893",
            salt: "a4e4d6b02a887b71"
            auth: ""

        ct = new Buffer([
            76, 93, 211, 25, 205, 64, 12, 250,
            12, 137, 139, 195, 251, 200, 115, 223,
            83, 62, 72, 77, 32, 217, 131, 93,
            196, 101, 69, 169, 181, 241, 197, 229,
            7, 110, 116, 75, 182, 223, 27, 119,
            182, 114, 113, 247, 209, 72, 207, 160,
            223, 77, 29, 87, 109, 151, 225, 165,
            15, 119, 77, 79, 135, 80, 214, 34,
            26, 184, 156, 192, 15, 1
        ])
        expect(decrypt(ct, "aaa111", params)).to.equals("This page is a demo of the Stanford Javascript Crypto Library.")

    it "sjcl encrypt", ->
        window = {}
        window.window = window

        s =
            ArrayBuffer: Object.freeze(ArrayBuffer)
            Buffer: Object.freeze(Buffer)
            Uint8Array: Object.freeze(Uint8Array)
            console: Object.freeze(console)
            window: Object.freeze(window)
            Uint32Array: Object.freeze(Uint32Array)

        decrypt = eval_file("../lib/assets/decode/aes-gcm.js", s)
        encrypt = eval_file("../lib/assets/encode/aes-gcm.js", s)

        message = gen(5)

        params =
            cipher: "aes"
            mode: "gcm"
            iter: 1000
            ks: 128
            ts: 128
            auth: "zzzzzz"

        data = encrypt(message, "aaa111", params)
        expect(decrypt(data, "aaa111", params)).to.equals(message)
