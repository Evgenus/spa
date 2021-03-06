(HASH) ->
    return (data) ->
        if data instanceof String or typeof data is "string"
            output = data
        else if data instanceof ArrayBuffer
            view = new Uint8Array(data)
            output = sjcl.codec.utf8String.fromBits(sjcl.codec.bytes.toBits(view))
        else if data instanceof Buffer
            output = sjcl.codec.utf8String.fromBits(sjcl.codec.bytes.toBits(data))
        else
            throw Error("invalid input type")

        return output
