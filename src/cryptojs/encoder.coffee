(data) ->
    hash = CryptoJS.algo[ALGO].create()
    if data instanceof ArrayBuffer
        words = []
        u8arr = new Uint8Array(data)
        len = u8arr.length
        i = 0
        while i < len
            words[i >>> 2] |= (u8arr[i] & 0xff) << (24 - (i % 4) * 8)
            i++
        data = CryptoJS.lib.WordArray.create(words, len)
    hash.update data
    return hash.finalize().toString CryptoJS.enc.Hex