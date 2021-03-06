(HASH) ->
    return (data) ->
        if data instanceof String or typeof data is "string"
            input = sjcl.codec.utf8String.toBits(data)
        else if data instanceof ArrayBuffer
            view = new Uint8Array(data)
            input = sjcl.codec.bytes.toBits(view)
        else if data instanceof Buffer
            input = sjcl.codec.bytes.toBits(data)
        else
            throw Error("invalid input type")

        return sjcl.codec.hex.fromBits(sjcl.hash[HASH].hash(input))
