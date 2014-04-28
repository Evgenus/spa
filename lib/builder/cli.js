// Generated by CoffeeScript 1.6.3
var Builder, argv, builder, error, exists, fs, get_config_path, opts, path;

path = require("path");

fs = require("fs");

Builder = require("./").Builder;

exists = function(filepath) {
  var stats;
  if (!fs.existsSync(filepath)) {
    return;
  }
  stats = fs.statSync(filepath);
  if (!stats.isFile()) {
    return;
  }
  return filepath;
};

get_config_path = function(arg) {
  var cwd, _ref, _ref1;
  cwd = process.cwd();
  if (arg != null) {
    return exists(path.resolve(cwd, arg));
  }
  return (_ref = (_ref1 = exists(path.join(cwd, "spa.json"))) != null ? _ref1 : exists(path.join(cwd, "spa.yaml"))) != null ? _ref : exists(path.join(cwd, "spa.yml"));
};

opts = require('optimist').usage('Usage: $0 <build-config-file>').options({
  config: {
    describe: "path to build config file"
  },
  help: {
    boolean: true
  },
  debug: {
    boolean: true
  }
});

argv = opts.parse(process.argv);

if (argv.help) {
  console.log(opts.help());
  process.exit();
}

builder = Builder.from_config(get_config_path(argv.config));

try {
  builder.build();
} catch (_error) {
  error = _error;
  console.log(error.toString());
}