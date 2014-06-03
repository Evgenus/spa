var $, UI, emptyArray;

emptyArray = [];

UI = (function() {
  function UI(selector, element) {
    this.items = (element != null ? element : document).querySelectorAll(selector);
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
      element = this[0];
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

  return UI;

})();

$ = function(selector) {
  return new UI(selector);
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
  loader.onTotalDownloadProgress = function(progress) {
    log(progress);
    return $("#total-progress").text((progress.loaded_size / progress.total_size * 100) + "%");
  };
  loader.onUpdateCompleted = function(manifest) {
    log("onUpdateCompleted", manifest);
    setTimeout(location.reload.bind(location), 0);
    return true;
  };
  loader.onUpdateFound = function(event, manifest) {
    log("onUpdateFound", event, manifest);
    return loader.startUpdate();
  };
  return loader.checkUpdate();
};

loader.onEvaluationStarted = function(manifest) {
  log("onEvaluationStarted");
  return loader.onApplicationReady = function(manifest) {
    log("onApplicationReady");
    $("#title-loading").addClass("hide");
    $("#title-done").removeClass("hide");
    return this.checkUpdate();
  };
};
