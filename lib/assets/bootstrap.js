var $, UI, emptyArray;

emptyArray = [];

UI = (function() {
  function UI(items) {
    this.items = items;
  }

  UI.prototype.each = function(callback) {
    emptyArray.every.call(this.items, function(el, idx) {
      return callback.call(el, idx, el) !== false;
    });
    return this;
  };

  UI.prototype.addClass = function(name) {
    if (name == null) {
      return this;
    }
    return this.each(function(idx) {
      var classList, klass, _i, _len, _ref;
      classList = this.className.split(/\s+/g);
      _ref = name.split(/\s+/g);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        klass = _ref[_i];
        if (classList.indexOf(klass) === -1) {
          classList.push(klass);
        }
      }
      return this.className = classList.join(" ");
    });
  };

  UI.prototype.removeClass = function(name) {
    return this.each(function(idx) {
      var classList, index, klass, _i, _len, _ref;
      if (name == null) {
        this.className = "";
        return;
      }
      classList = this.className.split(/\s+/g);
      _ref = name.split(/\s+/g);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        klass = _ref[_i];
        index = classList.indexOf(klass);
        if (index >= 0) {
          classList.splice(index);
        }
      }
      return this.className = classList.join(" ");
    });
  };

  UI.prototype.text = function(text) {
    if (text != null) {
      return this.each(function() {
        return this.textContent = '' + text;
      });
    } else {
      if (this.length > 0) {
        return this[0].textContent;
      }
    }
  };

  UI.prototype.css = function(property, value) {
    var computedStyle, element;
    if (arguments.length < 2) {
      element = this.items[0];
      if (element == null) {
        return;
      }
      computedStyle = getComputedStyle(element, '');
      return computedStyle.getPropertyValue(property);
    }
    if (!value && value !== 0) {
      return this.each(function() {
        return this.style.removeProperty(property);
      });
    } else {
      return this.each(function() {
        return this.style.cssText += ';' + property + ":" + value;
      });
    }
  };

  UI.prototype.attr = function(name, value) {
    var element;
    if (arguments.length < 2) {
      element = this.items[0];
      if (element == null) {
        return;
      }
      return element.getAttribute(name);
    }
    if (value != null) {
      return this.each(function() {
        return this.setAttribute(name, value);
      });
    } else {
      return this.each(function() {
        return this.removeAttribute(name);
      });
    }
  };

  UI.prototype.clone = function() {
    return new UI(emptyArray.map.call(this.items, function(el) {
      return el.cloneNode(true);
    }));
  };

  UI.prototype.append = function(elements) {
    return this.each(function() {
      var parent;
      parent = this;
      elements.each(function() {
        return parent.appendChild(this.cloneNode(true));
      });
    });
  };

  UI.prototype.find = function(selector) {
    var result;
    result = [];
    this.each(function() {
      var nodes;
      nodes = this.querySelectorAll(selector);
      return emptyArray.every.call(nodes, function(el, idx) {
        return result.push(el);
      });
    });
    return new UI(result);
  };

  return UI;

})();

$ = function(param) {
  if (typeof param === "string") {
    return new UI([document]).find(param);
  } else {
    return new UI(param);
  }
};
var log,
  __slice = [].slice;

log = function() {
  var args;
  args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
  return loader.log.apply(loader, ["bootstrap"].concat(__slice.call(args)));
};

loader.onNoManifest = function() {
  log("onNoManifest");
  loader.onUpdateFailed = function(event, error) {
    log("onUpdateFailed", event, error);
    $("#loader .page").addClass("hide");
    $("#page-fail").removeClass("hide");
    return $("#page-fail .error").text(error != null ? error : event.target.statusText);
  };
  loader.onUpdateFound = function(event, manifest) {
    var el, id, list, module, proto, _i, _len, _ref;
    log("onUpdateFound", event, manifest);
    $("#loader .page").addClass("hide");
    $("#page-update").removeClass("hide");
    proto = $("#download-item-template");
    list = $("#page-update .items");
    _ref = manifest.modules;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      module = _ref[_i];
      id = "module-" + module.id;
      el = proto.clone().attr("id", id);
      el.find(".name").text(module.url);
      list.append(el);
    }
    return loader.startUpdate();
  };
  loader.onModuleBeginDownload = function(module) {
    var el;
    log("onModuleBeginDownload", module);
    el = $("#module-" + module.id);
    el.find(".state").addClass("hide");
    el.find(".progress").removeClass("hide");
    el.find(".bytes-loaded").text(0);
    return el.find(".bytes-total").text(module.size);
  };
  loader.onModuleDownloadFailed = function(event, module) {
    var el;
    log("onModuleDownloadFailed", event, module);
    el = $("#module-" + module.id);
    el.find(".state").addClass("hide");
    return el.find(".error").text(event.target.statusText).removeClass("hide");
  };
  loader.onModuleDownloadProgress = function(event, module) {
    var el;
    log("onModuleDownloadProgress", event, module);
    el = $("#module-" + module.id);
    return el.find(".bytes-loaded").text(event.loaded);
  };
  loader.onModuleDownloaded = function(module) {
    var el;
    log("onModuleDownloaded", module);
    el = $("#module-" + module.id);
    el.find(".state").addClass("hide");
    return el.find(".success").removeClass("hide");
  };
  loader.onTotalDownloadProgress = function(progress) {
    log(progress);
    $("#page-update .total-progress .modules-loaded").text(progress.loaded_count);
    $("#page-update .total-progress .modules-total").text(progress.total_count);
    $("#page-update .total-progress .bytes-loaded").text(progress.loaded_size);
    return $("#page-update .total-progress .bytes-total").text(progress.total_size);
  };
  loader.onUpdateCompleted = function(manifest) {
    log("onUpdateCompleted", manifest);
    setTimeout(location.reload.bind(location), 0);
    return true;
  };
  return loader.checkUpdate();
};

loader.onEvaluationStarted = function(manifest) {
  var el, id, list, module, proto, _i, _len, _ref;
  log("onEvaluationStarted");
  $("#loader .page").addClass("hide");
  $("#page-load").removeClass("hide");
  proto = $("#evaluate-item-template");
  list = $("#page-load .items");
  _ref = manifest.modules;
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    module = _ref[_i];
    id = "module-" + module.id;
    el = proto.clone().attr("id", id);
    el.find(".name").text(module.url);
    list.append(el);
  }
  loader.onEvaluationError = function(module, error) {
    log("onEvaluationError", module, error);
    el = $("#module-" + module.id);
    el.find(".state").addClass("hide");
    return el.find(".error").text(error).removeClass("hide");
  };
  loader.onModuleEvaluated = function(module) {
    log("onModuleEvaluated", module);
    el = $("#module-" + module.id);
    el.find(".state").addClass("hide");
    return el.find(".success").removeClass("hide");
  };
  return loader.onApplicationReady = function(manifest) {
    log("onApplicationReady");
    return this.checkUpdate();
  };
};
