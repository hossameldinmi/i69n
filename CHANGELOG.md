## 3.8.0

- new `_select(value, case: 'text', ...)` message helper: branch a message on an
  enum value (or any value, matched by `toString()`), with an optional `other:`
  fallback and an empty string when nothing matches
- `_select` works in remote bundles too, resolved by the runtime interpreter
- `_select` is not enum-only: a `bool` branches on `true` / `false` cases, and any
  other value matches by `toString()`
- a malformed `_select` (unterminated call, case without a name or text,
  duplicate case, no cases) now fails the build instead of emitting broken Dart

## 3.7.0

- new `.i69n.json` input format: strict JSON message catalogs generating the
  same Dart as YAML; JSON values are escaped automatically (`"` and `\` are
  literal text outside `${...}`), unlike YAML's manual-escaping convention
- new `_i69n: remote` flag: runtime-loaded translations with baked fallbacks —
  fetch a payload yourself and inject it with `load(Map)`; a loaded value wins,
  then the compiled-in default, then the key itself
- a locale remote bundle shares the root bundle's loaded data, so one `load`
  feeds inherited and locale-declared keys alike
- a malformed or unusable remote template (bad syntax, plural with no usable
  form) falls back to the baked default instead of crashing or rendering `???`
- internal rewrite: node-tree model (`lib/src/shared/`) replaces the string
  renderer; message keys and parameter declarations are now validated and fail
  the build with a message pointing at the input file

## 3.6.0

- added ukrainian plural language rules

## 3.5.0

- added "dart format off" to skip formatting and unnecessary VCS changes

## 3.4.0

- fixed emojis: https://github.com/fnx-io/i69n/issues/14 

## 3.3.0

- Support for `build` package `<5.0.0`

## 3.2.1

- Support for `build` package `>=3.0.0`

## 3.2.0

- Added global configuration support for `nomap` and `notraverse` flags via `build.yaml`
- New `notraverse` flag to control dot notation access (`messages['nested.message']`)
- Local override support: use `map`/`traverse` flags to override global `nomap`/`notraverse` settings
- Enhanced test coverage for new functionality

## 3.1.0

- Bump the min sdk to `3.6.0`
- Update `dart_style` constraint to `^3.0.0`
- Updated other dependencies

## 3.0.0-alpha.1

- support for custom types and custom imports
- added docs for region support

## 2.1.0

- new 'prenullsafe' flag, which generate 'pre null safe' Dart code ('String' instead of 'String?')

## 2.0.2

- new nothrow flag

## 2.0.1

- Nullsafe README

## 2.0.0

- Nullsafe release

## 2.0.0-nullsafety.2

- Update dependencies

## 2.0.0-nullsafety.1

- migration to null safety

## 1.1.0

- polishing, fine-tuning, release

## 1.0.0

- possibility to customize generator behaviour with flags
- map operator is now generated only for objects with 'map' flag

## 0.5.0

- even more pedantic friendly - resolved all warnings

## 0.4.0

- pedantic friendly - both project source files and generated messages

## 0.3.0

- more benevolent dependencies (for web use angular: 5.3.1)

## 0.2.0

- Upgrade to Dart 2.5.1 and build_runner 1.7.1
- added possibility to access messages with string keys, not only Dart identifiers (i.e. `m['generic.ok']`)
- output is formatted with Dartfmt

## 0.1.0

- Seems good, let's move up

## 0.0.2

- More README

## 0.0.1

- Initial version, created by Stagehand
- Just getting started.
