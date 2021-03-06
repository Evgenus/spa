(MODE) ->
    decoder = (data, password, p) ->
        if data instanceof ArrayBuffer
            view = new Uint8Array(data)
            ct = sjcl.codec.bytes.toBits(view)
        else if data instanceof Buffer
            ct = sjcl.codec.bytes.toBits(data)
        else
            throw Error("invalid input type")

        salt = sjcl.codec.hex.toBits(p.salt)
        iv = sjcl.codec.hex.toBits(p.iv)
        key = sjcl.misc.pbkdf2(password, salt, p.iter).slice(0, p.ks / 32)
        prp = new sjcl.cipher.aes(key)
        auth = sjcl.codec.utf8String.toBits(p.auth)
        text = sjcl.mode[MODE].decrypt(prp, ct, iv, auth, p.ts)
        return sjcl.codec.utf8String.fromBits(text)

    return (content, module, loader) ->
        return decoder(content, loader.options.password, module.decoding)
