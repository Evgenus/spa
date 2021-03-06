path = require("path")
fs = require('fs')
expect = require("chai").expect
utils = require("./utils")
vm = require("vm")
spa = require("../lib")

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

    it "should compute valid `md5` hash", ->
        md5 = eval_file("../lib/assets/hash/md5.js", sandbox)
        expect(md5("Hello World")).to.equals("b10a8db164e0754105b7a99be72e3fe5")
        expect(md5(new Buffer("Hello World"))).to.equals("b10a8db164e0754105b7a99be72e3fe5")
        expect(md5(toArrayBuffer(new Buffer("Hello World")))).to.equals("b10a8db164e0754105b7a99be72e3fe5")

        expect(md5("Hello Вася")).to.equals("238de3b491f08ac71de076ad7c5b6541")
        expect(md5(new Buffer("Hello Вася"))).to.equals("238de3b491f08ac71de076ad7c5b6541")
        expect(md5(toArrayBuffer(new Buffer("Hello Вася")))).to.equals("238de3b491f08ac71de076ad7c5b6541")

    it "should compute valid `ripemd160` hash", ->
        ripemd160 = eval_file("../lib/assets/hash/ripemd160.js", sandbox)
        expect(ripemd160("Hello World")).to.equals("a830d7beb04eb7549ce990fb7dc962e499a27230")
        expect(ripemd160("Hello Вася")).to.equals("0c21db8ee9b440476b79f7dcbeb2594c45c37a2c")

    it "should compute valid `sha1` hash", ->
        sha1 = eval_file("../lib/assets/hash/sha1.js", sandbox)
        expect(sha1("Hello World")).to.equals("0a4d55a8d778e5022fab701977c5d840bbc486d0")
        expect(sha1(new Buffer("Hello World"))).to.equals("0a4d55a8d778e5022fab701977c5d840bbc486d0")
        expect(sha1(toArrayBuffer(new Buffer("Hello World")))).to.equals("0a4d55a8d778e5022fab701977c5d840bbc486d0")

        expect(sha1("Hello Вася")).to.equals("65a6daf017d8b5f036c27d9fb03adadb8dec801e")
        expect(sha1(new Buffer("Hello Вася"))).to.equals("65a6daf017d8b5f036c27d9fb03adadb8dec801e")
        expect(sha1(toArrayBuffer(new Buffer("Hello Вася")))).to.equals("65a6daf017d8b5f036c27d9fb03adadb8dec801e")

    it "should compute valid `sha224` hash", ->
        sha224 = eval_file("../lib/assets/hash/sha224.js", sandbox)
        expect(sha224("Hello World")).to.equals("c4890faffdb0105d991a461e668e276685401b02eab1ef4372795047")
        expect(sha224("Hello Вася")).to.equals("b6d32b2ca1b12b830218cf81f10478918cbc60dedd999908df4babcb")

    it "should compute valid `sha256` hash", ->
        sha256 = eval_file("../lib/assets/hash/sha256.js", sandbox)
        expect(sha256("Hello World")).to.equals("a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e")
        expect(sha256("Hello Вася")).to.equals("07a2495337a70ed331c6228a971c613e766a0c1b88e4b16ab47257768b86b885")

    it "should compute valid `sha384` hash", ->
        sha384 = eval_file("../lib/assets/hash/sha384.js", sandbox)
        expect(sha384("Hello World")).to.equals("99514329186b2f6ae4a1329e7ee6c610a729636335174ac6b740f9028396fcc803d0e93863a7c3d90f86beee782f4f3f")
        expect(sha384("Hello Вася")).to.equals("4cd80a13b2100ea2f4e4ac4a5911139a3fa19e345230b5e2b457fe9233d6878a1c99bd8c498acbfd6f7fafcdf0855a60")

    it "should compute valid `sha512` hash", ->
        sha512 = eval_file("../lib/assets/hash/sha512.js", sandbox)
        expect(sha512("Hello World")).to.equals("2c74fd17edafd80e8447b0d46741ee243b7eb74dd2149a0ab1b9246fb30382f27e853d8585719e0e67cbda0daa8f51671064615d645ae27acb15bfb1447f459b")
        expect(sha512("Hello Вася")).to.equals("93f287a0068b3de02010b96d758d5b48e777ea70e33457ed0b157ecc6c083477e7951962372d268bf3631f923f2eab2d95887c5fa8793c37b186d15c502cd751")

describe 'Testing cypher functions from assets', ->
    it "sjcl decrypt", ->
        decrypt = eval_file("../lib/assets/decode/aes-ccm.js", sandbox)

        module =
            decoding: 
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

        loader =
            options:
                password: "aaa111"

        expect(decrypt(ct, module, loader)).to.equals("This page is a demo of the Stanford Javascript Crypto Library.")

    window = {}
    window.window = window

    esandbox =
        ArrayBuffer: Object.freeze(ArrayBuffer)
        Buffer: Object.freeze(Buffer)
        Uint8Array: Object.freeze(Uint8Array)
        console: Object.freeze(console)
        window: Object.freeze(window)
        Uint32Array: Object.freeze(Uint32Array)

    it "sjcl aes-ccm", ->
        decrypt = eval_file("../lib/assets/decode/aes-ccm.js", esandbox)
        encrypt = eval_file("../lib/assets/encode/aes-ccm.js", esandbox)

        message = gen(5)

        builder =
            coding_func:
                password: "aaa111"
                iter: 1000
                ks: 128
                ts: 128
            cache: new spa.DB()

        module =
            url: "zzzzzz"

        loader =
            options:
                password: "aaa111"

        data = encrypt(message, module, builder)
        expect(module.decoding).to.have.property("cipher").that.equals("aes")
        expect(module.decoding).to.have.property("mode").that.equals("ccm")
        expect(decrypt(data, module, loader)).to.equals(message)

    it "sjcl aes-gcm", ->
        decrypt = eval_file("../lib/assets/decode/aes-gcm.js", esandbox)
        encrypt = eval_file("../lib/assets/encode/aes-gcm.js", esandbox)

        message = gen(5)

        builder =
            coding_func:
                password: "aaa111"
                iter: 1000
                ks: 128
                ts: 128
            cache: new spa.DB()

        module =
            url: "zzzzzz"

        loader =
            options:
                password: "aaa111"

        data = encrypt(message, module, builder)
        expect(module.decoding).to.have.property("cipher").that.equals("aes")
        expect(module.decoding).to.have.property("mode").that.equals("gcm")
        expect(decrypt(data, module, loader)).to.equals(message)

    it "sjcl aes-ocb2", ->
        decrypt = eval_file("../lib/assets/decode/aes-ocb2.js", esandbox)
        encrypt = eval_file("../lib/assets/encode/aes-ocb2.js", esandbox)

        message = gen(5)

        builder =
            coding_func:
                password: "aaa111"
                iter: 1000
                ks: 128
                ts: 128
            cache: new spa.DB()

        module =
            url: "zzzzzz"

        loader =
            options:
                password: "aaa111"

        data = encrypt(message, module, builder)
        expect(module.decoding).to.have.property("cipher").that.equals("aes")
        expect(module.decoding).to.have.property("mode").that.equals("ocb2")
        expect(decrypt(data, module, loader)).to.equals(message)
