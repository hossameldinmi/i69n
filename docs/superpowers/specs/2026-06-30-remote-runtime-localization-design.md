# Remote runtime localization — design

**Date:** 2026-06-30
**Branch:** feature/json-support
**Status:** Approved, pending implementation plan

## Problem

Today i69n is build-time only: a `.i69n.yaml`/`.i69n.json` schema generates Dart
bundle classes whose accessors return string literals embedded at compile time
(parametrized messages use Dart's native `$name` interpolation inside the
literal). There is no way to change a translation without rebuilding the app.

We want **remote runtime localization**: localization data fetched from an
external API (JSON or YAML) and injected into the runtime, so message values can
be updated without a rebuild — while keeping i69n's typed, generated message API.

## Decisions (locked)

| # | Decision | Choice |
|---|----------|--------|
| 1 | Resolution model | **Remote-primary** — loaded data resolves first; values flow through the interpreter rather than native Dart literals (a `_baked` fallback layer is added by decision 5) |
| 2 | Placeholder syntax | **Dart-style `$name` / `${name}`**, runtime-substituted (bare identifiers only, no Dart eval) |
| 3 | Plural representation | **Keep `${_plural(...)}` string** — runtime mini-interpreter evaluates it |
| 4 | Load API | **Per-instance `bundle.load(Map data)`** on the root bundle; data held on the instance (revised from the original global registry) |
| 5 | Missing key | **Bundled default base layer** — codegen emits a `_baked` map; chain remote → baked → key |
| 6 | Opt-in | **Per-file `_i69n: remote` flag** — non-flagged files generate exactly as today |

## Architecture

### Resolution flow

Build time: a `.i69n.yaml`/`.json` containing the `remote` flag in its top-level
`_i69n:` list generates a bundle whose leaf accessors resolve **at runtime**
through an interpreter, plus a compiled-in `_baked` map holding the schema's own
templates.

Runtime: the caller fetches and decodes the remote payload (i69n stays free of
HTTP and `package:yaml` dependencies) and calls `bundle.load(map)` on the root
bundle instance. The root holds the flattened data; nested bundles reach it
through the `_parent` chain. Each accessor resolves a single key as:

```
template = bundleData[key]
        ?? _baked[key]
        ?? key                                  // never throws
result   = interpret(template, args, languageCode)
```

Because the root bundle holds mutable loaded data it is **not `const`**
(`final m = RemoteMessages();`). A freshly constructed bundle is empty and
resolves to baked defaults until `load` is called, so an app shares one loaded
instance (DI / `InheritedWidget` / provider).

The same resolution path serves baked defaults and remote overrides — one code
path, uniform behavior. All values (baked and remote) flow through the
interpreter; native Dart `$`-interpolation is replaced by runtime interpretation
for `remote` bundles only.

Non-`remote` files generate exactly as today: literal accessors, native
`$`-interpolation, no `_baked` map, no per-getter cost.

### Component 1 — Runtime interpreter (`lib/src/runtime/interpreter.dart`)

Pure, self-contained function — the single riskiest unit, tested independently:

```dart
String interpret(String template, Map<String, Object?> args, String languageCode);
```

Grammar:

```
template := (literal | '$' ident | '${' expr '}')*
expr     := call | ident
call     := ('_plural' | '_ordinal' | '_cardinal') '(' ident (',' namedArg)* ')'
namedArg := ident ':' "'" template "'"        // value is itself a template, recursive
ident    := [A-Za-z_$][A-Za-z0-9_$]*
```

Evaluation:
- `ident` → `args[ident].toString()` (missing arg → empty string).
- `call` → resolve the positional `ident` from `args` as `int`; recursively
  `interpret` each named-arg template; dispatch to the existing
  `i69n.plural` / `i69n.ordinal` / `i69n.cardinal` with the resolved category
  strings and `languageCode`.

Parser requirements:
- Walk char-by-char tracking quote state and brace depth, so a `,`, `}`, or
  `${` appearing **inside** a single-quoted arg string is not treated as
  structure.
- Handle escaped quote `\'` inside arg strings.
- Unterminated `${`, unknown function name, or non-int plural arg → throw a
  descriptive `FormatException` (a malformed template is an authoring bug, fail
  loud at the interpreter boundary).

### Component 2 — Runtime helpers (`lib/i69n.dart`)

```dart
Map<String, String> flattenMessages(Map data) { ... }  // nested -> dotted keys

String tr(Map<String, String> data, Map<String, String> baked, String key,
    Map<String, Object?> args, String languageCode) {
  final template = data[key] ?? baked[key] ?? key;
  return interpret(template, args, languageCode);
}
```

- `flattenMessages` recursively flattens nested `data` into dotted keys
  (`{home: {title: 'x'}}` → `{'home.title': 'x'}`). Leaf values are stringified;
  any `_i69n*` config keys in the payload are ignored.
