(data) ->
    if data instanceof ArrayBuffer
        words = []
        u8arr = new Uint8Array(data)
        len = u8arr.length
        i = 0
        while i < len
            words[i >>> 2] |= (u8arr[i] & 0xff) << (24 - (i % 4) * 8)
            i++
        return CryptoJS.lib.WordArray.create(words, len)
    
    if data instanceof String or typeof data is "string"
        return CryptoJS.enc.Utf8.parse(data)
