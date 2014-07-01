var Builder, CryptoJS, CyclicDependenciesError, ExternalDependencyError, Logger, Loop, NoCopyingRuleError, UnresolvedDependencyError, clc, definition, detectiveAMD, detectiveCJS, ejs, encode_data, encoders, fs, get_config_content, globrules, hasBOM, hashers, load_json, load_yaml, packagejson, path, walker, yaml, _,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

fs = require('fs');

walker = require('fs-walk-glob-rules');

globrules = require('glob-rules');

path = require('path');

clc = require('cli-color');

detectiveCJS = require('detective');

detectiveAMD = require('detective-amd');

definition = require('module-definition').sync;

CryptoJS = require("crypto-js");

yaml = require('js-yaml');

ejs = require("ejs");

_ = require('underscore');

_.string = require('underscore.string');

_.mixin(_.string.exports());

packagejson = (function() {
  var packagepath;
  packagepath = path.resolve(__dirname, '../package.json');
  return JSON.parse(fs.readFileSync(packagepath, 'utf8'));
})();

CyclicDependenciesError = (function(_super) {
  __extends(CyclicDependenciesError, _super);

  function CyclicDependenciesError(loop) {
    this.loop = loop;
    this.name = this.constructor.name;
    this.message = "Can't sort modules. Loop found: \n" + this.loop;
  }

  return CyclicDependenciesError;

})(Error);

UnresolvedDependencyError = (function(_super) {
  __extends(UnresolvedDependencyError, _super);

  function UnresolvedDependencyError(path, alias) {
    this.path = path;
    this.alias = alias;
    this.name = this.constructor.name;
    this.message = ("Can't resolve dependency `" + this.alias + "` ") + ("inside module `" + this.path + "`");
  }

  return UnresolvedDependencyError;

})(Error);

ExternalDependencyError = (function(_super) {
  __extends(ExternalDependencyError, _super);

  function ExternalDependencyError(path, alias, dep) {
    this.path = path;
    this.alias = alias;
    this.dep = dep;
    this.name = this.constructor.name;
    this.message = ("Module at path `" + dep + "` is required from `" + path + "` ") + ("as `" + alias + "`, but it cant be found inside building scope.");
  }

  return ExternalDependencyError;

})(Error);

NoCopyingRuleError = (function(_super) {
  __extends(NoCopyingRuleError, _super);

  function NoCopyingRuleError(path) {
    this.path = path;
    this.name = this.constructor.name;
    this.message = "No copying rule for module to be crypter at path `" + this.path + "`";
  }

  return NoCopyingRuleError;

})(Error);

Loop = (function() {
  function Loop() {
    this._parts = [];
  }

  Loop.prototype.prepend = function(path, alias) {
    this._parts.unshift([path, alias]);
    return this;
  };

  Loop.prototype.toString = function() {
    var i, p;
    if (this._parts.length === 0) {
      return "";
    }
    p = this._parts.concat([this._parts[0]]);
    return ((function() {
      var _i, _ref, _results;
      _results = [];
      for (i = _i = 0, _ref = this._parts.length - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
        _results.push("" + p[i][0] + " --[" + p[i][1] + "]--> " + p[i + 1][0]);
      }
      return _results;
    }).call(this)).join("\n");
  };

  return Loop;

})();

Logger = {
  info: function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return console.info(args.join(" "));
  },
  warn: function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return console.warn(clc.bgYellow.bold("SPA"), clc.yellow(args.join(" ")));
  },
  error: function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return console.error(clc.bgRed.bold("SPA"), clc.red.bold(args.join(" ")));
  }
};

encode_data = function(data) {
  var i, len, words;
  if (data instanceof Buffer) {
    words = [];
    len = data.length;
    i = 0;
    while (i < len) {
      words[i >>> 2] |= (data[i] & 0xff) << (24 - (i % 4) * 8);
      i++;
    }
    return CryptoJS.lib.WordArray.create(words, len);
  }
  if (data instanceof String || typeof data === "string") {
    return CryptoJS.enc.Utf8.parse(data);
  }
};