- The generated root bundle owns the storage and the public `load`:
  ```dart
  final Map<String, String> _data = {};
  void load(Map data) { _data..clear()..addAll(i69n.flattenMessages(data)); }
  Map<String, String> get _messages => _data;        // children: => _parent._messages
  ```
- `tr` takes the bundle's `_messages` map directly — no global state. Calling
  `load` again replaces the instance's data.

### Component 3 — Codegen changes (`lib/src/shared/node.dart`, `file_node.dart`)

Gated on the inherited `remote` flag (file-level `_i69n: remote`, propagated to
child classes through the existing `inheritedFlags` mechanism).

- **Leaf accessors** emit an interpreter call instead of a literal:
  ```dart
  String get title => i69n.tr(_messages, _baked, 'home.title', const {}, _languageCode);
  String greeting(String name) => i69n.tr(_messages, _baked, 'home.greeting', {'name': name}, _languageCode);
  ```
  where `i69n.tr` performs the resolution chain above then `interpret`s.
- **Root bundle members** — a remote root emits `final Map<String,String> _data`,
  `void load(Map)`, and `Map<String,String> get _messages => _data`; it is
  non-`const`. Child bundles emit `get _messages => _parent._messages`.
- **`messagePath`** — a new `NodeKey` getter giving the raw-key dotted path with
  no locale prefix (e.g. `home.title`), used as the store/baked key. Distinct
  from the existing `path` getter, which prefixes the language code for
  `operator[]` error messages.
- **`_baked`** — one top-level `const Map<String, String> _baked = { ... }` per
  generated file, collecting every leaf's raw template keyed by `messagePath`.
- **`$`-escaping** — baked literals MUST escape `$` → `\$` (plus `'`, `\`,
  newlines) so the *generated file* does not Dart-interpolate them; the
  interpreter does, at runtime. This needs a new `escapeTemplate` helper,
  distinct from `escapeDartString` (which only escapes `\t`/`\n`/`\r`). This is
  the subtlest correctness risk in the design: compile-time vs runtime
  interpolation.
- **`operator[]`** and the `nomap` / `notraverse` / `nothrow` flags are
  unchanged — they delegate to the accessors, which now resolve at runtime.
  `noescape` is moot for remote leaves (no Dart literal is emitted).

### Locale bundles

With per-instance loading the caller fetches the locale-appropriate payload and
`load`s it into the bundle they hold, so locale selection is the caller's
concern (which file/bundle they construct + which payload they fetch). Remote
**locale-variant files** (`x_cs.i69n.yaml` with the `remote` flag) are out of
scope here: a locale subclass `extends` the default class across files and
cannot reach its private `_data`/`_messages`, which the per-instance model
relies on. The supported path is a single `remote` default file per bundle.

## Error / fallback semantics

- Missing at every layer (remote, baked) → the accessor returns the **key
  string**. Never throws (matches the current non-nothrow `default: return key`).
- Malformed template (bad `${...}`) → `interpret` throws `FormatException`.
- Plurals resolve through the existing `registerResolver` CLDR machinery; no
  change to plural rule resolution.

## Testing strategy

1. **Interpreter units** — plain text; `$id`; `${id}`; each of
   `_plural`/`_ordinal`/`_cardinal`; nested `${...}` inside an arg template;
   escaped `\'`; comma inside an arg string; missing arg → empty; malformed
   template → throws.
2. **Flatten / tr units** — nested → dotted flatten; `_i69n*` ignored;
   non-string leaf stringified; `tr` chain (data wins → baked → key) + arg
   interpolation + plural.
3. **Codegen golden** — a `remote`-flagged fixture → expected generated Dart
   (`_baked` map + non-const root with `_data`/`load`/`_messages` +
   `tr`-backed accessors + correct `$`-escaping).
4. **End-to-end** — construct a remote bundle, `load` an overriding map, assert:
   loaded value wins; omitted key falls back to baked; plural resolves per
   locale; nested `load` reaches sub-bundles; separate instances are
   independent; unknown key returns the key string.
5. **Backward compatibility** — existing non-`remote` goldens
   (`parsing_test`, `example_parity_test`) must stay byte-identical.

## Out of scope (YAGNI)

- HTTP / fetching — caller's responsibility.
- YAML decoding in the runtime lib — caller decodes; `load` takes a `Map`.
- Hot-reload notifications / listeners — `load` mutates the store; rebuild is the
  app's concern.
- Caching parsed templates — possible later optimization, not required for
  correctness.
- Message-to-message references (e.g. `${_otherMessage(x)}` calling a sibling
  message method). The interpreter supports only `$ident` / `${ident}` and the
  three grammatical calls `_plural` / `_ordinal` / `_cardinal`. A `remote` file
  must not use cross-message references; an unknown function name in a template
  raises a `FormatException`. Remote payloads use plain text (YAML/JSON native
  escaping), not Dart-literal escaping.
