var Builder, CyclicDependenciesError, DB, ExternalDependencyError, HostingUrlOverwritingError, Logger, Loop, ModuleFileOverwritingError, ModuleTypeError, NoCopyingRuleError, UnresolvedDependencyError, amdType, clc, console, crypto, definition, detectiveAMD, detectiveCJS, ejs, encoders, eval_file, fs, get_config_content, globrules, hasBOM, hashers, load_json, load_yaml, mkdirpSync, packagejson, path, resolve, sandbox, vm, walker, yaml, _,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

fs = require('fs');

vm = require("vm");

walker = require('fs-walk-glob-rules');

globrules = require('glob-rules');

path = require('path');

clc = require('cli-color');

mkdirpSync = require('mkdirp').sync;

detectiveCJS = require('detective');

detectiveAMD = require('detective-amd');

definition = require('module-definition').fromSource;

amdType = require('get-amd-module-type').fromSource;

yaml = require('js-yaml');

ejs = require("ejs");

_ = require('lodash');

_.string = require('underscore.string');

_.mixin(_.string.exports());

crypto = require("crypto");

resolve = require("resolve");

console = require("./console");

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

ModuleTypeError = (function(_super) {
  __extends(ModuleTypeError, _super);

  function ModuleTypeError(path, error) {
    var _ref;
    this.path = path;
    this.error = error;
    this.name = this.constructor.name;
    this.message = "Can't determine type of module at `" + this.path + "`: " + ((_ref = this.error) != null ? _ref.toString() : void 0);
  }

  return ModuleTypeError;

})(Error);

ModuleFileOverwritingError = (function(_super) {
  __extends(ModuleFileOverwritingError, _super);

  function ModuleFileOverwritingError(path) {
    this.path = path;
    this.name = this.constructor.name;
    this.message = "Several modules are about to be wrote into `" + this.path + "`. Please revisit your `copying` rules.";
  }

  return ModuleFileOverwritingError;

})(Error);

HostingUrlOverwritingError = (function(_super) {
  __extends(HostingUrlOverwritingError, _super);

  function HostingUrlOverwritingError(url) {
    this.url = url;
    this.name = this.constructor.name;
    this.message = "Several modules are about to be hosted `" + this.url + "`. Please revisit your `hosting` rules.";
  }

  return HostingUrlOverwritingError;

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

Logger = (function() {
  function Logger(prefix) {
    this.prefix = prefix;
  }

  Logger.prototype.info = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return console.info(args.join(" "));
  };

  Logger.prototype.warn = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return console.warn(clc.bgYellow.bold(this.prefix), clc.yellow(args.join(" ")));
  };

  Logger.prototype.error = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return console.error(clc.bgRed.bold(this.prefix), clc.red.bold(args.join(" ")));
  };

  return Logger;

})();

DB = (function() {
  function DB(filename) {
    this.filename = filename;
    if ((this.filename != null) && fs.existsSync(this.filename)) {
      this._data = JSON.parse(fs.readFileSync(this.filename));
    } else {
      this._data = {};
    }
  }

  DB.prototype.get = function(key) {
    var content;
    content = this._data[key];
    if (content != null) {
      return JSON.parse(content);
    }
  };

  DB.prototype.set = function(key, value) {
    return this._data[key] = JSON.stringify(value);
  };

  DB.prototype.del = function(key) {
    return delete this._data[key];
  };

  DB.prototype.has = function(key) {
    return this._data.hasOwnProperty(key);
  };

  DB.prototype.flush = function() {
    return fs.writeFileSync(this.filename, JSON.stringify(this._data));
  };

  return DB;

})();

sandbox = function() {
  var result, window;
  window = {};
  window.window = window;
  result = {
    ArrayBuffer: Object.freeze(ArrayBuffer),
    Buffer: Object.freeze(Buffer),
    Uint8Array: Object.freeze(Uint8Array),
    console: Object.freeze(console),
    window: Object.freeze(window),
    Uint32Array: Object.freeze(Uint32Array)
  };
  return result;
};

eval_file = function(p, s) {
  return vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, p), "utf8"), sandbox());
};

