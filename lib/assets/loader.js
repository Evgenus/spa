var AMDEvaluator, AMDReturnsNothingError, AbstractMethodError, BasicEvaluator, CJSEvaluator, ChangesInWindowError, ExportsViolationError, Loader, NoSourceError, PollutionEvaluator, RawEvaluator, ReturnPollutionError, SAFE_CHARS, ThisPollutionError, UndeclaredRequireError, XHR, decodeUtf8, hasBOM, waitAll,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

AbstractMethodError = (function(_super) {
  __extends(AbstractMethodError, _super);

  function AbstractMethodError() {
    this.name = "AbstractMethodError";
    this.message = "Calling abstract method detected.";
  }

  return AbstractMethodError;

})(Error);

UndeclaredRequireError = (function(_super) {
  __extends(UndeclaredRequireError, _super);

  function UndeclaredRequireError(self_name, require_name) {
    this.self_name = self_name;
    this.require_name = require_name;
    this.name = "UndeclaredRequireError";
    this.message = "Found unreserved attempt to require of `" + this.require_name + "` inside `" + this.self_name + "`";
  }

  return UndeclaredRequireError;

})(Error);

ChangesInWindowError = (function(_super) {
  __extends(ChangesInWindowError, _super);

  function ChangesInWindowError(self_name, props) {
    this.self_name = self_name;
    this.props = props;
    this.name = "ChangesInWindowError";
    this.message = "During `" + this.self_name + "` loading window object was polluted with: " + props;
  }

  return ChangesInWindowError;

})(Error);

NoSourceError = (function(_super) {
  __extends(NoSourceError, _super);

  function NoSourceError(url) {
    this.url = url;
    this.name = "NoSourceError";
    this.message = "Module " + this.url + " source was not found in local database. Probably it was not loaded.";
  }

  return NoSourceError;

})(Error);

ExportsViolationError = (function(_super) {
  __extends(ExportsViolationError, _super);

  function ExportsViolationError(self_name) {
    this.self_name = self_name;
    this.name = "ExportsViolationError";
    this.message = "Modules `" + this.self_name + "` overrides own exports by replacing. `exports` != `module.exports`";
  }

  return ExportsViolationError;

})(Error);

ReturnPollutionError = (function(_super) {
  __extends(ReturnPollutionError, _super);

  function ReturnPollutionError(self_name, props) {
    this.self_name = self_name;
    this.props = props;
    this.name = "ReturnPollutionError";
    this.message = "Code of `" + this.self_name + "` contains `return` statement in module scope.";
  }

  return ReturnPollutionError;

})(Error);

ThisPollutionError = (function(_super) {
  __extends(ThisPollutionError, _super);

  function ThisPollutionError(self_name, props) {
    this.self_name = self_name;
    this.props = props;
    this.name = "ThisPollutionError";
    this.message = "Code of `" + this.self_name + "` trying to modify host object.";
  }

  return ThisPollutionError;

})(Error);

AMDReturnsNothingError = (function(_super) {
  __extends(AMDReturnsNothingError, _super);

  function AMDReturnsNothingError(self_name) {
    this.self_name = self_name;
    this.name = "AMDReturnsNothingError";
    this.message = "AMD module `" + this.self_name + "` returns nothing. Should return empty object!";
  }

  return AMDReturnsNothingError;

})(Error);

waitAll = function(array, reduce, map) {
  var counter, items, received, results;
  items = array.concat();
  results = [];
  received = [];
  counter = 0;
  items.forEach(function(item, index) {
    map(item, function(result) {
      var i, _i, _ref;
      counter++;
      results[index] = result;
      received[index] = true;
      for (i = _i = 0, _ref = items.length - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
        if (!received[i]) {
          return;
        }
      }
      return reduce(results);
    });
  });
};

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

