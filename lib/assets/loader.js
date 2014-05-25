var AMDEvaluator, AMDReturnsNothingError, AbstractMethodError, BasicEvaluator, CJSEvaluator, ChangesInWindowError, ExportsViolationError, Loader, NoSourceError, PollutionEvaluator, RawEvaluator, ReturnPollutionError, Storage, ThisPollutionError, UndeclaredRequireError, XHR,
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
    this.message = "";
  }

  return ExportsViolationError;

})(Error);

ReturnPollutionError = (function(_super) {
  __extends(ReturnPollutionError, _super);

  function ReturnPollutionError(self_name, props) {
    this.self_name = self_name;
    this.props = props;
    this.name = "ReturnPollutionError";
    this.message = "";
  }

  return ReturnPollutionError;

})(Error);

ThisPollutionError = (function(_super) {
  __extends(ThisPollutionError, _super);

  function ThisPollutionError(self_name, props) {
    this.self_name = self_name;
    this.props = props;
    this.name = "ThisPollutionError";
    this.message = "";
  }

  return ThisPollutionError;

})(Error);

AMDReturnsNothingError = (function(_super) {
  __extends(AMDReturnsNothingError, _super);

  function AMDReturnsNothingError(self_name) {
    this.self_name = self_name;
    this.name = "AMDReturnsNothingError";
    this.message = "";
  }

  return AMDReturnsNothingError;

})(Error);

