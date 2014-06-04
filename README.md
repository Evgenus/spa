#SPA

[![Dependency Status](https://david-dm.org/Evgenus/spa.svg)](https://david-dm.org/Evgenus/spa)
[![devDependency Status](https://david-dm.org/Evgenus/spa/dev-status.svg)](https://david-dm.org/Evgenus/spa#info=devDependencies)
[![GitHub version](https://badge.fury.io/gh/Evgenus%2Fspa.svg)](http://badge.fury.io/gh/Evgenus%2Fspa)

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

**root** - path where the file search will start, may be relative to config file itself.

**extensions** - files to consider as modules, `[".js"]` by default.

**excludes** - files to ignore, empty by default.
List may contains wildcards/globs, eg. `./something/**/test/*.js`. Paths are relative to root path.

**paths** - path aliases to use during module name resolution.

Example:
```
root: "/testimonial/"
paths:
    vendor: "/lib/contrib"
```
This allows to use module `/testimonial/lib/contrib/b.js` from file `/testimonial/src/a.js` as `require('vendor/b.js')`

**hosting** - similar dict which specifies how to remap paths to URLs.
Keys - rules as in `excludes`, where you can select path fragments in brackets,
values - URI format where selected fragments will be substitutes.

If you want files to be included in cache manifest, they need to match at least one pattern in `hosting` as well.

Example:
```
hosting:
    "/lib/(**/*.js)": "http://myapp.com/$1"
```

File `/lib/app/main.js` will be loaded `http://myapp.com/app/main.js`.

**loaders** - rules which describe what module formats JS files use.

Keys - rules as in `excludes`, values - format types. Available formats:
- _cjs_ - `CommonJS`
- _amd_ - `AMD` or `UMD`.
- _junk_ - module needs to mutate `window`
- _raw_ - local variables from module needs to be in `global` context (like `<script>`)

**default_loader** - loader for files not matched by loaders

**manifest** - relative path to loader manifest. Can be omitted.

**hash_func** ─ has function to be used in `manifest` and `appcache` generation process. Value may be `md5`, `ripemd160`, `sha1`, `sha224`, `sha256`, `sha3`, `sha384`, `sha512`. Default value is `md5`.

**randomize_urls** ─ this parameter to be transletad into loader thru `index_template`. If `true` loader will add some random characters to URLs for manifest and application files suppressing caching.

**pretty** - pretty-print manifest json

**index** - relative path to bootstrap html file. Loader and its dependencies (but not app dependencies) will be baked into this file. Can be omitted.

**appcache** - relative path to HTML5 AppCache Manifest. 

**cached** - paths to other files to include in appcache. URLs are remapped according to **hosting** dict.

**assets** - path to customizable builder templates

- appcache_template - template to generate `appcache`. Can include `cached` list.
- index_template - template to generate `index`. You can use `assets` to include them, except the `index_template` itself :)

## Example

```yaml
root: "/testimonial/"
index: index.html
appcache: main.appcache
paths:
    vendor: "/lib/contrib"
assets:
    index_template: /assets/index.tmpl
    appcache_template: /assets/appcache.tmpl
hash_func: sha256
cached:
    - /a.js
hosting:
    "/(**/*.*)": "http://127.0.0.1:8010/$1"
```

## Alternatives

Other modules you should definitelly look at:

 * [gluejs](http://mixu.net/gluejs/)
 * [browserbuild](https://github.com/learnboost/browserbuild/)
 * [browserify](http://browserify.org/)

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
│       └───hash                    wrapped and prepared hash-functions code
├───node_modules                    builder dependencies; installs with `npm`
├───src                             coffee-script source code
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

## Copyright and license

Code and documentation copyright 2014 Eugene Chernyshov. Code released under [the MIT license](LICENSE).

[![Total views](https://sourcegraph.com/api/repos/github.com/Evgenus/spa/counters/views.png)](https://sourcegraph.com/github.com/Evgenus/spa)
[![Views in the last 24 hours](https://sourcegraph.com/api/repos/github.com/Evgenus/spa/counters/views-24h.png)](https://sourcegraph.com/github.com/Evgenus/spa)
[![library users](https://sourcegraph.com/api/repos/github.com/Evgenus/spa/badges/library-users.png)](https://sourcegraph.com/github.com/Evgenus/spa)
[![xrefs](https://sourcegraph.com/api/repos/github.com/Evgenus/spa/badges/xrefs.png)](https://sourcegraph.com/github.com/Evgenus/spa)