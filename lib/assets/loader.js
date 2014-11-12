var AMDEvaluator, AMDReturnsNothingError, AbstractMethodError, BasicEvaluator, CJSEvaluator, ChangesInWindowError, DBError, DepsAMDEvaluator, ExportsViolationError, FactoryAMDEvaluator, HashFuncMismatchedError, HashMismatchedError, Loader, Logger, NamedAMDEvaluator, NoSourceError, NodepsAMDEvaluator, PollutionEvaluator, REMAMDEvaluator, RawEvaluator, ReturnPollutionError, SAFE_CHARS, ThisPollutionError, UndeclaredRequireError, VersionMismatchedError, XHR, waitAll,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
  __slice = [].slice;

AbstractMethodError = (function(_super) {
  __extends(AbstractMethodError, _super);

  function AbstractMethodError(name) {
    this.name = "AbstractMethodError";
    this.message = "Calling abstract method `" + name + "` detected.";
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

DBError = (function(_super) {
  __extends(DBError, _super);

  function DBError(url, error) {
    this.url = url;
    this.error = error;
    this.name = "DBError";
    this.message = "Error " + this.error + " occured during loading of module " + this.url + ".";
  }

  return DBError;

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

VersionMismatchedError = (function(_super) {
  __extends(VersionMismatchedError, _super);

  function VersionMismatchedError(got, expected) {
    this.got = got;
    this.expected = expected;
    this.name = "VersionMismatchedError";
    this.message = "Invalid manifest version. Got: " + this.got + ". Expected: " + this.expected;
  }

  return VersionMismatchedError;

})(Error);

HashFuncMismatchedError = (function(_super) {
  __extends(HashFuncMismatchedError, _super);

  function HashFuncMismatchedError(got, expected) {
    this.got = got;
    this.expected = expected;
    this.name = "HashFuncMismatchedError";
    this.message = "Invalid manifest hash function. Got: " + this.got + ". Expected: " + this.expected;
  }

  return HashFuncMismatchedError;

})(Error);

HashMismatchedError = (function(_super) {
  __extends(HashMismatchedError, _super);

  function HashMismatchedError(url, got, expected) {
    this.url = url;
    this.got = got;
    this.expected = expected;
    this.name = "HashMismatchedError";
    this.message = "Downloaded from url `" + this.url + "` file has unexpected checksum hash. Got: " + this.got + ". Expected: " + this.expected;
  }

  return HashMismatchedError;

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

XHR = function() {
  return new XMLHttpRequest();
};

BasicEvaluator = (function() {
  function BasicEvaluator(options) {
    this.id = options.id;
    this.url = options.url;
    this.source = options.source;
    this.deps = options.dependencies;
    this["this"] = {};
    this.window_props = [];
    this.window = this.get_window();
    this.errors = [];
  }

  BasicEvaluator.prototype.render = function() {
    throw new AbstractMethodError("render");
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
    var WrapperType, define_property, prop, wrapper;
    WrapperType = function() {};
    WrapperType.prototype = window;
    wrapper = new WrapperType();
    this.window_props = [];
    for (prop in window) {
      this.window_props.push(prop);
      define_property = function(prop) {
        var cell;
        cell = {
          value: window[prop]
        };
        if (typeof window[prop] === 'function') {
          Object.defineProperty(wrapper, prop, {
            get: function() {
              return function() {
                return cell.value.apply(window, arguments);
              };
            },
            set: function(value) {
              return cell.value = value;
            }
          });
        } else {
          Object.defineProperty(wrapper, prop, {
            get: function() {
              if (window[prop] === window) {
                return wrapper;
              }
              return cell.value;
            },
            set: function(value) {
              if (typeof value === 'function') {
                return cell.value = function() {
                  return value.apply(wrapper, arguments);
                };
              } else {
                return cell.value = value;
              }
            }
          });
        }
      };
      define_property(prop);
    }
    wrapper.addEventListener = function(type, listener, useCapture) {
      var wrap_listener;
      if ('message' === type) {
        wrap_listener = function(originalListener) {
          return function(event) {
            var newEvent;
            newEvent = document.createEvent('MessageEvent');
            newEvent.initMessageEvent('message', event.bubbles, event.cancelable, event.data, event.origin, event.lastEventId, wrapper, event.ports);
            return originalListener(newEvent);
          };
        };
        listener = wrap_listener(listener);
      }
      return window.addEventListener.call(window, type, listener, useCapture);
    };
    return wrapper;
  };

  BasicEvaluator.prototype.get_require = function() {
    throw new AbstractMethodError("get_require");
  };

  BasicEvaluator.prototype._fail = function(reason) {
    this.errors.push(reason);
    throw reason;
  };

  BasicEvaluator.prototype._check = function(result) {
    throw new AbstractMethodError("_check");
  };

  BasicEvaluator.prototype._check_window = function(wrapper) {
    var added_props, prop;
    added_props = (function() {
      var _results;
      _results = [];
      for (prop in wrapper) {
        if (__indexOf.call(this.window_props, prop) < 0) {
          _results.push(prop);
        }
      }
      return _results;
    }).call(this);
    if (added_props.length !== 0) {
      throw new ChangesInWindowError(this.id, added_props);
    }
  };

  BasicEvaluator.prototype._make = function() {
    throw new AbstractMethodError("_make");
  };

  BasicEvaluator.prototype.get_require = function() {
    var require;
    require = function(name) {
      if (!(name in this.deps)) {
        this._fail(new UndeclaredRequireError(this.id, name));
      }
      return this.deps[name];
    };
    return require.bind(this);
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
    this.process = {
      env: {}
    };
    this.deps["exports"] = this.exports;
    this.deps["module"] = this.module;
    this.deps["require"] = this.require;
  }

  CJSEvaluator.prototype.render = function() {
    return "return (function(module, exports, require, window, process) { \n    " + this.source + "; \n}).call(this.this, this.module, this.exports, this.require, this.window, this.process);\n\n//# sourceURL=" + this.url + "\n";
  };

  CJSEvaluator.prototype._check = function(result) {
    var this_keys;
    this._check_window(this.window);
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
    return "return (function(define, window) { \n    " + this.source + "; \n}).call(this.this, this.define, this.window);\n\n//# sourceURL=" + this.url + "\n";
  };

  AMDEvaluator.prototype._check = function(result) {
    var this_keys;
    this._check_window(this.window);
    if (result != null) {
      throw new ReturnPollutionError(this.id, Object.keys(result));
    }
    this_keys = Object.keys(this["this"]);
    if (this_keys.length !== 0) {
      throw new ThisPollutionError(this.id, this_keys);
    }
  };

  return AMDEvaluator;

})(BasicEvaluator);

NodepsAMDEvaluator = (function(_super) {
  __extends(NodepsAMDEvaluator, _super);

  function NodepsAMDEvaluator() {
    return NodepsAMDEvaluator.__super__.constructor.apply(this, arguments);
  }

  NodepsAMDEvaluator.prototype.get_define = function() {
    var define;
    define = function(exports) {
      return this.result = exports;
    };
    return define.bind(this);
  };

  NodepsAMDEvaluator.prototype._make = function() {
    return this.result;
  };

  return NodepsAMDEvaluator;

})(AMDEvaluator);

FactoryAMDEvaluator = (function(_super) {
  __extends(FactoryAMDEvaluator, _super);

  function FactoryAMDEvaluator(options) {
    FactoryAMDEvaluator.__super__.constructor.call(this, options);
    this.require = this.get_require();
  }

  FactoryAMDEvaluator.prototype.get_define = function() {
    var define;
    define = function(func) {
      return this.result = func.call(this["this"], this.require);
    };
    return define.bind(this);
  };

  FactoryAMDEvaluator.prototype._check = function(result) {
    FactoryAMDEvaluator.__super__._check.call(this, result);
    if (this.result == null) {
      throw new AMDReturnsNothingError(this.id);
    }
  };

  FactoryAMDEvaluator.prototype._make = function() {
    return this.result;
  };

  return FactoryAMDEvaluator;

})(AMDEvaluator);

REMAMDEvaluator = (function(_super) {
  __extends(REMAMDEvaluator, _super);

  function REMAMDEvaluator(options) {
    REMAMDEvaluator.__super__.constructor.call(this, options);
    this.module = {};
    this.exports = {};
    this.module.exports = this.exports;
    this.require = this.get_require();
  }

  REMAMDEvaluator.prototype.get_define = function() {
    var define;
    define = function(func) {
      return this.result = func.call(this["this"], this.require, this.exports, this.module);
    };
    return define.bind(this);
  };

  REMAMDEvaluator.prototype._check = function(result) {
    REMAMDEvaluator.__super__._check.call(this, result);
    if (!(this.exports === this.module.exports || Object.keys(this.exports).length === 0)) {
      throw new ExportsViolationError(this.id);
    }
    if (this.result != null) {
      throw new ReturnPollutionError(this.id, Object.keys(this.result));
    }
  };

  REMAMDEvaluator.prototype._make = function() {
    return this.module.exports;
  };

  return REMAMDEvaluator;

})(AMDEvaluator);

DepsAMDEvaluator = (function(_super) {
  __extends(DepsAMDEvaluator, _super);

  function DepsAMDEvaluator(options) {
    DepsAMDEvaluator.__super__.constructor.call(this, options);
    this.module = {};
    this.exports = {};
    this.module.exports = this.exports;
    this.require = this.get_require();
    this.deps["exports"] = this.exports;
    this.deps["module"] = this.module;
    this.deps["require"] = this.require;
  }

  DepsAMDEvaluator.prototype.get_define = function() {
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

  DepsAMDEvaluator.prototype._check = function(result) {
    DepsAMDEvaluator.__super__._check.call(this, result);
    if (this.result != null) {
      if (Object.keys(this.exports).length !== 0) {
        throw new ExportsViolationError(this.id);
      }
      if (!(this.module.exports === null || Object.keys(this.module.exports).length === 0)) {
        throw new ExportsViolationError(this.id);
      }
    } else {
      if (!(this.exports === this.module.exports || Object.keys(this.exports).length === 0)) {
        throw new ExportsViolationError(this.id);
      }
      if (this.exports === this.module.exports && Object.keys(this.exports).length === 0) {
        throw new AMDReturnsNothingError(this.id);
      }
    }
  };

  DepsAMDEvaluator.prototype._make = function() {
    if (this.result != null) {
      return this.result;
    }
    return this.module.exports;
  };

  return DepsAMDEvaluator;

})(AMDEvaluator);

NamedAMDEvaluator = (function(_super) {
  __extends(NamedAMDEvaluator, _super);

  function NamedAMDEvaluator() {
    return NamedAMDEvaluator.__super__.constructor.apply(this, arguments);
  }

  NamedAMDEvaluator.prototype.get_define = function() {
    var define;
    define = function(own_name, names, func) {
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

  return NamedAMDEvaluator;

})(DepsAMDEvaluator);

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
    return "return (function(" + names + ") {\n    " + this.source + ";\n}).call(" + args + ");\n\n//# sourceURL=" + this.url + "\n";
  };

  PollutionEvaluator.prototype._check = function(result) {
    if (result != null) {
      throw new ReturnPollutionError(this.id, Object.keys(result));
    }
  };

  PollutionEvaluator.prototype.get_window = function() {
    var name, result, value, _ref;
    result = PollutionEvaluator.__super__.get_window.call(this);
    _ref = this.deps;
    for (name in _ref) {
      value = _ref[name];
      result[name] = value;
    }
    return result;
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
    return "" + this.source + "\n\n//# sourceURL=" + this.url + "\n";
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

Logger = (function() {
  function Logger(prefix) {
    this.prefix = prefix;
  }

  Logger.prototype.info = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return console.info.apply(console, [this.prefix].concat(__slice.call(args)));
  };

  Logger.prototype.warn = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return console.warn.apply(console, [this.prefix].concat(__slice.call(args)));
  };

  Logger.prototype.error = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return console.error.apply(console, [this.prefix].concat(__slice.call(args)));
  };

  return Logger;

})();

Loader = (function() {
  function Loader(options) {
    var _ref, _ref1;
    this._all_modules = {};
    this._current_manifest = null;
    this._update_started = false;
    this._modules_to_load = [];
    this._new_manifest = null;
    this._total_size = 0;
    this._stats = {
      evaluate_module_start: [],
      evaluate_module_loaded_from_db: [],
      update_module_start: [],
      update_module_loaded_from_db: [],
      evaluate_module_decoded: []
    };
    this.version = options.version;
    this.prefix = options.prefix;
    this.hash_name = options.hash_name;
    this.hash_func = options.hash_func;
    this.decoder_func = options.decoder_func;
    this.randomize_urls = options.randomize_urls;
    this.manifest_location = (_ref = options.manifest_location) != null ? _ref : "manifest.json";
    this.options = options;
    this.logger = (_ref1 = options.logger) != null ? _ref1 : new Logger("LOADER:" + this.prefix);
    this.manifest_key = this.prefix + "::manifest";
    localforage.config({
      name: this.prefix + "-db"
    });
  }

  Loader.prototype._get_evaluator = function(module) {
    var _ref, _ref1;
    switch ((_ref = module.type) != null ? _ref : "cjs") {
      case "cjs":
        return CJSEvaluator;
      case "amd":
        switch ((_ref1 = module.amdtype) != null ? _ref1 : "deps") {
          case "nodeps":
            return NodepsAMDEvaluator;
          case "factory":
            return FactoryAMDEvaluator;
          case "rem":
            return REMAMDEvaluator;
          case "deps":
            return DepsAMDEvaluator;
          case "named":
            return NamedAMDEvaluator;
          default:
            throw new TypeError("Invalid amd-type module `" + module.amdtype + "`");
        }
        break;
      case "junk":
        return PollutionEvaluator;
      case "raw":
        return RawEvaluator;
      default:
        throw new TypeError("Invalid module type `" + module.type + "`");
    }
  };

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
      throw new VersionMismatchedError(raw.version, this.version);
    }
    if (raw.hash_func !== this.hash_name) {
      throw new HashFuncMismatchedError(raw.hash_func, this.hash_name);
    }
    manifest = {
      content: content,
      modules: raw.modules,
      version: raw.version,
      hash_func: raw.hash_func,
      hash: this.hash_func(content)
    };
    if (raw.bundle != null) {
      manifest.bundle = {
        hash: raw.bundle.hash,
        url: raw.bundle.url
      };
    }
    return manifest;
  };

  Loader.prototype.get_manifest = function() {
    return this._parse_manifest(window.localStorage.getItem(this.manifest_key));
  };

  Loader.prototype.set_manifest = function(manifest) {
    window.localStorage.setItem(this.manifest_key, manifest.content);
  };

  Loader.prototype.del_manifest = function() {
    window.localStorage.removeItem(this.manifest_key);
  };

  Loader.prototype.make_key = function(module) {
    return this.prefix + ":" + module.hash + ":" + module.url;
  };

  Loader.prototype.get_content = function(key, cb) {
    return localforage.getItem(key, cb);
  };

  Loader.prototype.set_content = function(key, content, cb) {
    this.logger.info("storing", key);
    return localforage.setItem(key, content, cb);
  };

  Loader.prototype.get_contents_keys = function(cb) {
    localforage.keys().then((function(_this) {
      return function(keys) {
        var key, _i, _len;
        for (_i = 0, _len = keys.length; _i < _len; _i++) {
          key = keys[_i];
          cb(key);
        }
      };
    })(this))["catch"]((function(_this) {
      return function(err) {
        return _this.logger.error(err);
      };
    })(this));
  };

  Loader.prototype.del_content = function(key, cb) {
    this.logger.warn("removing", key);
    return localforage.removeItem(key, cb);
  };

  Loader.prototype.onNoManifest = function(error) {};

  Loader.prototype.onUpToDate = function(event, manifest) {};

  Loader.prototype.onUpdateFound = function(event, manifest) {
    return this.startUpdate();
  };

  Loader.prototype.onUpdateFailed = function(event, error) {};

  Loader.prototype.onUpdateCompleted = function(manifest) {
    return true;
  };

  Loader.prototype.onModuleBeginDownload = function(module) {};

  Loader.prototype.onModuleDownloadFailed = function(event, module, error) {};

  Loader.prototype.onModuleDownloadProgress = function(event, module) {};

  Loader.prototype.onTotalDownloadProgress = function(progress) {};

  Loader.prototype.onModuleDownloaded = function(module) {};

  Loader.prototype.onEvaluationStarted = function(manifest) {
    return true;
  };

  Loader.prototype.onEvaluationError = function(module, error) {};

  Loader.prototype.onModuleEvaluated = function(module) {};

  Loader.prototype.onApplicationReady = function(manifest) {
    return this.checkUpdate();
  };

  Loader.prototype.emit = function() {
    var args, error, name, _ref;
    name = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    (_ref = this.logger).info.apply(_ref, [name].concat(__slice.call(args)));
    try {
      return this["on" + name].apply(this, args);
    } catch (_error) {
      error = _error;
      return this.logger.error(error);
    }
  };

  Loader.prototype.load = function() {
    var error;
    try {
      this._current_manifest = this.get_manifest();
    } catch (_error) {
      error = _error;
      this.emit("NoManifest", error);
      return;
    }
    this.logger.info("Current manifest", this._current_manifest);
    if (this.emit("EvaluationStarted", this._current_manifest) !== false) {
      this.evaluate(this._current_manifest.modules).then((function(_this) {
        return function() {
          return _this._cleanUp();
        };
      })(this));
    }
  };

  Loader.prototype.evaluate = function(queue) {
    var key, module;
    this._stats.evaluate_module_start.push(new Date().getTime());
    queue = queue.concat();
    if (queue.length === 0) {
      this.emit("ApplicationReady", this._current_manifest);
      return;
    }
    module = queue.shift();
    key = this.make_key(module);
    return this.get_content(key).then((function(_this) {
      return function(module_source) {
        var alias, dep, deps, error, evaluator, evaluator_type, namespace, _ref;
        _this._stats.evaluate_module_loaded_from_db.push(new Date().getTime());
        if (module_source == null) {
          _this.emit("EvaluationError", module, new NoSourceError(module.url));
          return;
        }
        try {
          module.source = _this.decoder_func(module_source, module, _this);
        } catch (_error) {
          error = _error;
          _this.emit("EvaluationError", module, error);
          return;
        }
        _this._stats.evaluate_module_decoded.push(new Date().getTime());
        deps = {};
        _ref = module.deps;
        for (alias in _ref) {
          dep = _ref[alias];
          deps[alias] = _this._all_modules[dep];
        }
        deps["loader"] = _this;
        evaluator_type = _this._get_evaluator(module);
        evaluator = new evaluator_type({
          id: module.id,
          source: module.source,
          dependencies: deps,
          url: module.url
        });
        try {
          namespace = evaluator.run();
        } catch (_error) {
          error = _error;
          _this.emit("EvaluationError", module, error);
          return;
        }
        _this._all_modules[module.id] = namespace;
        module.namespace = namespace;
        _this.emit("ModuleEvaluated", module);
        return _this.evaluate(queue);
      };
    })(this))["catch"]((function(_this) {
      return function(err) {
        _this.emit("EvaluationError", module, new DBError(module.url, err));
      };
    })(this));
  };

  Loader.prototype.checkUpdate = function() {
    var manifest_request;
    if (this._update_started) {
      return false;
    }
    this.logger.info("Checking for update...");
    manifest_request = XHR();
    manifest_request.open("GET", this._prepare_url(this.manifest_location), true);
    manifest_request.overrideMimeType("application/json; charset=utf-8");
    manifest_request.onload = (function(_this) {
      return function(event) {
        var error;
        if (event.target.status === 404) {
          _this.emit("UpdateFailed", event, null);
          return;
        }
        try {
          _this._new_manifest = _this._parse_manifest(event.target.response);
        } catch (_error) {
          error = _error;
          _this.emit("UpdateFailed", event, error);
          return;
        }
        _this.logger.info("New manifest", _this._new_manifest);
        if (_this._current_manifest != null) {
          if (_this._current_manifest.hash === _this._new_manifest.hash) {
            _this.emit("UpToDate", event, _this._current_manifest);
            return;
          }
        }
        return _this.emit("UpdateFound", event, _this._new_manifest);
      };
    })(this);
    manifest_request.onerror = (function(_this) {
      return function(event) {
        return _this.emit("UpdateFailed", event, null);
      };
    })(this);
    manifest_request.onabort = (function(_this) {
      return function(event) {
        return _this.emit("UpdateFailed", event, null);
      };
    })(this);
    manifest_request.send();
    return true;
  };

  Loader.prototype.startUpdate = function() {
    var module, _i, _j, _len, _len1, _ref, _ref1;
    if (this._update_started) {
      return false;
    }
    this.logger.info("Starting update...");
    this._update_started = true;
    _ref = this._new_manifest.modules;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      module = _ref[_i];
      module.loaded = 0;
    }
    this._modules_to_load = this._new_manifest.modules.concat();
    if ((this._current_manifest == null) && (this._new_manifest.bundle != null)) {
      this._downloadBundle();
    } else {
      _ref1 = this._modules_to_load.splice(0, 4);
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        module = _ref1[_j];
        this._updateModule(module);
      }
    }
    return true;
  };

  Loader.prototype.dropData = function() {
    return this.del_manifest();
  };

  Loader.prototype._downloadBundle = function() {
    var bundle, bundle_request;
    bundle = this._new_manifest.bundle;
    bundle_request = XHR();
    bundle_request.open("GET", this._prepare_url(bundle.url), true);
    bundle_request.responseType = "arraybuffer";
    bundle_request.onload = (function(_this) {
      return function(event) {
        var bundle_source, hash;
        bundle_source = event.target.response;
        hash = _this.hash_func(bundle_source);
        if (hash !== bundle.hash) {
          _this.emit("UpdateFailed", event, new HashMismatchedError(bundle.url, hash, bundle.hash));
          return;
        }
        _this._disassembleBundle(bundle_source);
      };
    })(this);
    bundle_request.onprogress = (function(_this) {
      return function(event) {
        var module, progress, total_count, total_size, _i, _len, _ref;
        total_size = 0;
        total_count = 0;
        _ref = _this._new_manifest.modules;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          module = _ref[_i];
          total_size += module.size;
          total_count++;
        }
        progress = {
          loaded_count: 0,
          total_count: total_count,
          loaded_size: event.loaded,
          total_size: total_size
        };
        return _this.emit("TotalDownloadProgress", progress);
      };
    })(this);
    bundle_request.onerror = (function(_this) {
      return function(event) {
        return _this.emit("UpdateFailed", event, null);
      };
    })(this);
    bundle_request.onabort = (function(_this) {
      return function(event) {
        return _this.emit("UpdateFailed", event, null);
      };
    })(this);
    bundle_request.send();
  };

  Loader.prototype._disassembleBundle = function(bundle) {
    var hash, module, module_source, pointer, _i, _len, _ref;
    this._modules_to_load;
    pointer = 0;
    _ref = this._new_manifest.modules;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      module = _ref[_i];
      module_source = bundle.slice(pointer, pointer + module.size);
      hash = this.hash_func(module_source);
      if (hash !== module.hash) {
        this.emit("ModuleDownloadFailed", event, module, new HashMismatchedError(module.url, hash, module.hash));
        return;
      }
      module.source = module_source;
      module.loaded = module.size;
      pointer += module.size;
    }
    return this._storeModule(this._modules_to_load.shift());
  };

  Loader.prototype._storeModule = function(module) {
    var onNextModule;
    onNextModule = (function(_this) {
      return function(module) {
        return _this._storeModule(module);
      };
    })(this);
    return this.set_content(this.make_key(module), module.source).then((function(_this) {
      return function(content) {
        _this.emit("ModuleDownloaded", module);
        _this._reportTotalProgress();
        _this._checkAllUpdated(onNextModule);
      };
    })(this))["catch"]((function(_this) {
      return function(err) {
        _this.emit("ModuleDownloadFailed", null, module, new DBError(module.url, err));
      };
    })(this));
  };

  Loader.prototype._updateModule = function(module) {
    var key, onDownload, onNextModule;
    this._stats.update_module_start.push(new Date().getTime());
    key = this.make_key(module);
    onNextModule = (function(_this) {
      return function(module) {
        return _this._updateModule(module);
      };
    })(this);
    onDownload = (function(_this) {
      return function() {
        return _this._checkAllUpdated(onNextModule);
      };
    })(this);
    this.get_content(key).then((function(_this) {
      return function(module_source) {
        _this._stats.update_module_loaded_from_db.push(new Date().getTime());
        if (module_source == null) {
          return _this._downloadModule(module, onDownload);
        }
        if (_this.hash_func(module_source) !== module.hash) {
          _this.emit("ModuleDownloadFailed", null, module, new HashMismatchedError(module.url, hash, module.hash));
          return;
        }
        module.source = module_source;
        module.loaded = module.size;
        _this.emit("ModuleDownloaded", module);
        _this._reportTotalProgress();
        _this._checkAllUpdated(onNextModule);
      };
    })(this))["catch"]((function(_this) {
      return function(err) {
        return _this._downloadModule(module, onDownload);
      };
    })(this));
  };

  Loader.prototype._reportTotalProgress = function() {
    var loaded_count, loaded_size, module, progress, total_count, total_size, _i, _len, _ref;
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
    progress = {
      loaded_count: loaded_count,
      total_count: total_count,
      loaded_size: loaded_size,
      total_size: total_size
    };
    return this.emit("TotalDownloadProgress", progress);
  };

  Loader.prototype._downloadModule = function(module, cb) {
    var module_request;
    this.emit("ModuleBeginDownload", module);
    module_request = XHR();
    module_request.open("GET", this._prepare_url(module.url), true);
    module_request.responseType = "arraybuffer";
    module_request.onload = (function(_this) {
      return function(event) {
        var hash, module_source;
        module_source = event.target.response;
        hash = _this.hash_func(module_source);
        if (hash !== module.hash) {
          _this.emit("ModuleDownloadFailed", event, module, new HashMismatchedError(module.url, hash, module.hash));
          return;
        }
        return _this.set_content(_this.make_key(module), module_source).then(function(content) {
          module.source = module_source;
          module.loaded = module.size;
          _this.emit("ModuleDownloaded", module);
          _this._reportTotalProgress();
          cb();
        })["catch"](function(err) {
          _this.emit("ModuleDownloadFailed", null, module, new DBError(module.url, err));
        });
      };
    })(this);
    module_request.onprogress = (function(_this) {
      return function(event) {
        module.loaded = event.loaded;
        _this.emit("ModuleDownloadProgress", event, module);
        return _this._reportTotalProgress();
      };
    })(this);
    module_request.onerror = (function(_this) {
      return function(event) {
        return _this.emit("ModuleDownloadFailed", event, module, null);
      };
    })(this);
    module_request.onabort = (function(_this) {
      return function(event) {
        return _this.emit("ModuleDownloadFailed", event, module, null);
      };
    })(this);
    module_request.send();
  };

  Loader.prototype._checkAllUpdated = function(cb) {
    var module, next, _i, _len, _ref;
    next = this._modules_to_load.shift();
    if (next != null) {
      cb(next);
      return;
    }
    _ref = this._new_manifest.modules;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      module = _ref[_i];
      if (module.source == null) {
        return;
      }
    }
    if (this.emit("UpdateCompleted", this._new_manifest)) {
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
        _this.del_content(key)["catch"](function(error) {
          return _this.logger.error(error);
        });
      };
    })(this));
  };

  return Loader;

})();
