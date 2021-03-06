(HASH) ->
    return (data) ->
        if data instanceof String or typeof data is "string"
            wa = CryptoJS.enc.Utf8.parse(data)
        else
            words = []
            if data instanceof ArrayBuffer
                array = new Uint8Array(data)
            else if data instanceof Buffer
                array = data
            else
                throw Error("invalid input type")

            len = array.length
            for i in [0..len-1]
                words[i >>> 2] |= (array[i] & 0xff) << (24 - (i % 4) * 8)

            wa = CryptoJS.lib.WordArray.create(words, len)

        hash = CryptoJS.algo[HASH].create()
        hash.update(wa)
        return hash.finalize().toString(CryptoJS.enc.Hex)
