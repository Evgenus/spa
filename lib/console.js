var context, setEnabled, silent;

silent = function() {
  return null;
};

context = {
  enabled: null
};

setEnabled = function(enabled) {
  if (this.enabled === enabled) {
    return;
  }
  this.enabled = enabled;
  if (this.enabled) {
    this.log = console.log.bind(console);
    this.info = console.info.bind(console);
    this.warn = console.warn.bind(console);
    this.error = console.error.bind(console);
    this.dir = console.dir.bind(console);
    this.trace = console.trace.bind(console);
    return this.assert = console.assert.bind(console);
  } else {
    this.log = silent;
    this.info = silent;
    this.warn = silent;
    this.error = silent;
    this.dir = silent;
    this.trace = silent;
    return this.assert = silent;
  }
};

setEnabled.call(context, true);

exports.isEnabled = function() {
  return context.enabled;
};

exports.disable = function() {
  return setEnabled.call(context, false);
};

exports.enable = function() {
  return setEnabled.call(context, true);
};

exports.log = function() {
  return context.log.apply(context, arguments);
};

exports.info = function() {
  return context.info.apply(context, arguments);
};

exports.warn = function() {
  return context.warn.apply(context, arguments);
};

exports.error = function() {
  return context.error.apply(context, arguments);
};

exports.dir = function() {
  return context.dir.apply(context, arguments);
};

exports.trace = function() {
  return context.trace.apply(context, arguments);
};

exports.assert = function() {
  return context.assert.apply(context, arguments);
};

exports.setEnabled = setEnabled.bind(context);
