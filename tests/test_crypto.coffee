path = require("path")
fs = require('fs')
expect = require("chai").expect
utils = require("./utils")

gen = (size) ->
    result = "-"
    for i in [0..size]
        result = result + "|" + result
    return result

describe.skip 'Dev test for sjcl hashing', ->
    sjcl = null
    
    before ->
        sjcl = require("../bower_components/sjcl/all.js")

    hashfunc = (data) ->
        return sjcl.codec.hex.fromBits(sjcl.hash.sha256.hash(data))

    test = (data, hash) ->
        it "should compute valid `sha256` hash for input #{data.length} bytes long", ->
            expect(hashfunc(data)).to.equals(hash)

    test(gen(16), "9ee430991b9536f193c0495f7671bda60fd74fe73efa74f73dd59ea4963de9d9")
    test(gen(17), "4d80214effd24d69e0264d284c29613b2619b65c56cc35b74762230030ba98a9")
    test(gen(18), "1ef8081e6c4d1de53bbe014229a6edc42192e1bf6cf8bbf50c49be7d509e9f65")
    test(gen(19), "f479a814a054e4178170a0999bbcfecf30ee1125004138e1c501de816c9db423")
    test(gen(20), "d2069169ee236ff4538eade428eeb0adafec9e8398ea6626bf3b8211c708cb2d")

describe.skip 'Dev test for openssl hashing', ->
    hashfunc = (data) ->
        return crypto.createHash("sha256").update(data).digest('hex')

    test = (data, hash) ->
        it "should compute valid `sha256` hash for input #{data.length} bytes long", ->
            expect(hashfunc(data)).to.equals(hash)

    test(gen(16), "9ee430991b9536f193c0495f7671bda60fd74fe73efa74f73dd59ea4963de9d9")
    test(gen(17), "4d80214effd24d69e0264d284c29613b2619b65c56cc35b74762230030ba98a9")
    test(gen(18), "1ef8081e6c4d1de53bbe014229a6edc42192e1bf6cf8bbf50c49be7d509e9f65")
    test(gen(19), "f479a814a054e4178170a0999bbcfecf30ee1125004138e1c501de816c9db423")
    test(gen(20), "d2069169ee236ff4538eade428eeb0adafec9e8398ea6626bf3b8211c708cb2d")

describe.skip 'Dev test for sjcl encryption', ->
    sjcl = null
    
    before ->
        sjcl = require("../bower_components/sjcl/all.js")

    test = (data, length) ->
        it "encrypt #{data.length} bytes long input using `gcm`", ->
            result = sjcl.encrypt("password", data, {"mode": "gcm"});
            expect(result).to.be.a("String").with.length(length)

    test(gen(16), 349673)
    test(gen(17), 699197)
    test(gen(18), 1398249)
    test(gen(19), 2796349)
    test(gen(20), 5592553)