decodeUtf8 = function(arrayBuffer) {
  var c, c1, c2, c3, data, i, result;
  result = "";
  i = 0;
  c = 0;
  c1 = 0;
  c2 = 0;
  data = new Uint8Array(arrayBuffer);
  if (hasBOM(data)) {
    i = 3;
  }
  while (i < data.length) {
    c = data[i];
    if (c < 128) {
      result += String.fromCharCode(c);
      i++;
    } else if ((191 < c && c < 224)) {
      if (i + 1 >= data.length) {
        throw "UTF-8 Decode failed. Two byte character was truncated.";
      }
      c2 = data[i + 1];
      result += String.fromCharCode(((c & 31) << 6) | (c2 & 63));
      i += 2;
    } else {
      if (i + 2 >= data.length) {
        throw "UTF-8 Decode failed. Multi byte character was truncated.";
      }
      c2 = data[i + 1];
      c3 = data[i + 2];
      result += String.fromCharCode(((c & 15) << 12) | ((c2 & 63) << 6) | (c3 & 63));
      i += 3;
    }
  }
  return result;
};

XHR = function() {
  return new XMLHttpRequest();
};

BasicEvaluator = (function() {
  function BasicEvaluator(options) {
    this.id = options.id;
    this.source = options.source;
    this.deps = options.dependencies;
    this["this"] = {};
    this.window = this.get_window();
    this.errors = [];
  }

  BasicEvaluator.prototype.render = function() {
    throw new AbstractMethodError();
  };

  BasicEvaluator.prototype.run = function() {
    var code, func, result;
    code = this.render();
    func = new Function(code);
    result = func.call(this);
    this._check(result);
    if (this.errors.length > 0) {
      return null;
    }
    return this._make();
  };

  BasicEvaluator.prototype.get_window = function() {
    return {
      __proto__: window
    };
  };

  BasicEvaluator.prototype.get_require = function() {
    throw new AbstractMethodError();
  };

  BasicEvaluator.prototype._fail = function(reason) {
    this.errors.push(reason);
    throw reason;
  };

  BasicEvaluator.prototype._check = function(result) {
    throw new AbstractMethodError();
  };

  BasicEvaluator.prototype._make = function() {
    throw new AbstractMethodError();
  };

  return BasicEvaluator;

})();

CJSEvaluator = (function(_super) {
  __extends(CJSEvaluator, _super);

  function CJSEvaluator(options) {
    CJSEvaluator.__super__.constructor.call(this, options);
    this.module = {};
    this.exports = {};
    this.module.exports = this.exports;
    this.require = this.get_require();
  }

  CJSEvaluator.prototype.render = function() {
    return "return (function(module, exports, require, window) { \n    " + this.source + "; \n}).call(this.this, this.module, this.exports, this.require, this.window);";
  };

  CJSEvaluator.prototype.get_require = function() {
    var require;
    require = function(name) {
      var value;
      value = this.deps[name];
      if (value == null) {
        this._fail(new UndeclaredRequireError(this.id, name));
      }
      return value;
    };
    return require.bind(this);
  };

  CJSEvaluator.prototype._check = function(result) {
    var this_keys, window_keys;
    window_keys = Object.keys(this.window);
    if (window_keys.length !== 0) {
      throw new ChangesInWindowError(this.id, window_keys);
    }
    if (!(this.exports === this.module.exports || Object.keys(this.exports).length === 0)) {
      throw new ExportsViolationError(this.id);
    }
    if (result != null) {
      throw new ReturnPollutionError(this.id, Object.keys(result));
    }
    this_keys = Object.keys(this["this"]);
    if (this_keys.length !== 0) {
      throw new ThisPollutionError(this.id, this_keys);
    }
  };

  CJSEvaluator.prototype._make = function() {
    return this.module.exports;
  };

  return CJSEvaluator;

})(BasicEvaluator);

