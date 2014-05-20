var Builder, CyclicDependenciesError, ExternalDependencyError, Loop, UnresolvedDependencyError, crypto, definition, detectiveAMD, detectiveCJS, ejs, fs, get_config_content, globStringToRegex, load_json, load_yaml, make_md5, path, preg_quote, walk, yaml, _,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

fs = require('fs');

walk = require('fs-walk');

path = require('path');

detectiveCJS = require('detective');

detectiveAMD = require('detective-amd');

definition = require('module-definition').sync;

crypto = require('crypto');

yaml = require('js-yaml');

ejs = require("ejs");

_ = require('underscore');

_.string = require('underscore.string');

_.mixin(_.string.exports());

preg_quote = function(str, delimiter) {
  return (str + '').replace(new RegExp('[.\\\\+*?\\[\\^\\]${}=!<>|:\\' + (delimiter || '') + '-]', 'g'), '\\$&');
};

globStringToRegex = function(str) {
  return new RegExp(preg_quote(str).replace(/\\\*\\\*\//g, '(?:[^/]+/)*').replace(/\\\*/g, '[^/]*').replace(/\\\?/g, '[^/]'), 'm');
};

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

make_md5 = function(content) {
  return crypto.createHash('md5').update(content).digest('hex');
};

Builder = (function() {
  function Builder(options) {
    var name, pattern, template, type, value, _ref, _ref1, _ref2, _ref3, _ref4, _ref5;
    this.root = path.resolve(process.cwd(), options.root);
    this.extensions = (_ref = options.extensions) != null ? _ref : [".js"];
    this.excludes = _((_ref1 = options.excludes) != null ? _ref1 : []).map(globStringToRegex);
    this.paths = (_ref2 = options.paths) != null ? _ref2 : {};
    this.hosting = (function() {
      var _ref3, _ref4, _results;
      _ref4 = (_ref3 = options.hosting) != null ? _ref3 : {};
      _results = [];
      for (pattern in _ref4) {
        template = _ref4[pattern];
        _results.push({
          pattern: globStringToRegex(pattern),
          template: template
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
          pattern: globStringToRegex(pattern),
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
      index_template: path.join(__dirname, "assets/index.tmpl"),
      md5: path.join(__dirname, "assets/md5.js"),
      loader: path.join(__dirname, "assets/loader.js"),
      fake_app: path.join(__dirname, "assets/fake/app.js"),
      fake_manifest: path.join(__dirname, "assets/fake/manifest.json")
    };
    _ref5 = options.assets;
    for (name in _ref5) {
      if (!__hasProp.call(_ref5, name)) continue;
      value = _ref5[name];
      this.assets[name] = value;
    }
    this.appcache = options.appcache;
    this.cached = options.cached;
    this._clear();
  }

  Builder.prototype.filter = function(filepath) {
    if (!_(this.extensions).any(function(ext) {
      return path.extname(filepath) === ext;
    })) {
      return false;
    }
    return !_(this.excludes).any(function(pattern) {
      return pattern.test(filepath);
    });
  };

  Builder.prototype._clear = function() {
    this._modules = [];
    this._by_path = {};
    return this._by_id = {};
  };

  Builder.prototype._relativate = function(filepath) {
    return '/' + filepath.split(path.sep).join('/');
  };

  Builder.prototype._enlist = function(root) {
    walk.filesSync(root, (function(_this) {
      return function(basedir, filename, stat) {
        var filepath, module, relative;
        filepath = path.resolve(basedir, filename);
        relative = _this._relativate(path.relative(root, filepath));
        if (!_this.filter(relative)) {
          return;
        }
        module = {
          path: filepath,
          relative: relative
        };
        _this._by_path[filepath] = module;
        return _this._modules.push(module);
      };
    })(this));
  };

  Builder.prototype._set_ids = function() {
    var ext, id, module, root, _i, _len, _ref;
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
        id = path.basename(root) + "|" + id;
        root = path.dirname(root);
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
      if (!rule.pattern.test(module.relative)) {
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
    module.md5 = make_md5(source);
    module.size = source.length;
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
      if (!rule.pattern.test(filepath)) {
        continue;
      }
      return filepath.replace(rule.pattern, rule.template);
    }
  };

  Builder.prototype._write_manifest = function() {
    var content, data, filename, module;
    data = (function() {
      var _i, _len, _ref, _results;
      _ref = this._modules;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        module = _ref[_i];
        _results.push({
          id: module.id,
          url: module.url,
          md5: module.md5,
          size: module.size,
          type: module.type,
          deps: module.deps_ids
        });
      }
      return _results;
    }).call(this);
    filename = path.resolve(this.root, this.manifest);
    content = JSON.stringify(data, null, this.pretty ? "  " : void 0);
    console.log("Writing " + filename);
    return fs.writeFileSync(filename, content);
  };

  Builder.prototype._write_index = function() {
    var assets, compiled, filename, name, value, _ref;
    assets = {};
    _ref = this.assets;
    for (name in _ref) {
      if (!__hasProp.call(_ref, name)) continue;
      value = _ref[name];
      assets[name] = fs.readFileSync(value, {
        encoding: "utf8"
      });
    }
    compiled = ejs.compile(assets["index_template"]);
    filename = path.resolve(this.root, this.index);
    this._index_content = compiled(assets);
    console.log("Writing " + filename);
    return fs.writeFileSync(filename, this._index_content);
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
      assets[url] = make_md5(content);
    }
    if (this.index != null) {
      filepath = path.resolve(this.root, this.index);
      relative = this._relativate(path.relative(this.root, filepath));
      url = this._host(relative);
      if (url != null) {
        filename = path.resolve(this.root, this.index);
        assets[url] = make_md5(this._index_content);
      }
    }
    if (assets.length === 0) {
      if (this.index != null) {
        console.log("No hosting rule for `" + this.index + "` file. AppCache manifest `" + this.appcache + "` appears to be empty");
      } else {
        console.log("There are no assets to be included into AppCache manifest `" + this.appcache + "`");
      }
    }
    template = this.assets["appcache_template"];
    compiled = ejs.compile(fs.readFileSync(template, {
      encoding: "utf8"
    }));
    filename = path.resolve(this.root, this.appcache);
    content = compiled({
      assets: assets
    });
    console.log("Writing " + filename);
    return fs.writeFileSync(filename, content);
  };

  Builder.prototype.build = function() {
    var module, _i, _j, _len, _len1, _ref, _ref1;
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
    }
    if (this.manifest != null) {
      this._write_manifest();
    }
    if (this.index != null) {
      this._write_index();
    }
    if (this.appcache != null) {
      this._write_appcache();
    }
  };

  return Builder;

})();

load_json = function(filepath) {
  var source;
  if (filepath == null) {
    return;
  }
  source = fs.readFileSync(filepath);
  return JSON.parse(source);
};

load_yaml = function(filepath) {
  var source;
  if (filepath == null) {
    return;
  }
  source = fs.readFileSync(filepath, {
    encoding: "utf8"
  });
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
  console.log("Reading config from " + config_path);
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
