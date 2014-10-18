path = require("path")
fs = require("fs")
Builder = require("./").Builder

exists = (filepath) ->
    console.log("Trying to find #{filepath}")
    return unless fs.existsSync(filepath)
    stats = fs.statSync(filepath)
    return unless stats.isFile()
    return filepath


get_config_path = (arg) ->
    cwd = process.cwd()
    return exists(path.resolve(cwd, arg)) ?
           exists(path.resolve(cwd, arg, "spa.json")) ?
           exists(path.resolve(cwd, arg, "spa.yaml")) ?
           exists(path.resolve(cwd, arg, "spa.yml"))

get_options_parser = ->
    return require("nomnom")
        .script 'spa'
        .options 
            config:
                abbr: 'c'
                type: 'string'
                metavar: 'FILE'
                help: 'Path to build config file'
                default: '.'

exports.run = ->
    options_parser = get_options_parser()
    argv = options_parser.parse(process.argv)
    path = get_config_path(argv.config)

    unless path?
        console.log("Can't locate config file")
        return

    builder = Builder.from_config(path)

    try
        builder.build()
    catch error
        console.log(error.toString())