hashers = {
  md5: function(data) {
    var encoded_data, hash;
    encoded_data = encode_data(data);
    hash = CryptoJS.MD5(encoded_data);
    return hash.toString(CryptoJS.enc.Hex);
  },
  ripemd160: function(data) {
    var encoded_data, hash;
    encoded_data = encode_data(data);
    hash = CryptoJS.RIPEMD160(encoded_data);
    return hash.toString(CryptoJS.enc.Hex);
  },
  sha1: function(data) {
    var encoded_data, hash;
    encoded_data = encode_data(data);
    hash = CryptoJS.SHA1(encoded_data);
    return hash.toString(CryptoJS.enc.Hex);
  },
  sha224: function(data) {
    var encoded_data, hash;
    encoded_data = encode_data(data);
    hash = CryptoJS.SHA224(encoded_data);
    return hash.toString(CryptoJS.enc.Hex);
  },
  sha256: function(data) {
    var encoded_data, hash;
    encoded_data = encode_data(data);
    hash = CryptoJS.SHA256(encoded_data);
    return hash.toString(CryptoJS.enc.Hex);
  },
  sha384: function(data) {
    var encoded_data, hash;
    encoded_data = encode_data(data);
    hash = CryptoJS.SHA384(encoded_data);
    return hash.toString(CryptoJS.enc.Hex);
  },
  sha512: function(data) {
    var encoded_data, hash;
    encoded_data = encode_data(data);
    hash = CryptoJS.SHA512(encoded_data);
    return hash.toString(CryptoJS.enc.Hex);
  },
  sha3: function(data) {
    var encoded_data, hash;
    encoded_data = encode_data(data);
    hash = CryptoJS.SHA3(encoded_data);
    return hash.toString(CryptoJS.enc.Hex);
  }
};

encoders = {
  identity: function(data, builder) {
    return data;
  }
};