AMDEvaluator = (function(_super) {
  __extends(AMDEvaluator, _super);

  function AMDEvaluator(options) {
    AMDEvaluator.__super__.constructor.call(this, options);
    this.define = this.get_define();
  }

  AMDEvaluator.prototype.render = function() {
    return "return (function(define, window) { \n    " + this.source + "; \n}).call(this.this, this.define, this.window);";
  };

  AMDEvaluator.prototype.get_define = function() {
    var define;
    define = function(names, func) {
      var deps, name;
      deps = (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = names.length; _i < _len; _i++) {
          name = names[_i];
          _results.push(this.deps[name]);
        }
        return _results;
      }).call(this);
      return this.result = func.apply(this["this"], deps);
    };
    return define.bind(this);
  };

  AMDEvaluator.prototype._check = function(result) {
    var this_keys, window_keys;
    window_keys = Object.keys(this.window);
    if (window_keys.length !== 0) {
      throw new ChangesInWindowError(this.id, window_keys);
    }
    if (result != null) {
      throw new ReturnPollutionError(this.id, Object.keys(result));
    }
    this_keys = Object.keys(this["this"]);
    if (this_keys.length !== 0) {
      throw new ThisPollutionError(this.id, this_keys);
    }
    if (this.result == null) {
      throw new AMDReturnsNothingError(this.id);
    }
  };

  AMDEvaluator.prototype._make = function() {
    return this.result;
  };

  return AMDEvaluator;

})(BasicEvaluator);

PollutionEvaluator = (function(_super) {
  __extends(PollutionEvaluator, _super);

  function PollutionEvaluator() {
    return PollutionEvaluator.__super__.constructor.apply(this, arguments);
  }

  PollutionEvaluator.prototype.render = function() {
    var args, name, names;
    names = ["window"].concat((function() {
      var _results;
      _results = [];
      for (name in this.deps) {
        _results.push(name);
      }
      return _results;
    }).call(this)).join(", ");
    args = ["this.this", "this.window"].concat((function() {
      var _results;
      _results = [];
      for (name in this.deps) {
        _results.push("this.deps[\"" + name + "\"]");
      }
      return _results;
    }).call(this)).join(", ");
    return "return (function(" + names + ") {\n    " + this.source + ";\n}).call(" + args + ");";
  };

  PollutionEvaluator.prototype._check = function(result) {
    if (result != null) {
      throw new ReturnPollutionError(this.id, Object.keys(result));
    }
  };

  PollutionEvaluator.prototype.get_window = function() {
    var name, result, value, _ref;
    result = {
      __proto__: PollutionEvaluator.__super__.get_window.call(this)
    };
    _ref = this.deps;
    for (name in _ref) {
      value = _ref[name];
      result[name] = value;
    }
    return {
      __proto__: result
    };
  };

  PollutionEvaluator.prototype._make = function() {
    var name, result, value, _ref, _ref1;
    result = {};
    _ref = this.window;
    for (name in _ref) {
      if (!__hasProp.call(_ref, name)) continue;
      value = _ref[name];
      result[name] = value;
    }
    _ref1 = this["this"];
    for (name in _ref1) {
      if (!__hasProp.call(_ref1, name)) continue;
      value = _ref1[name];
      result[name] = value;
    }
    return result;
  };

  return PollutionEvaluator;

})(BasicEvaluator);

RawEvaluator = (function(_super) {
  __extends(RawEvaluator, _super);

  function RawEvaluator() {
    return RawEvaluator.__super__.constructor.apply(this, arguments);
  }

  RawEvaluator.prototype.render = function() {
    return this.source;
  };

  RawEvaluator.prototype._check = function(result) {};

  RawEvaluator.prototype.get_window = function() {
    return window;
  };

  RawEvaluator.prototype._make = function() {
    return {};
  };

  return RawEvaluator;

})(BasicEvaluator);

SAFE_CHARS = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