hashers = {
  md5: function(data) {
    return crypto.createHash("md5").update(data).digest('hex');
  },
  ripemd160: function(data) {
    return crypto.createHash("ripemd160").update(data).digest('hex');
  },
  sha1: function(data) {
    return crypto.createHash("sha1").update(data).digest('hex');
  },
  sha224: function(data) {
    return crypto.createHash("sha224").update(data).digest('hex');
  },
  sha256: function(data) {
    return crypto.createHash("sha256").update(data).digest('hex');
  },
  sha384: function(data) {
    return crypto.createHash("sha384").update(data).digest('hex');
  },
  sha512: function(data) {
    return crypto.createHash("sha512").update(data).digest('hex');
  },
  sha3: eval_file("./assets/hash/sha3.js")
};

encoders = {
  "aes-ccm": eval_file("./assets/encode/aes-ccm.js"),
  "aes-gcm": eval_file("./assets/encode/aes-gcm.js"),
  "aes-ocb2": eval_file("./assets/encode/aes-ocb2.js")
};

Builder = (function() {
  function Builder(options) {
    var name, pattern, template, type, value, _base, _ref, _ref1, _ref10, _ref11, _ref12, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _ref9;
    this._built_ins = ["loader", "require", "module", "exports"];
    this.options = options;
    if ((_base = this.options).logger == null) {
      _base.logger = "SPA";
    }
    if (_.isString(options.logger)) {
      this.logger = this._create_logger();
    } else {
      this.logger = options.logger;
    }
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
    this.hosting_map = options.hosting_map;
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
    this.bundle = options.bundle;
    this.manifest = options.manifest;
    this.index = options.index;
    this.pretty = (_ref4 = options.pretty) != null ? _ref4 : false;
    this.grab = (_ref5 = options.grab) != null ? _ref5 : false;
    this.print_stats = (_ref6 = options.print_stats) != null ? _ref6 : true;
    this.print_roots = (_ref7 = options.print_roots) != null ? _ref7 : true;
    this.assets = {
      appcache_template: path.join(__dirname, "assets/appcache.tmpl"),
      index_template: path.join(__dirname, "assets/index.tmpl")
    };
    _ref8 = options.assets;
    for (name in _ref8) {
      if (!__hasProp.call(_ref8, name)) continue;
      value = _ref8[name];
      this.assets[name] = value;
    }
    this.appcache = options.appcache;
    this.cached = (_ref9 = options.cached) != null ? _ref9 : [];
    this.hash_func = (_ref10 = options.hash_func) != null ? _ref10 : "md5";
    this.randomize_urls = (_ref11 = options.randomize_urls) != null ? _ref11 : true;
    this.coding_func = options.coding_func;
    this.cache = this._create_db(path.resolve(this.root, (_ref12 = options.cache_file) != null ? _ref12 : ".spacache"));
  }

  Builder.prototype._create_db = function(path) {
    return new DB(path);
  };

  Builder.prototype._create_logger = function(name) {
    return new Logger(name);
  };

  Builder.prototype._filter = function(filepath) {
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

  Builder.prototype.encode = function(content, module) {
    var encoder;
    encoder = encoders[this.coding_func.name];
    return encoder(content, module, this);
  };

  Builder.prototype._relativate = function(filepath) {
    return this.walker.normalize(filepath);
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

  Builder.prototype._host_path = function(relative) {
    var rule, _i, _len, _ref;
    _ref = this.hosting;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      rule = _ref[_i];
      if (!rule.test(relative)) {
        continue;
      }
      return rule.transform(relative);
    }
    return this.logger.error("No hosting rules for `" + relative + "`");
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

  Builder.prototype._get_type = function(module, source) {
    var error, rule, _i, _len, _ref;
    _ref = this.loaders;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      rule = _ref[_i];
      if (!rule.test(module.relative)) {
        continue;
      }
      return rule.type;
    }
    try {
      switch (definition(module.source)) {
        case "commonjs":
          return "cjs";
        case "amd":
          return "amd";
      }
    } catch (_error) {
      error = _error;
      throw new ModuleTypeError(module.path, error);
    }
    return this.default_loader;
  };

  Builder.prototype._resolve = function(module, dep) {
    var alias, basedir, prefix, _ref, _ref1, _ref2;
    _ref = this.paths;
    for (alias in _ref) {
      prefix = _ref[alias];
      if (!_.startsWith(dep, alias)) {
        continue;
      }
      if ((dep[alias.length] || "/") === "/") {
        dep = dep.replace(alias, prefix);
        break;
      }
    }
    if (_.startsWith(dep, "/")) {
      dep = path.join(this.root, dep);
    } else if (_.startsWith(dep, "./") || _.startsWith(dep, "../")) {
      basedir = path.dirname(module.path);
      dep = path.resolve(basedir, dep);
    } else {
      try {
        return resolve.sync(dep, {
          basedir: path.dirname(module.path),
          extensions: this.extensions
        });
      } catch (_error) {
        return null;
      }
    }
    return (_ref1 = (_ref2 = this._resolve_to_file(dep)) != null ? _ref2 : this._resolve_to_file(dep + ".js")) != null ? _ref1 : this._resolve_to_directory(dep);
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

  Builder.prototype._write_file = function(destination, content) {
    var filepath;
    filepath = path.resolve(this.root, destination);
    this.logger.info("Writing " + filepath + ". " + content.length + " bytes.");
    mkdirpSync(path.dirname(filepath));
    return fs.writeFileSync(filepath, content);
  };

  Builder.prototype._stringify_json = function(data) {
    return JSON.stringify(data, null, this.pretty ? "  " : void 0);
  };

  Builder.prototype._inject_inline = function(relative) {
    var filepath;
    filepath = path.resolve(__dirname, "assets", relative);
    return fs.readFileSync(filepath, {
      encoding: "utf8"
    });
  };

  Builder.prototype._clear = function() {
    this._modules = [];
    this._by_path = {};
    this._by_id = {};
    this._manifest_content = void 0;
    return this._index_content = void 0;
  };

  Builder.prototype._enlist = function() {
    var data, module, _i, _len, _ref;
    this.walker = new walker.SyncWalker({
      root: this.root,
      excludes: this.excludes
    });
    _ref = this.walker.walk();
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      data = _ref[_i];
      if (!this._filter(data.relative)) {
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

  Builder.prototype._analyze = function() {
    var dep, deps, module, modules, resolved, source, submodule, _i, _len;
    modules = this._modules.concat();
    while (modules.length > 0) {
      module = modules.shift();
      source = fs.readFileSync(module.path);
      module.source = source.toString('utf8');
      module.deps_paths = {};
      module.type = this._get_type(module);
      switch (module.type) {
        case "amd":
          module.amdtype = amdType(module.source);
      }
      module.source_hash = this.calc_hash(source);
      module.source_length = source.length;
      deps = (function() {
        switch (module.type) {
          case "cjs":
            return detectiveCJS(module.source);
          case "amd":
            return detectiveAMD(module.source);
          default:
            return [];
        }
      })();
      for (_i = 0, _len = deps.length; _i < _len; _i++) {
        dep = deps[_i];
        if (__indexOf.call(this._built_ins, dep) >= 0) {
          continue;
        }
        resolved = this._resolve(module, dep);
        if (resolved == null) {
          throw new UnresolvedDependencyError(module.relative, dep);
        }
        module.deps_paths[dep] = resolved;
        if (this.grab && !this._by_path[resolved]) {
          submodule = {
            path: resolved,
            relative: this._relativate(resolved)
          };
          this._by_path[resolved] = submodule;
          this._modules.push(submodule);
          modules.push(submodule);
        }
      }
    }
  };

  Builder.prototype._host = function() {
    var module, url, urls, _i, _len, _ref;
    urls = {};
    _ref = this._modules;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      module = _ref[_i];
      url = this._host_path(module.relative);
      if (!url) {
        continue;
      }
      if (url in urls) {
        throw new HostingUrlOverwritingError(url);
      }
      urls[url] = module;
      module.url = url;
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

  Builder.prototype._encode = function() {
    var destination, module, output, paths, source, _contents, _i, _j, _len, _len1, _ref, _ref1;
    _contents = [];
    if (this.coding_func != null) {
      paths = {};
      _ref = this._modules;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        module = _ref[_i];
        destination = this._get_copying(module.relative);
        if (destination == null) {
          throw new NoCopyingRuleError(module.relative);
        }
        if (destination in paths) {
          throw new ModuleFileOverwritingError(destination);
        }
        paths[destination] = module;
        source = fs.readFileSync(module.path);
        output = this.encode(source, module);
        if (this.bundle) {
          _contents.push(output);
        }
        this._write_file(destination, output);
        module.hash = this.calc_hash(output);
        module.size = output.length;
      }
    } else {
      _ref1 = this._modules;
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        module = _ref1[_j];
        module.hash = module.source_hash;
        module.size = module.source_length;
        if (this.bundle) {
          source = fs.readFileSync(module.path);
          _contents.push(source);
        }
      }
    }
    this._bundle_content = _contents.join("");
  };

  Builder.prototype._create_manifest = function() {
    var bundle, filepath, module, modules, relative, url;
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
          amdtype: module.amdtype,
          deps: module.deps_ids,
          decoding: module.decoding
        });
      }
      return _results;
    }).call(this);
    this._manifest_content = {
      version: packagejson.version,
      hash_func: this.hash_func,
      modules: modules
    };
    if (this.bundle) {
      filepath = path.resolve(this.root, this.bundle);
      relative = this._relativate(filepath);
      url = this._host_path(relative);
      bundle = {
        hash: this.calc_hash(new Buffer(this._bundle_content, "utf8")),
        url: url
      };
      this._manifest_content.bundle = bundle;
    }
    if (this.coding_func != null) {
      this._manifest_content.decoder_func = this.coding_func.name;
    }
    return this._manifest_content;
  };

  Builder.prototype._create_hosting_map = function() {
    var filepath, files, map, module, relative, url, _i, _len, _ref;
    files = {};
    _ref = this._modules;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      module = _ref[_i];
      files[module.url] = module.relative;
    }
    map = {
      version: packagejson.version,
      files: files
    };
    if (this.bundle) {
      filepath = path.resolve(this.root, this.bundle);
      relative = this._relativate(filepath);
      url = this._host_path(relative);
      if (url != null) {
        map.bundle = {
          path: relative,
          url: url
        };
      }
    }
    if (this.manifest) {
      filepath = path.resolve(this.root, this.manifest);
      relative = this._relativate(filepath);
      url = this._host_path(relative);
      if (url != null) {
        map.manifest = {
          path: relative,
          url: url
        };
      }
    }
    if (this.index) {
      filepath = path.resolve(this.root, this.index);
      relative = this._relativate(filepath);
      url = this._host_path(relative);
      if (url != null) {
        map.index = {
          path: relative,
          url: url
        };
      }
    }
    if (this.appcache != null) {
      filepath = path.resolve(this.root, this.appcache);
      relative = this._relativate(filepath);
      url = this._host_path(relative);
      if (url != null) {
        map.appcache = {
          path: relative,
          url: url
        };
      }
    }
    return map;
  };

  Builder.prototype._create_index = function() {
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
    namespace["decoder_name"] = this.coding_func != null ? this.coding_func.name : "identity";
    namespace["passcode_required"] = this.coding_func != null;
    if (this.manifest != null) {
      filepath = path.resolve(this.root, this.manifest);
      relative = this._relativate(filepath);
      url = this._host_path(relative);
      if (url != null) {
        namespace["manifest_location"] = url;
      } else {
        this.logger.warn("Manifest file hosted as `" + relative + "` and will be accesible relatively");
      }
    }
    if (this.appcache != null) {
      filepath = path.resolve(this.root, this.appcache);
      relative = this._relativate(filepath);
      url = this._host_path(relative);
      if (url != null) {
        namespace["appcache_location"] = url;
      } else {
        this.logger.warn("AppCache manifest file location can't be automatically calculated for index.html");
      }
    }
    compiled = ejs.compile(assets["index_template"]);
    this._index_content = compiled(namespace);
    return this._index_content;
  };

  Builder.prototype._create_appcache = function() {
    var assets, compiled, content, filename, filepath, relative, template, url, _i, _len, _ref;
    assets = {};
    _ref = this.cached;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      filename = _ref[_i];
      filepath = path.resolve(this.root, filename);
      relative = this._relativate(filepath);
      url = this._host_path(relative);
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
      relative = this._relativate(filepath);
      url = this._host_path(relative);
      if (url != null) {
        filename = path.resolve(this.root, this.index);
        assets[url] = this.calc_hash(this._index_content);
      }
    }
    if (Object.keys(assets).length === 0) {
      if (this.index != null) {
        this.logger.warn("No hosting rule for `" + this.index + "` file. AppCache manifest `" + this.appcache + "` appears to be empty");
      } else {
        this.logger.warn("There are no assets to be included into AppCache manifest `" + this.appcache + "`");
      }
    }
    template = this.assets["appcache_template"];
    compiled = ejs.compile(fs.readFileSync(template, {
      encoding: "utf8"
    }));
    content = compiled({
      cached: assets
    });
    return content;
  };

  Builder.prototype._print_roots = function() {
    var all_deps, dep, dep_path, message, module, num, roots, _i, _j, _len, _len1, _ref, _ref1, _ref2, _ref3, _results;
    all_deps = [];
    _ref = this._modules;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      module = _ref[_i];
      _ref1 = module.deps_ids;
      for (dep_path in _ref1) {
        dep = _ref1[dep_path];
        all_deps.push(dep);
      }
    }
    roots = [];
    _ref2 = this._modules;
    for (_j = 0, _len1 = _ref2.length; _j < _len1; _j++) {
      module = _ref2[_j];
      if (_ref3 = module.id, __indexOf.call(all_deps, _ref3) >= 0) {
        continue;
      }
      roots.push(module);
    }
    if (roots.length === 0) {
      return;
    }
    this.logger.info("Possible roots: ");
    _results = [];
    for (num in roots) {
      module = roots[num];
      message = _.sprintf("%(num)3s %(module.relative)s", {
        num: parseInt(num) + 1,
        module: module
      });
      _results.push(this.logger.info(message));
    }
    return _results;
  };

  Builder.prototype._print_stats = function() {
    var message, module, num, total, _ref;
    this.logger.info("Statistics: ");
    total = 0;
    _ref = this._modules;
    for (num in _ref) {
      module = _ref[num];
      total += module.size;
      message = _.sprintf("%(num)3s %(module.relative)-40s %(module.size)7s %(type)-11s %(module.hash)s", {
        num: parseInt(num) + 1,
        module: module,
        type: module.type === "amd" ? module.type + "/" + module.amdtype : module.type
      });
      this.logger.info(message);
    }
    return this.logger.info("Total " + total + " bytes in " + this._modules.length + " files");
  };

  Builder.prototype.build = function() {
    this._clear();
    this._enlist();
    this._analyze();
    this._host();
    this._set_ids();
    this._link();
    if (this.print_roots) {
      this._print_roots();
    }
    this._sort();
    this._encode();
    if (this.manifest != null) {
      this._write_file(this.manifest, this._stringify_json(this._create_manifest()));
    }
    if (this.hosting_map != null) {
      this._write_file(this.hosting_map, this._stringify_json(this._create_hosting_map()));
    }
    if (this.index != null) {
      this._write_file(this.index, this._create_index());
    }
    if (this.appcache != null) {
      this._write_file(this.appcache, this._create_appcache());
    }
    if (this.bundle != null) {
      this._write_file(this.bundle, this._bundle_content);
    }
    if (this.print_stats) {
      this._print_stats();
    }
    this.cache.flush();
    return this._manifest_content;
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

Builder.from_config = function(config_path, options) {
  var basedir, config, name, value, _ref;
  basedir = path.dirname(config_path);
  config = get_config_content(config_path);
  _ref = options != null ? options : {};
  for (name in _ref) {
    if (!__hasProp.call(_ref, name)) continue;
    value = _ref[name];
    config[name] = value;
  }
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

exports.ModuleTypeError = ModuleTypeError;

exports.ModuleFileOverwritingError = ModuleFileOverwritingError;

exports.HostingUrlOverwritingError = HostingUrlOverwritingError;

exports.Loop = Loop;

exports.Logger = Logger;

exports.DB = DB;

exports.hashers = hashers;

exports.encoders = encoders;