Builder = (function() {
  function Builder(options) {
    var name, pattern, template, type, value, _ref, _ref1, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8;
    this.root = path.resolve(process.cwd(), options.root) + "/";
    this.extensions = (_ref = options.extensions) != null ? _ref : [".js"];
    this.excludes = (_ref1 = options.excludes) != null ? _ref1 : [];
    this.paths = (_ref2 = options.paths) != null ? _ref2 : {};
    this.hosting = (function() {
      var _ref3, _ref4, _results;
      _ref4 = (_ref3 = options.hosting) != null ? _ref3 : {};
      _results = [];
      for (pattern in _ref4) {
        template = _ref4[pattern];
        _results.push({
          test: globrules.tester(pattern),
          transform: globrules.transformer(pattern, template)
        });
      }
      return _results;
    })();
    this.copying = (function() {
      var _ref3, _ref4, _results;
      _ref4 = (_ref3 = options.copying) != null ? _ref3 : {};
      _results = [];
      for (pattern in _ref4) {
        template = _ref4[pattern];
        _results.push({
          test: globrules.tester(pattern),
          transform: globrules.transformer(pattern, template)
        });
      }
      return _results;
    })();
    this.default_loader = (_ref3 = options.default_loader) != null ? _ref3 : "cjs";
    this.loaders = (function() {
      var _ref4, _ref5, _results;
      _ref5 = (_ref4 = options.loaders) != null ? _ref4 : {};
      _results = [];
      for (pattern in _ref5) {
        type = _ref5[pattern];
        _results.push({
          test: globrules.tester(pattern),
          type: type
        });
      }
      return _results;
    })();
    this.manifest = options.manifest;
    this.index = options.index;
    this._built_ins = ["loader"];
    this.pretty = (_ref4 = options.pretty) != null ? _ref4 : false;
    this.assets = {
      appcache_template: path.join(__dirname, "assets/appcache.tmpl"),
      index_template: path.join(__dirname, "assets/index.tmpl")
    };
    _ref5 = options.assets;
    for (name in _ref5) {
      if (!__hasProp.call(_ref5, name)) continue;
      value = _ref5[name];
      this.assets[name] = value;
    }
    this.appcache = options.appcache;
    this.cached = options.cached;
    this.hash_func = (_ref6 = options.hash_func) != null ? _ref6 : "md5";
    this.randomize_urls = (_ref7 = options.randomize_urls) != null ? _ref7 : true;
    this.coding_func = (_ref8 = options.coding_func) != null ? _ref8 : "identity";
    this._clear();
  }

  Builder.prototype.filter = function(filepath) {
    var expected;
    expected = path.extname(filepath);
    if (!_(this.extensions).any(function(ext) {
      return expected === ext;
    })) {
      return false;
    }
    return true;
  };

  Builder.prototype.calc_hash = function(content) {
    return hashers[this.hash_func](content);
  };

  Builder.prototype.calc_code = function(content) {
    return encoders[this.coding_func](content, this);
  };

  Builder.prototype._clear = function() {
    this._modules = [];
    this._by_path = {};
    return this._by_id = {};
  };

  Builder.prototype._relativate = function(filepath) {
    return './' + filepath.split(path.sep).join('/');
  };

  Builder.prototype._enlist = function(root) {
    var data, module, walked, _i, _len;
    walked = walker.walkSync({
      root: root,
      excludes: this.excludes
    });
    for (_i = 0, _len = walked.length; _i < _len; _i++) {
      data = walked[_i];
      if (!this.filter(data.relative)) {
        continue;
      }
      module = {
        path: data.path,
        relative: data.relative
      };
      this._by_path[data.path] = module;
      this._modules.push(module);
    }
  };

  Builder.prototype._set_ids = function() {
    var ext, id, module, newroot, root, _i, _len, _ref;
    _ref = this._modules;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      module = _ref[_i];
      ext = path.extname(module.path);
      root = path.dirname(module.path);
      id = path.basename(module.path, ext);
      if (id === "index") {
        id = path.basename(root);
        root = path.dirname(root);
      }
      while (id in this._by_id) {
        id = path.basename(root) + "/" + id;
        newroot = path.dirname(root);
        if (newroot === root) {
          break;
        }
        root = newroot;
      }
      id = id.split(/[^a-zA-Z0-9]/g).join("_");
      while (id in this._by_id) {
        id = "_" + id;
      }
      this._by_id[id] = module;
      module.id = id;
    }
  };

  Builder.prototype._resolve_to_file = function(filepath) {
    var stats;
    if (fs.existsSync(filepath)) {
      stats = fs.statSync(filepath);
      if (stats.isFile()) {
        return filepath;
      }
    }
  };

  Builder.prototype._resolve_to_directory = function(dirpath) {
    var stats;
    if (fs.existsSync(dirpath)) {
      stats = fs.statSync(dirpath);
      if (stats.isDirectory()) {
        return this._resolve_to_file(path.join(dirpath, "index.js"));
      }
    }
  };

  Builder.prototype._get_type = function(module) {
    var rule, _i, _len, _ref;
    _ref = this.loaders;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      rule = _ref[_i];
      if (!rule.test(module.relative)) {
        continue;
      }
      return rule.type;
    }
    switch (definition(module.path)) {
      case "commonjs":
        return "cjs";
      case "amd":
        return "amd";
    }
    return this.default_loader;
  };

  Builder.prototype._resolve = function(module, dep) {
    var alias, basedir, prefix, _ref, _ref1, _ref2;
    _ref = this.paths;
    for (alias in _ref) {
      prefix = _ref[alias];
      if (_(dep).startsWith(alias)) {
        dep = dep.replace(alias, prefix);
        break;
      }
    }
    if (_(dep).startsWith("/")) {
      dep = path.join(this.root, dep);
    } else if (_(dep).startsWith("./") || _(dep).startsWith("../")) {
      basedir = path.dirname(module.path);
      dep = path.resolve(basedir, dep);
    }
    return (_ref1 = (_ref2 = this._resolve_to_file(dep)) != null ? _ref2 : this._resolve_to_file(dep + ".js")) != null ? _ref1 : this._resolve_to_directory(dep);
  };

  Builder.prototype._analyze = function(module) {
    var dep, deps, resolved, source, _i, _len, _results;
    source = fs.readFileSync(module.path);
    module.deps_paths = {};
    deps = (function() {
      switch (module.type) {
        case "cjs":
          return detectiveCJS(source);
        case "amd":
          return detectiveAMD(source);
        default:
          return [];
      }
    })();
    _results = [];
    for (_i = 0, _len = deps.length; _i < _len; _i++) {
      dep = deps[_i];
      if (__indexOf.call(this._built_ins, dep) >= 0) {
        continue;
      }
      resolved = this._resolve(module, dep);
      if (resolved == null) {
        throw new UnresolvedDependencyError(module.relative, dep);
      }
      _results.push(module.deps_paths[dep] = resolved);
    }
    return _results;
  };

  Builder.prototype._find_loop = function(candidates) {
    var candidate, has_loop, walked, _go_deep, _i, _len;
    for (_i = 0, _len = candidates.length; _i < _len; _i++) {
      candidate = candidates[_i];
      walked = [];
      _go_deep = (function(_this) {
        return function(current) {
          var alias, deep, dep, deps, module, relative;
          module = _this._by_path[current];
          relative = module.relative;
          deps = module.deps_paths;
          for (alias in deps) {
            dep = deps[alias];
            if (__indexOf.call(candidates, dep) < 0) {
              continue;
            }
            if (__indexOf.call(walked, dep) >= 0) {
              continue;
            }
            if (dep === candidate) {
              return new Loop().prepend(relative, alias);
            }
            walked.push(dep);
            deep = _go_deep(dep);
            walked.pop();
            if (deep != null) {
              return deep.prepend(relative, alias);
            }
          }
        };
      })(this);
      has_loop = _go_deep(candidate);
      if (has_loop != null) {
        return has_loop;
      }
    }
  };

  Builder.prototype._sort = function() {
    var deps, left, module, mpath, order, use, _i, _len;
    left = (function() {
      var _i, _len, _ref, _results;
      _ref = this._modules;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        module = _ref[_i];
        _results.push(module.path);
      }
      return _results;
    }).call(this);
    order = [];
    while (left.length > 0) {
      use = [];
      for (_i = 0, _len = left.length; _i < _len; _i++) {
        mpath = left[_i];
        deps = this._by_path[mpath].deps_paths;
        if (!_(deps).any(function(dep) {
          return __indexOf.call(order, dep) < 0;
        })) {
          use.push(mpath);
        }
      }
      if (use.length === 0) {
        throw new CyclicDependenciesError(this._find_loop(left));
      }
      order.push.apply(order, use);
      left = left.filter(function(mpath) {
        return __indexOf.call(use, mpath) < 0;
      });
    }
    return this._modules = (function() {
      var _j, _len1, _results;
      _results = [];
      for (_j = 0, _len1 = order.length; _j < _len1; _j++) {
        mpath = order[_j];
        _results.push(this._by_path[mpath]);
      }
      return _results;
    }).call(this);
  };

  Builder.prototype._link = function() {
    var dep, module, resolved, _i, _len, _ref, _results;
    _ref = this._modules;
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      module = _ref[_i];
      module.deps_ids = {};
      _results.push((function() {
        var _ref1, _results1;
        _ref1 = module.deps_paths;
        _results1 = [];
        for (dep in _ref1) {
          resolved = _ref1[dep];
          if (this._by_path[resolved] != null) {
            _results1.push(module.deps_ids[dep] = this._by_path[resolved].id);
          } else {
            throw new ExternalDependencyError(module.relative, dep, resolved);
          }
        }
        return _results1;
      }).call(this));
    }
    return _results;
  };

  Builder.prototype._host = function(filepath) {
    var rule, _i, _len, _ref;
    _ref = this.hosting;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      rule = _ref[_i];
      if (!rule.test(filepath)) {
        continue;
      }
      return rule.transform(filepath);
    }
  };

  Builder.prototype._get_copying = function(filepath) {
    var rule, _i, _len, _ref;
    _ref = this.copying;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      rule = _ref[_i];
      if (!rule.test(filepath)) {
        continue;
      }
      return rule.transform(filepath);
    }
  };

  Builder.prototype._create_manifest = function() {
    var manifest, module, modules;
    modules = (function() {
      var _i, _len, _ref, _results;
      _ref = this._modules;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        module = _ref[_i];
        _results.push({
          id: module.id,
          url: module.url,
          hash: module.hash,
          size: module.size,
          type: module.type,
          deps: module.deps_ids
        });
      }
      return _results;
    }).call(this);
    manifest = {
      version: packagejson.version,
      hash_func: this.hash_func,
      modules: modules
    };
    return JSON.stringify(manifest, null, this.pretty ? "  " : void 0);
  };

  Builder.prototype._write_file = function(destination, content) {
    var filepath;
    filepath = path.resolve(this.root, destination);
    Logger.info("Writing " + filepath + ". " + content.length + " bytes.");
    return fs.writeFileSync(filepath, content);
  };

  Builder.prototype._inject_inline = function(relative) {
    var filepath;
    filepath = path.resolve(__dirname, "assets", relative);
    return fs.readFileSync(filepath, {
      encoding: "utf8"
    });
  };

  Builder.prototype._write_index = function() {
    var assets, compiled, content, filepath, name, namespace, relative, url, value, _ref;
    assets = {};
    namespace = {
      assets: assets
    };
    _ref = this.assets;
    for (name in _ref) {
      if (!__hasProp.call(_ref, name)) continue;
      value = _ref[name];
      content = fs.readFileSync(value, {
        encoding: "utf8"
      });
      namespace[name] = content;
      assets[name] = content;
    }
    namespace["manifest_location"] = "manifest.json";
    namespace["randomize_urls"] = this.randomize_urls;
    namespace["inline"] = (function(_this) {
      return function(relative) {
        return _this._inject_inline(relative);
      };
    })(this);
    namespace["version"] = packagejson.version;
    namespace["hash_name"] = this.hash_func;
    namespace["decoder_name"] = this.coding_func;
    namespace["ask_password"] = this.password != null;
    if (this.manifest != null) {
      filepath = path.resolve(this.root, this.manifest);
      relative = this._relativate(path.relative(this.root, filepath));
      url = this._host(relative);
      if (url != null) {
        namespace["manifest_location"] = url;
      } else {
        Logger.warn("Manifest file hosted as `manifest.json` and will be accesible relatively");
      }
    }
    compiled = ejs.compile(assets["index_template"]);
    this._index_content = compiled(namespace);
    return this._write_file(this.index, this._index_content);
  };

  Builder.prototype._write_appcache = function() {
    var assets, compiled, content, filename, filepath, relative, template, url, _i, _len, _ref;
    assets = {};
    _ref = this.cached;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      filename = _ref[_i];
      filepath = path.resolve(this.root, filename);
      relative = this._relativate(path.relative(this.root, filepath));
      url = this._host(relative);
      if (url == null) {
        continue;
      }
      content = fs.readFileSync(filepath, {
        encoding: "utf8"
      });
      assets[url] = this.calc_hash(content);
    }
    if (this.index != null) {
      filepath = path.resolve(this.root, this.index);
      relative = this._relativate(path.relative(this.root, filepath));
      url = this._host(relative);
      if (url != null) {
        filename = path.resolve(this.root, this.index);
        assets[url] = this.calc_hash(this._index_content);
      }
    }
    if (Object.keys(assets).length === 0) {
      if (this.index != null) {
        Logger.warn("No hosting rule for `" + this.index + "` file. AppCache manifest `" + this.appcache + "` appears to be empty");
      } else {
        Logger.warn("There are no assets to be included into AppCache manifest `" + this.appcache + "`");
      }
    }
    template = this.assets["appcache_template"];
    compiled = ejs.compile(fs.readFileSync(template, {
      encoding: "utf8"
    }));
    content = compiled({
      assets: assets
    });
    return this._write_file(this.appcache, content);
  };

  Builder.prototype.build = function() {
    var destination, manifest_content, module, output, source, _i, _j, _k, _len, _len1, _len2, _ref, _ref1, _ref2;
    this._enlist(this.root);
    this._set_ids();
    _ref = this._modules;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      module = _ref[_i];
      module.type = this._get_type(module);
      this._analyze(module);
    }
    this._link();
    this._sort();
    _ref1 = this._modules;
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      module = _ref1[_j];
      module.url = this._host(module.relative);
      if (module.url == null) {
        Logger.error("No hosting rules for `" + module.relative + "`");
      }
    }
    _ref2 = this._modules;
    for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
      module = _ref2[_k];
      source = fs.readFileSync(module.path);
      destination = this._get_copying(module.relative);
      if (!((destination != null) || this.coding_func === "identity")) {
        throw new NoCopyingRuleError(module.relative);
      }
      output = this.calc_code(source);
      if (destination != null) {
        this._write_file(destination, output);
        Logger.info("Writing " + destination + ".");
      }
      module.hash = this.calc_hash(output);
      module.size = output.length;
    }
    manifest_content = this._create_manifest();
    if (this.manifest != null) {
      this._write_file(this.manifest, manifest_content);
    }
    if (this.index != null) {
      this._write_index();
    }
    if (this.appcache != null) {
      this._write_appcache();
    }
    this._print_stats();
    return manifest_content;
  };

  Builder.prototype._print_stats = function() {
    var message, module, num, total, _ref;
    total = 0;
    _ref = this._modules;
    for (num in _ref) {
      module = _ref[num];
      total += module.size;
      message = _.sprintf("%(num)3s %(module.relative)-20s %(module.size)7s %(module.type)4s %(module.hash)s", {
        num: parseInt(num) + 1,
        module: module
      });
      Logger.info(message);
    }
    return Logger.info("Total " + total + " bytes in " + this._modules.length + " files");
  };

  return Builder;

})();

