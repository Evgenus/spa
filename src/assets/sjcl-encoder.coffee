(MODE) ->
    encoder = (data, password, p) ->
        if data instanceof String or typeof data is "string"
            msg = sjcl.codec.utf8String.toBits(data)
        else if data instanceof ArrayBuffer
            view = new Uint8Array(data)
            msg = sjcl.codec.bytes.toBits(view)
        else if data instanceof Buffer
            msg = sjcl.codec.bytes.toBits(data)
        else
            throw Error("invalid input type")

        p.cipher = "aes"
        p.mode = MODE
        if p.iv?
            iv = sjcl.codec.hex.toBits(p.iv)
        else    
            iv = sjcl.random.randomWords(4, 0)
            p.iv = sjcl.codec.hex.fromBits(iv)
        if p.salt?
            salt = sjcl.codec.hex.toBits(p.salt)
        else
            salt = sjcl.random.randomWords(2, 0)
            p.salt = sjcl.codec.hex.fromBits(salt)
        key = sjcl.misc.pbkdf2(password, salt, p.iter).slice(0, p.ks / 32)
        auth = sjcl.codec.utf8String.toBits(p.auth)
        prp = new sjcl.cipher.aes(key)
        ct = sjcl.mode[MODE].encrypt(prp, msg, iv, auth, p.ts)
        return new Buffer(sjcl.codec.bytes.fromBits(ct))

    return (content, module, builder) ->
        result =
            iter: builder.coding_func.iter
            ks: builder.coding_func.ks
            ts: builder.coding_func.ts
            auth: module.url
        key = "aes-#{MODE}-#{result.ks}-#{result.ts}-#{result.iter}-#{module.source_hash}-#{result.auth}"
        if builder.cache.has(key)
            cached = builder.cache.get(key)
            result.salt = cached.salt
            result.iv = cached.iv
        data = encoder(content, builder.coding_func.password, result)
        module.decoding = result
        builder.cache.set(key, result)
        return data
