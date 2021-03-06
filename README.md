#SPA [![Build Status](https://drone.io/github.com/Evgenus/spa/status.png)](https://drone.io/github.com/Evgenus/spa/latest)

[![Dependency Status](https://david-dm.org/Evgenus/spa.svg)](https://david-dm.org/Evgenus/spa)
[![devDependency Status](https://david-dm.org/Evgenus/spa/dev-status.svg)](https://david-dm.org/Evgenus/spa#info=devDependencies)
[![GitHub version](https://badge.fury.io/gh/Evgenus%2Fspa.svg)](http://badge.fury.io/gh/Evgenus%2Fspa)

![SPA](./artwork/spa.png)

**S** ingle **P** age **A** pplications builder with continuous integration, granular updates and loader.

The general idea is to calculate dependencies offline and then eagerly cache/load modules in predefined order.
Also we can detect which files are changed and do partial updates.

Preferred module format is `CommonJS`.

Advantages:

 - no async dependency resolution
 - no AMD wrappers
 - less moving parts and mutable state
 - less data duplication and possible conflicts
 - loader code is separate from application code
 - loading progress is easy to visualize

## Running builder

All options are stored in config file. So the only command line parameter is a config file path.

```
spa -c spa.yaml
```

## Options

Config file is a `dict` in YAML or JSON format with the following keys:

**root**(required) - path where the file search will start, may be relative to config file itself.

**extensions**(optional) - files to consider as modules, `[".js"]` by default.

**excludes**(optional) - files to ignore, empty by default.
List may contains wildcards/globs, eg. `./something/**/test/*.js`. Paths are relative to root path.

**paths**(optional) - path aliases to use during module name resolution.

Example:
```yaml
root: "/testimonial/"
paths:
    vendor: "./lib/contrib"
```
This allows to use module `/testimonial/lib/contrib/b.js` from file `/testimonial/src/a.js` as `require('vendor/b.js')`

**grab**(optional) - do try grab all dependencies suppressing ExternalDependencyErrors. 
Can walk inside `node_modules` with `commonjs` rules recursively.  Default value is `false`.

**hosting**(required for web usage) - similar dict which specifies how to remap paths to URLs.
Keys - rules as in `excludes`, where you can select path fragments in brackets,
values - URI format where selected fragments will be substitutes.

If you want files to be included in cache manifest, they need to match at least one pattern in `hosting` as well.

Example:
```yaml
hosting:
    "./lib/(**/*.js)": "http://myapp.com/$1"
```

File `./lib/app/main.js` will be loaded `http://myapp.com/app/main.js`.

**hosting_map**(optional) - relative path to output hosting map file. Can be omitted. 

Hosting map format:
```json
{
    "version": 1,
    "files": {
        "relative/hosting/path1.js": "node_modules/source/path1.js",
    },
    "manifest": {
        "url": "relative/hosting/manifest.json",
        "path": "node_modules/source/path1.js"
    },
    "index": {
        "url": "http://site.com/hosting/index.html",
        "path": "build/index.html"
    }
}
```

**loaders**(optional) - rules which describe what module formats JS files use.

Keys - rules as in `excludes`, values - format types. Available formats:
- _cjs_ - `CommonJS`
- _amd_ - `AMD` or `UMD`.
- _junk_ - module needs to mutate `window`
- _raw_ - local variables from module needs to be in `global` context (like `<script>`)

**default_loader**(optional) - loader for files not matched by loaders. Default value is `cjs`.

**manifest**(optional) - relative path to loader manifest. Can be omitted.

**bundle**(optional) - relative path where bundle will be stored. Bundle used at first run to speed up downloading. Can be omitted.

**hash_func**(optional) - has function to be used in `manifest` and `appcache` generation process. Value may be `md5`, `ripemd160`, `sha1`, `sha224`, `sha256`, `sha3`, `sha384`, `sha512`. Default value is `md5`. New hash function could be easily added as assets to builder. Hack into `Cakefile` for mere information.

**randomize_urls**(optional) - this parameter to be transletad into loader thru `index_template`. If `true` loader will add some random characters to URLs for manifest and application files to suppress caching.

**pretty**(optional) - pretty-print manifest and other json files. Default is `false`.

**print_roots**(optional) - output list of root modules no one depends on. Default is `true`.

**print_stats**(optional) - output statistics about analyzed modules. Default is `true`.

**index**(optional) - relative path to bootstrap html file. Loader and its dependencies (but not app dependencies) will be baked into this file. Can be omitted.

**appcache**(optional) - relative path to HTML5 AppCache Manifest. 

**cached**(optional) - paths to other files to include in appcache. URLs are remapped according to **hosting** dict.

**assets**(optional) - path to customizable builder templates

- _appcache_template_ - template to generate `appcache`. Can include `cached` list.
- _index_template_ - template to generate `index`. You can use `assets` to include them, except the `index_template` itself :)

**coding_func**(optional) - dictionary that defines parameters of encoding function. Viable parameters depends on particular function. The only necessary parameter is `name` which value may be `aes-ccm`, `aes-gcm`, `aes-ocb2`.

Example:
```yaml
coding_func:
    name: aes-gcm
    password: babuka
    iter: 1000
    ks: 128
    ts: 128
```
**copying**(required for `coding_func`) - same set of rules as in `hosting` but used together with `coding_func` to store encoded files.

> Enabling encryption could possibly overwrite your source files if copying rules was not properly specified. 
> Use this feature with caution. 
> Ensure that you've commited changes into restorable repository before you build.

**cache_file**(optional) - path to cache-file. This option is also necessary for using some of `coding_func`. To preserve incremental updates feature we have to query some data from previous builds. Default value is `.spacache`. This path is relative to `root`

Example:
```yaml
copying:
    "./lib/(**/*.js)": "./build/$1"
```

## Example

```yaml
root: "./testimonial/"
index: index.html
appcache: main.appcache
manifest: manifest.json
paths:
    vendor: "./lib/contrib"
assets:
    index_template: /assets/index.tmpl
    appcache_template: /assets/appcache.tmpl
hash_func: sha256
cached:
    - /a.js
hosting:
    "./(**/*.*)": "http://127.0.0.1:8010/$1"
hosting_map: hosting.json
bundle: "./bundle.js"
coding_func:
    name: aes-gcm
    password: babuka
    iter: 1000
    ks: 128
    ts: 128
copying:
    "./lib/(**/*.js)": "./build/$1"
grab: true
```

## Alternatives

Read this book [Single page apps in depth](http://singlepageappbook.com)!

Other modules you should definitely look at:

 * [browserify](http://browserify.org/)
 * [gluejs](http://mixu.net/gluejs/)
 * [browserbuild](https://github.com/learnboost/browserbuild/)
 * [stitch](https://github.com/sstephenson/stitch)
 * [wrapup](https://github.com/kamicane/wrapup)

## Development

Report new [issues](https://github.com/Evgenus/spa/issues). I'm open for collaboration.

### Installing from GitHub

```
npm install git://github.com/Evgenus/spa.git#stable
```

### Project structure

```
spa
├───bin                             executable builder file
├───bower_components                loader dependencies; installs with `bower`
├───lib                             compiled builder files
│   └───assets                      builder assets (templates, compiled loader, loader assets)
│       ├───decode                  prepared decoding functions for using in loader
│       ├───encode                  prepared encoding functions for using in builder
│       └───hash                    wrapped and prepared hash-functions code
├───node_modules                    builder dependencies; installs with `npm`
├───src                             coffee-script source code
│   ├───assets                      various assets templates and helpers sources
│   ├───builder                     source code of builder
│   ├───bootstrap                   source code of bootstrap code with default callbacks and UI visualization
│   └───loader                      source code of loader
└───tests                           tests for builder and loader
```

### Installing dependencies

```
npm install
bower install
```

### Compiling project

```
cake build
```

### Testing 

Tests require devDependencies to be installed! Tests require `Selenium Standalone Server`.

```
npm test
```

### Events and API methods 

To subscribe for event you simply need to assign handler into loader instance.
```javascript
loader.onEventName = function Handler(param1, param2) { /*....*/ }
```

**load()** - starts loading current version of hosted application.

Possible generated events:

* `NoManifest(error)` - this event fires when there is no current version of application. Either the application is being started for the first time or previous download was unsuccessful. Usually `checkUpdate` method should be called in the handler. 
* `EvaluationStarted(manifest)` - event fires when current version was found and about to be loaded. If handler returns `false` then loaded will not perform any further actions and halts. Parameters: `manifest` - manifest of current version as an object.
* `ModuleEvaluated(module)` - event fires for each successfully loaded module. Parameters: `module` - loaded module descriptor (as inside of manifest).
* `EvaluationError(module, error)` - fires if there was an error during module loading. All further loading could not be performed and loader halts. Event `ApplicationReady` will not be fired. Parameters: `module` - problem module descriptor (some fields may be absent); `error` - occurred error(some frequent errors are strictly typed).
* `ApplicationReady(manifest)` - event notifies host application about its successfully loading. Inside handler application could start working and intercept control. Parameters: `manifest` - current manifest.

**checkUpdate()** - checks server for newer version of application. 
Returns `false` if process of checking or updating already has been started, otherwise `true`.

* `UpToDate(event, manifest)` - event fires if latest version of application was already downloaded. Parameters: `manifest` - cuurent manifest.
* `UpdateFound(event, manifest)` - event occurs if a newer version of the application was found. Usually `startUpdate` should be called inside handler or user asked for confirmation before downloading new version files. Current version is assumed to be working at this time. Parameters: `event` - the event object passed by browser as a result of the request; `manifest` - the manifest of a new version.
* `UpdateFailed(event, error)` - event occurs if for some of the reason a newer version could not be found or manifest of newer version is incorrect. It also occurs if current loader is outdated and not compatible with the new format of the manifest. Parameters: `event` - the event object passed by browser as a result of the query (you can obtain network errors from it); `error` - error arose during the analysis of the manifest of the newer version or downloading bundle (may be `null`).


**startUpdate()** - initialize downloading of the newer version of the application accordingly to previously downloaded manifest. 
Returns `false` if process of updating already has been started, otherwise `true`.

* `ModuleBeginDownload(module)` - event fires when each module is about to be downloaded. Parameters: `module` - module descriptor object from newer version manifest.
* `ModuleDownloadProgress(event, module)` - fires when individual module download progress changed. Parameters: `event` - browser event (downloaded bytes, etc); `module` - descriptor of module being downloaded (contains total length).
* `TotalDownloadProgress(progress)` - total download progress. `progress` is a hash with these fields: `loaded_count` - number of modules already downloaded, `total_count` - total number of modules, `loaded_size` - amount of bytes downloaded, `total_size` - total size of modules in bytes.
* `ModuleDownloadFailed(event, module, error)` - event fires when module downloading was aborted, interrupted, or data checksum did not match. Parameters: `event` - browser event, `module` - module which failed to download, `error` - contains error occured during module checking.
* `ModuleDownloaded(module)` - occurs when module was successfully downloaded. Parameters: `event` - browser event, `module` - downloaded module.
* `UpdateCompleted(manifest)` - occurs when all modules of the new version were successfully downloaded. The handler __must return__ `true`, if loader should accept new version, or `false` if update should be postponed. You can inform user about update and request application restart at this point. If update is accepted it will be loaded at next application run (next `load` call). Parameters: `manifest` - new version manifest.

**dropData** - remove current version and force data to be downloaded again. Useful in case of critical failures.

## Copyright and license

Code and documentation copyright 2014 Eugene Chernyshov. Code released under [the MIT license](LICENSE).

[![Total views](https://sourcegraph.com/api/repos/github.com/Evgenus/spa/counters/views.png)](https://sourcegraph.com/github.com/Evgenus/spa)
[![Views in the last 24 hours](https://sourcegraph.com/api/repos/github.com/Evgenus/spa/counters/views-24h.png)](https://sourcegraph.com/github.com/Evgenus/spa)
[![library users](https://sourcegraph.com/api/repos/github.com/Evgenus/spa/badges/library-users.png)](https://sourcegraph.com/github.com/Evgenus/spa)
[![xrefs](https://sourcegraph.com/api/repos/github.com/Evgenus/spa/badges/xrefs.png)](https://sourcegraph.com/github.com/Evgenus/spa)