hasBOM = function(data) {
  if (data.length < 3) {
    return false;
  }
  if (data[0] !== 0xef) {
    return false;
  }
  if (data[1] !== 0xbb) {
    return false;
  }
  if (data[2] !== 0xbf) {
    return false;
  }
  return true;
};

load_json = function(filepath) {
  var source;
  if (filepath == null) {
    return;
  }
  source = fs.readFileSync(filepath);
  return JSON.parse(source);
};

load_yaml = function(filepath) {
  var data, source;
  if (filepath == null) {
    return;
  }
  data = fs.readFileSync(filepath);
  source = data.toString("utf8", hasBOM(data) ? 3 : 0);
  return yaml.safeLoad(source);
};

get_config_content = function(filepath) {
  switch (path.extname(filepath)) {
    case ".yaml":
    case ".yml":
      return load_yaml(filepath);
    case ".json":
      return load_json(filepath);
  }
};

Builder.from_config = function(config_path) {
  var basedir, config;
  Logger.info("Reading config from " + config_path);
  basedir = path.dirname(config_path);
  config = get_config_content(config_path);
  if (config.root == null) {
    config.root = ".";
  }
  config.root = path.resolve(basedir, config.root);
  return new Builder(config);
};

exports.Builder = Builder;

exports.CyclicDependenciesError = CyclicDependenciesError;

exports.UnresolvedDependencyError = UnresolvedDependencyError;

exports.ExternalDependencyError = ExternalDependencyError;

exports.Loop = Loop;