Loader = (function() {
  function Loader(options) {
    var _ref;
    this._all_modules = {};
    this._current_manifest = null;
    this._update_started = false;
    this._modules_to_load = [];
    this._new_manifest = null;
    this._total_size = 0;
    this._evaluators = {
      cjs: CJSEvaluator,
      amd: AMDEvaluator,
      junk: PollutionEvaluator,
      raw: RawEvaluator
    };
    this.version = options.version;
    this.prefix = options.prefix;
    this.hash_name = options.hash_name;
    this.hash_func = options.hash_func;
    this.randomize_urls = options.randomize_urls;
    this.manifest_location = (_ref = options.manifest_location) != null ? _ref : "manifest.json";
    this.manifest_key = this.prefix + "::manifest";
    localforage.config();
  }

  Loader.prototype._prepare_url = function(url) {
    var i, result, _i;
    if (!this.randomize_urls) {
      return escape(url);
    }
    result = '';
    for (i = _i = 0; _i <= 16; i = ++_i) {
      result += SAFE_CHARS[Math.round(Math.random() * (SAFE_CHARS.length - 1))];
    }
    return escape(url) + '?' + result;
  };

  Loader.prototype._parse_manifest = function(content) {
    var manifest, raw;
    if (content == null) {
      throw ReferenceError("Manifest was not defined");
    }
    raw = JSON.parse(content);
    if (!(raw instanceof Object)) {
      throw TypeError("Invalid manifest format");
    }
    if (raw.modules == null) {
      throw TypeError("Invalid manifest format");
    }
    if (raw.version !== this.version) {
      throw TypeError("Invalid manifest version. Got: " + raw.version + ". Expected: " + this.version);
    }
    if (raw.hash_func !== this.hash_name) {
      throw TypeError("Invalid manifest hash function. Got: " + raw.hash_func + ". Expected: " + this.hash_name);
    }
    manifest = {
      content: content,
      modules: raw.modules,
      version: raw.version,
      hash_func: raw.hash_func,
      hash: this.hash_func(content)
    };
    return manifest;
  };

  Loader.prototype.get_manifest = function() {
    return this._parse_manifest(window.localStorage.getItem(this.manifest_key));
  };

  Loader.prototype.set_manifest = function(manifest) {
    window.localStorage.setItem(this.manifest_key, manifest.content);
  };

  Loader.prototype.make_key = function(module) {
    return this.prefix + ":" + module.hash + ":" + module.url;
  };

  Loader.prototype.get_content = function(key, cb) {
    return localforage.getItem(key, cb);
  };

  Loader.prototype.set_content = function(key, content, cb) {
    this.log("storing", key);
    return localforage.setItem(key, content, cb);
  };

  Loader.prototype.get_contents_keys = function(cb) {
    localforage.length((function(_this) {
      return function(length) {
        var buf, c, i, receive, _i, _ref, _results;
        c = 0;
        buf = [];
        receive = function(num, key) {
          var _i, _len;
          c++;
          buf[num] = key;
          if (c < length) {
            return;
          }
          for (_i = 0, _len = buf.length; _i < _len; _i++) {
            key = buf[_i];
            cb(key);
          }
        };
        _results = [];
        for (i = _i = 0, _ref = length - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
          _results.push(localforage.key(i, receive.bind(_this, i)));
        }
        return _results;
      };
    })(this));
  };

  Loader.prototype.del_content = function(key, cb) {
    this.log("removing", key);
    return localforage.removeItem(key, cb);
  };

  Loader.prototype.log = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return console.log.apply(console, ["LOADER:" + this.prefix].concat(__slice.call(args)));
  };

  Loader.prototype.onNoManifest = function() {
    return this.log("onNoManifest");
  };

  Loader.prototype.onUpToDate = function(event) {
    return this.log("onUpToDate", event);
  };

  Loader.prototype.onUpdateFound = function(event, manifest) {
    this.log("onUpdateFound", event, manifest);
    return this.startUpdate();
  };

  Loader.prototype.onUpdateFailed = function(event, error) {
    return this.log("onUpdateFailed", event, error);
  };

  Loader.prototype.onUpdateCompleted = function(manifest) {
    this.log("onUpdateCompleted", manifest);
    return true;
  };

  Loader.prototype.onModuleBeginDownload = function(module) {
    return this.log("onModuleBeginDownload", module);
  };

  Loader.prototype.onModuleDownloadFailed = function(event, module) {
    return this.log("onModuleDownloadFailed", event, module);
  };

  Loader.prototype.onModuleDownloadProgress = function(event, module) {
    return this.log("onModuleDownloadProgress", event, module);
  };

  Loader.prototype.onTotalDownloadProgress = function(progress) {
    return this.log("onTotalDownloadProgress", progress);
  };

  Loader.prototype.onModuleDownloaded = function(module) {
    return this.log("onModuleDownloaded", module);
  };

  Loader.prototype.onEvaluationStarted = function(manifest) {
    return this.log("onEvaluationStarted", manifest);
  };

  Loader.prototype.onEvaluationError = function(module, error) {
    return this.log("onEvaluationError", module, error);
  };

  Loader.prototype.onModuleEvaluated = function(module) {
    return this.log("onModuleEvaluated", module);
  };

  Loader.prototype.onApplicationReady = function(manifest) {
    this.log("onApplicationReady", manifest);
    return this.checkUpdate();
  };

  Loader.prototype.load = function() {
    var error;
    try {
      this._current_manifest = this.get_manifest();
    } catch (_error) {
      error = _error;
      this.onNoManifest();
      return;
    }
    this.onEvaluationStarted(this._current_manifest);
    this.log("Current manifest", this._current_manifest.content);
    this.evaluate(this._current_manifest.modules);
    this._cleanUp();
  };

  Loader.prototype.evaluate = function(queue) {
    var key, module;
    queue = queue.concat();
    if (queue.length === 0) {
      this.onApplicationReady(this._current_manifest);
      return;
    }
    module = queue.shift();
    key = this.make_key(module);
    return this.get_content(key, (function(_this) {
      return function(module_source) {
        var alias, dep, deps, error, evaluator, namespace, _ref, _ref1;
        if (module_source == null) {
          _this.onEvaluationError(module, new NoSourceError(module.url));
          return;
        }
        try {
          if (module_source instanceof ArrayBuffer) {
            module.source = decodeUtf8(module_source);
          } else {
            module.source = module_source;
          }
        } catch (_error) {
          error = _error;
          _this.onEvaluationError(module, error);
          return;
        }
        deps = {};
        _ref = module.deps;
        for (alias in _ref) {
          dep = _ref[alias];
          deps[alias] = _this._all_modules[dep];
        }
        deps["loader"] = _this;
        evaluator = new _this._evaluators[(_ref1 = module.type) != null ? _ref1 : "cjs"]({
          id: module.id,
          source: module.source,
          dependencies: deps
        });
        try {
          namespace = evaluator.run();
        } catch (_error) {
          error = _error;
          _this.onEvaluationError(module, error);
          return;
        }
        _this._all_modules[module.id] = namespace;
        module.namespace = namespace;
        _this.onModuleEvaluated(module);
        return _this.evaluate(queue);
      };
    })(this));
  };

  Loader.prototype.checkUpdate = function() {
    var manifest_request;
    if (this._update_started) {
      return;
    }
    this.log("Checking for update...");
    manifest_request = XHR();
    manifest_request.open("GET", this._prepare_url(this.manifest_location), true);
    manifest_request.overrideMimeType("application/json; charset=utf-8");
    manifest_request.onload = (function(_this) {
      return function(event) {
        var error;
        if (event.target.status === 404) {
          _this.onUpdateFailed(event, null);
          return;
        }
        try {
          _this._new_manifest = _this._parse_manifest(event.target.response);
        } catch (_error) {
          error = _error;
          _this.onUpdateFailed(event, error);
          return;
        }
        _this.log("New manifest", _this._new_manifest.content);
        if (_this._current_manifest != null) {
          if (_this._current_manifest.hash === _this._new_manifest.hash) {
            _this.onUpToDate(_this._current_manifest);
            return;
          }
        }
        return _this.onUpdateFound(event, _this._new_manifest);
      };
    })(this);
    manifest_request.onerror = (function(_this) {
      return function(event) {
        return _this.onUpdateFailed(event, null);
      };
    })(this);
    manifest_request.onabort = (function(_this) {
      return function(event) {
        return _this.onUpdateFailed(event, null);
      };
    })(this);
    manifest_request.send();
  };

  Loader.prototype.startUpdate = function() {
    var module, _i, _j, _len, _len1, _ref, _ref1;
    this.log("Starting update...");
    this._update_started = true;
    _ref = this._new_manifest.modules;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      module = _ref[_i];
      module.loaded = 0;
    }
    this._modules_to_load = this._new_manifest.modules.concat();
    _ref1 = this._modules_to_load.splice(0, 4);
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      module = _ref1[_j];
      this._updateModule(module);
    }
  };

  Loader.prototype._updateModule = function(module) {
    var key;
    key = this.make_key(module);
    this.get_content(key, (function(_this) {
      return function(module_source) {
        if (module_source != null) {
          module.source = module_source;
          _this._reportTotalProgress();
          _this._checkAllUpdated();
        } else {
          _this._downloadModule(module);
        }
      };
    })(this));
  };

  Loader.prototype._reportTotalProgress = function() {
    var loaded_count, loaded_size, module, total_count, total_size, _i, _len, _ref;
    loaded_size = 0;
    total_size = 0;
    loaded_count = 0;
    total_count = 0;
    _ref = this._new_manifest.modules;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      module = _ref[_i];
      total_size += module.size;
      loaded_size += module.loaded;
      total_count++;
      if (module.source != null) {
        loaded_count++;
      }
    }
    return this.onTotalDownloadProgress({
      loaded_count: loaded_count,
      total_count: total_count,
      loaded_size: loaded_size,
      total_size: total_size
    });
  };

  Loader.prototype._downloadModule = function(module) {
    var module_request;
    this.onModuleBeginDownload(module);
    module_request = XHR();
    module_request.open("GET", this._prepare_url(module.url), true);
    module_request.responseType = "arraybuffer";
    module_request.onload = (function(_this) {
      return function(event) {
        var module_source;
        module_source = event.target.response;
        if (_this.hash_func(module_source) !== module.hash) {
          _this.onModuleDownloadFailed(event, module);
          return;
        }
        return _this.set_content(_this.make_key(module), module_source, function() {
          module.source = module_source;
          module.loaded = module.size;
          _this.onModuleDownloaded(module);
          _this._reportTotalProgress();
          return _this._checkAllUpdated();
        });
      };
    })(this);
    module_request.onprogress = (function(_this) {
      return function(event) {
        module.loaded = event.loaded;
        _this.onModuleDownloadProgress(event, module);
        return _this._reportTotalProgress();
      };
    })(this);
    module_request.onerror = (function(_this) {
      return function(event) {
        return _this.onModuleDownloadFailed(event, module);
      };
    })(this);
    module_request.onabort = (function(_this) {
      return function(event) {
        return _this.onModuleDownloadFailed(event, module);
      };
    })(this);
    module_request.send();
  };

  Loader.prototype._checkAllUpdated = function() {
    var module, next, _i, _len, _ref;
    next = this._modules_to_load.shift();
    if (next != null) {
      this._updateModule(next);
      return;
    }
    _ref = this._new_manifest.modules;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      module = _ref[_i];
      if (module.source == null) {
        return;
      }
    }
    if (this.onUpdateCompleted(this._new_manifest)) {
      this.set_manifest(this._new_manifest);
      this._current_manifest = this._new_manifest;
      this._new_manifest = null;
    }
    this._update_started = false;
  };

  Loader.prototype._cleanUp = function() {
    var module, useful;
    useful = (function() {
      var _i, _len, _ref, _results;
      _ref = this._current_manifest.modules;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        module = _ref[_i];
        _results.push(this.make_key(module));
      }
      return _results;
    }).call(this);
    useful.push(this.manifest_key);
    this.get_contents_keys((function(_this) {
      return function(key) {
        if (key == null) {
          return;
        }
        if (key.indexOf(_this.prefix) !== 0) {
          return;
        }
        if (__indexOf.call(useful, key) >= 0) {
          return;
        }
        _this.del_content(key);
      };
    })(this));
  };

  return Loader;

})();