XHR = function() {
  try {
    return new XMLHttpRequest();
  } catch (_error) {

  }
  try {
    return new ActiveXObject("Msxml3.XMLHTTP");
  } catch (_error) {

  }
  try {
    return new ActiveXObject("Msxml2.XMLHTTP.6.0");
  } catch (_error) {

  }
  try {
    return new ActiveXObject("Msxml2.XMLHTTP.3.0");
  } catch (_error) {

  }
  try {
    return new ActiveXObject("Msxml2.XMLHTTP");
  } catch (_error) {

  }
  try {
    return new ActiveXObject("Microsoft.XMLHTTP");
  } catch (_error) {

  }
  return null;
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
    var func, result;
    func = new Function(this.render());
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

Storage = (function() {
  function Storage() {}

  Storage.prototype.get = function(name) {
    throw new AbstractMethodError();
  };

  Storage.prototype.set = function(name, value) {
    throw new AbstractMethodError();
  };

  return Storage;

})();

Loader = (function() {
  function Loader(options) {
    this._all_modules = {};
    this._modules_running = [];
    this._current_manifest = null;
    this._update_started = false;
    this._modules_in_update = [];
    this._new_manifest = null;
    this._total_size = 0;
    this._loaded_sizes = {};
    this._evaluators = {
      cjs: CJSEvaluator,
      amd: AMDEvaluator,
      junk: PollutionEvaluator,
      raw: RawEvaluator
    };
    this.manifest_key = (typeof LOADER_PREFIX !== "undefined" && LOADER_PREFIX !== null ? LOADER_PREFIX : "spa") + "::manifest";
    localforage.config();
  }

  Loader.prototype.get_manifest = function() {
    return window.localStorage.getItem(this.manifest_key);
  };

  Loader.prototype.set_manifest = function(value) {
    window.localStorage.setItem(this.manifest_key, value);
  };

  Loader.prototype.make_key = function(module) {
    return (typeof LOADER_PREFIX !== "undefined" && LOADER_PREFIX !== null ? LOADER_PREFIX : "spa") + ":" + module.hash + ":" + module.url;
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
    return console.log.apply(console, args);
  };

  Loader.prototype.onUpdateFound = function(event) {
    this.log("onUpdateFound", arguments);
    return this.startUpdate();
  };

  Loader.prototype.onUpToDate = function() {
    return this.log("onUpToDate", arguments);
  };

  Loader.prototype.onUpdateFailed = function(event) {
    return this.log("onUpdateFailed", arguments);
  };

  Loader.prototype.onUpdateCompletted = function(event) {
    this.log("onUpdateCompletted", arguments);
    return true;
  };

  Loader.prototype.onModuleBeginDownload = function(module) {
    return this.log("onModuleBeginDownload", arguments);
  };

  Loader.prototype.onModuleDownloaded = function() {
    return this.log("onModuleDownloaded", arguments);
  };

  Loader.prototype.onModuleDownloadFailed = function() {
    return this.log("onModuleDownloadFailed", arguments);
  };

  Loader.prototype.onModuleDownloadProgress = function() {
    return this.log("onModuleDownloadProgress", arguments);
  };

  Loader.prototype.onTotalDownloadProgress = function() {
    return this.log("onTotalDownloadProgress", arguments);
  };

  Loader.prototype.onEvaluationError = function(error) {
    return this.log("onEvaluationError", arguments);
  };

  Loader.prototype.onApplicationReady = function() {
    this.log("onApplicationReady", arguments);
    return this.checkUpdate();
  };

  Loader.prototype.write_fake = function(cb) {
    var manifest, module;
    manifest = JSON.parse(FAKE_MANIFEST);
    this.set_manifest(FAKE_MANIFEST);
    module = manifest[0];
    return this.set_content(this.make_key(module), FAKE_APP, cb);
  };

  Loader.prototype.calc_hash = function(data) {
    return CryptoJS[HASH_FUNC](data).toString();
  };

  Loader.prototype.evaluate = function(queue) {
    var key, module;
    if (queue.length === 0) {
      this.onApplicationReady();
      return;
    }
    module = queue.shift();
    key = this.make_key(module);
    return this.get_content(key, (function(_this) {
      return function(module_source) {
        var alias, dep, deps, error, evaluator, _ref, _ref1;
        if (module_source == null) {
          _this.onEvaluationError(new NoSourceError(module.url));
          return;
        }
        module.source = module_source;
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
          _this._all_modules[module.id] = evaluator.run();
        } catch (_error) {
          error = _error;
          _this.onEvaluationError(error);
          return;
        }
        return _this.evaluate(queue);
      };
    })(this));
  };

  Loader.prototype.start = function() {
    this._current_manifest = this.get_manifest();
    this.log("Current manifest", this._current_manifest);
    if (this._current_manifest == null) {
      this.log("Writing fake application");
      this.write_fake((function(_this) {
        return function() {
          return _this.start();
        };
      })(this));
      return;
    }
    this._cleanUp();
    this._modules_running = JSON.parse(this._current_manifest);
    this.evaluate(this._modules_running);
  };

  Loader.prototype.checkUpdate = function() {
    var manifest_request;
    if (this._update_started) {
      return;
    }
    this.log("Checking for update...");
    manifest_request = XHR();
    manifest_request.open("GET", typeof MANIFEST_LOCATION !== "undefined" && MANIFEST_LOCATION !== null ? MANIFEST_LOCATION : "manifest.json", true);
    manifest_request.overrideMimeType("application/json; charset=utf-8");
    manifest_request.onload = (function(_this) {
      return function(event) {
        if (event.target.status === 404) {
          _this.onUpdateFailed(event);
          return;
        }
        _this._new_manifest = event.target.response;
        if (_this._current_manifest != null) {
          if (_this.calc_hash(_this._current_manifest) === _this.calc_hash(_this._new_manifest)) {
            _this.onUpToDate();
            return;
          }
        }
        return _this.onUpdateFound(event);
      };
    })(this);
    manifest_request.onerror = (function(_this) {
      return function(event) {
        return _this.onUpdateFailed(event);
      };
    })(this);
    manifest_request.send();
  };

  Loader.prototype.startUpdate = function() {
    var module, _i, _j, _len, _len1, _ref, _ref1;
    this.log("Starting update...");
    this._update_started = true;
    this._modules_in_update = JSON.parse(this._new_manifest);
    this._total_size = 0;
    _ref = this._modules_in_update;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      module = _ref[_i];
      this._total_size += module.size;
      this._loaded_sizes[module.id] = 0;
    }
    _ref1 = this._modules_in_update;
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      module = _ref1[_j];
      this._updateModule(module);
    }
  };

  Loader.prototype._updateModule = function(module) {
    this.get_content(this.make_key(module), (function(_this) {
      return function() {
        if (typeof module_source !== "undefined" && module_source !== null) {
          module.source = module_source;
          _this.onTotalDownloadProgress({
            loaded: _this._getLoadedSize(),
            total: _this._total_size
          });
          _this._checkAllUpdated();
        } else {
          _this._downloadModule(module);
        }
      };
    })(this));
  };

  Loader.prototype._getLoadedSize = function() {
    var loaded_size, name, size, _ref;
    loaded_size = 0;
    _ref = this._loaded_sizes;
    for (name in _ref) {
      size = _ref[name];
      loaded_size += size;
    }
    return loaded_size;
  };

  Loader.prototype._downloadModule = function(module) {
    var module_request;
    this.onModuleBeginDownload(module);
    module_request = XHR();
    module_request.open("GET", module.url, true);
    module_request.onload = (function(_this) {
      return function(event) {
        var module_source;
        module_source = event.target.response;
        if (_this.calc_hash(module_source) !== module.hash) {
          _this.onModuleDownloadFailed(module, event);
          return;
        }
        return _this.set_content(_this.make_key(module), module_source, function() {
          module.source = module_source;
          _this._loaded_sizes[module.id] = module.size;
          _this.onModuleDownloaded(event);
          _this.onTotalDownloadProgress({
            loaded: _this._getLoadedSize(),
            total: _this._total_size
          });
          return _this._checkAllUpdated();
        });
      };
    })(this);
    module_request.onprogress = (function(_this) {
      return function(event) {
        _this._loaded_sizes[module.id] = event.loaded;
        _this.onModuleDownloadProgress({
          loaded: event.loaded,
          total: module.size
        });
        return _this.onTotalDownloadProgress({
          loaded: _this._getLoadedSize(),
          total: _this._total_size
        });
      };
    })(this);
    module_request.onerror = (function(_this) {
      return function(event) {
        return _this.onModuleDownloadFailed(module, event);
      };
    })(this);
    module_request.onabort = (function(_this) {
      return function(event) {
        return _this.onModuleDownloadFailed(module, event);
      };
    })(this);
    module_request.send();
  };

  Loader.prototype._checkAllUpdated = function() {
    var module, _i, _len, _ref;
    _ref = this._modules_in_update;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      module = _ref[_i];
      if (module.source == null) {
        return;
      }
    }
    if (this.onUpdateCompletted()) {
      this.set_manifest(this._new_manifest);
      this._current_manifest = this._new_manifest;
      this._new_manifest = null;
      this._cleanUp();
    }
    this._update_started = false;
    this._modules_in_update = [];
  };

  Loader.prototype._cleanUp = function() {
    var module, modules, prefix, useful;
    prefix = typeof LOADER_PREFIX !== "undefined" && LOADER_PREFIX !== null ? LOADER_PREFIX : "spa";
    modules = JSON.parse(this._current_manifest);
    useful = (function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = modules.length; _i < _len; _i++) {
        module = modules[_i];
        _results.push(this.make_key(module));
      }
      return _results;
    }).call(this);
    useful.push(this.manifest_key);
    this.get_contents_keys((function(_this) {
      return function(key) {
        if (key.indexOf(prefix) !== 0) {
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

window.onload = function() {
  var loader;
  loader = new Loader();
  loader.start();
  return true;
};
