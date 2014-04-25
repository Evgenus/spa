path = require("path")
fs = require("fs")
Builder = require("./").Builder

exists = (filepath) ->
    return unless fs.existsSync(filepath)
    stats = fs.statSync(filepath)
    return unless stats.isFile()
    return filepath

load_json = (filepath) ->
    return unless filepath?
    source = fs.readFileSync(filepath)
    return JSON.parse(source)

load_yaml = (filepath) ->
    yaml = require('js-yaml')
    return unless filepath?
    source = fs.readFileSync(filepath, encoding: "utf8")
    return yaml.safeLoad(source)

get_config_path = (arg) ->
    cwd = process.cwd()
    return exists(path.resolve(cwd, arg)) if arg?
    return exists(path.join(cwd, "spa.json")) ?
           exists(path.join(cwd, "spa.yaml")) ?
           exists(path.join(cwd, "spa.yml"))

get_config_content = (filepath) ->
    switch path.extname(filepath)
        when ".yaml", ".yml"
            return load_yaml(filepath)
        when ".json"
            return load_json(filepath)

check_config = (config) ->
    config.root ?= config
    config.root ?= "."
    config.root = path.resolve(process.cwd(), config.root) 
    return config

opts = require('optimist')
    .usage('Usage: $0 <build-config-file>')
    .options
        config:
            describe: "path to build config file"
        help:
            boolean: true
        debug: 
            boolean: true

argv = opts.parse(process.argv)

if argv.help
    console.log(opts.help())
    process.exit()

config = check_config(get_config_content(get_config_path(argv.config)))
builder = new Builder(config)
try
    builder.build()
catch error
    console.log(error.toString())
