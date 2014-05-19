#SPA

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

**pretty** - pretty-print manifest json

**index** - relative path to bootstrap html file. Loader and its dependencies (but not app dependencies) will be baked into this file. Can be omitted.

**appcache** - relative path to HTML5 AppCache Manifest. 

**cached** - paths to other files to include in appcache. URLs are remapped according to **hosting** dict.

**assets** - path to customizable builder templates

- appcache_template - template to generate `appcache`. Can include `cached` list.
- index_template - template to generate `index`. You can use `assets` to include them, except the `index_template` itself :)
- md5 - hash checker library to use
- loader - path to compiled loader JS
- fake_app - path to fake app which is shown before first update is loaded
- fake_manifest - path to manifest of fake app

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
    loader: /assets/loader.js
    md5: /assets/md5.js
    fake_app: /assets/fake/app.js
    fake_manifest: /assets/fake/manifest.json
cached:
    - /a.js
hosting:
    "/(**/*.*)": "http://127.0.0.1:8010/$1"
```
