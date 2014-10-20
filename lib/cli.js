var Builder, console, exists, fs, get_config_path, get_options_parser, path;

path = require("path");

fs = require("fs");

console = require("./console");

Builder = require("./").Builder;

exists = function(filepath) {
  var stats;
  console.log("Trying to find " + filepath);
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
  var cwd, _ref, _ref1, _ref2;
  cwd = process.cwd();
  return (_ref = (_ref1 = (_ref2 = exists(path.resolve(cwd, arg))) != null ? _ref2 : exists(path.resolve(cwd, arg, "spa.json"))) != null ? _ref1 : exists(path.resolve(cwd, arg, "spa.yaml"))) != null ? _ref : exists(path.resolve(cwd, arg, "spa.yml"));
};

get_options_parser = function() {
  return require("nomnom").script('spa').options({
    config: {
      abbr: 'c',
      type: 'string',
      metavar: 'FILE',
      help: 'Path to build config file',
      "default": '.'
    },
    silent: {
      abbr: 's',
      flag: true,
      "default": false,
      help: 'Suppress all console output.'
    }
  });
};

exports.run = function() {
  var argv, builder, error, options_parser;
  options_parser = get_options_parser();
  argv = options_parser.parse(process.argv);
  console.setEnabled(!argv.silent);
  path = get_config_path(argv.config);
  if (path == null) {
    console.log("Can't locate config file");
    return;
  }
  console.log("Reading config from " + path);
  builder = Builder.from_config(path);
  try {
    return builder.build();
  } catch (_error) {
    error = _error;
    return console.error(error.toString());
  }
};
