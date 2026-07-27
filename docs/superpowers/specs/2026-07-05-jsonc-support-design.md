# Design: JSONC input support for i69n

**Date:** 2026-07-05
**Status:** Approved (design), pending implementation plan

## Summary

Add `.i69n.jsonc` as a third input format for the i69n code generator, alongside
the existing `.i69n.yaml` and `.i69n.json`. JSONC is JSON with `//` line
comments, `/* ... */` block comments, and trailing commas. A `.i69n.jsonc` file
generates a `.i69n.dart` message bundle identical to the equivalent JSON/YAML
input.

The existing `.i69n.json` format stays strict JSON and is left completely
unchanged.

## Motivation

Translators and developers want to annotate localization files with comments
(context for a string, TODO markers, sectioning) and tolerate trailing commas
when editing large maps. Strict JSON forbids both. Rather than loosen the
existing `.json` contract, we add a distinct opt-in extension.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Recognition | New `.i69n.jsonc` extension | Explicit opt-in; `.i69n.json` semantics unchanged |
| Syntax scope | Comments + trailing commas | Matches VS Code / tsconfig "jsonc"; the two things strict JSON lacks |
| Parser | `jsonc` pub package (`jsonc.decode`) | Exact jsonc semantics (unlike `json5`, which also allows unquoted keys / single quotes); resolves under `sdk: ^3.6.0`; no transitive deps |
| Builder | Separate `jsoncBasedBuilder` | Clean separation; strict `.json` builder untouched |
| Example dir | Add `example/jsonc/` mirror | Symmetry with existing `example/json` + `example/yaml`; demonstrates comments |

## Architecture

i69n has two parse entry points, both of which decode an input file into a
`Map` and hand it to `FileNode.parseMap(path, map)`:

1. **build_runner path** — `lib/builder.dart` defines `Builder`s keyed by input
   extension in `build.yaml`. This is the production codegen path.
2. **Formatter path** — `lib/src/formatters/*_parser.dart` implement
   `BaseParser.parse() -> Future<FileNode>`. Used by the test suite
   (`test/mock/fixture.dart`).

JSONC support is added symmetrically to both paths. Everything downstream of the
decoded `Map` (`FileNode`, `LocaleFile`, `FileMetadata`, code generation) is
already extension-agnostic and needs **no changes**.

`jsonc.decode(String)` strips comments and trailing commas, then delegates to
`dart:convert`'s `json.decode`, returning a `Map<String, dynamic>` for an object
root — the same shape `json.decode` returns, so `as Map` / `FileNode.parseMap`
consume it unchanged.

## Components

### 1. Dependency — `pubspec.yaml`
Add `jsonc: ^0.0.3` to `dependencies` (same tier as `yaml`; used at build time by
`builder.dart`). Confirmed to resolve against `sdk: ^3.6.0` with no transitive
additions.

### 2. `lib/src/formatters/jsonc_parser.dart` (new)
`JsoncParser implements BaseParser`, a mirror of `JsonParser`:
```dart
import 'dart:io';
import 'package:jsonc/jsonc.dart';
import 'package:i69n/src/formatters/base_parser.dart';
import 'package:i69n/src/shared/file_node.dart';

class JsoncParser implements BaseParser {
  final String filePath;
  JsoncParser(this.filePath);

  @override
  Future<FileNode> parse() async {
    final file = File(filePath);
    final contents = await file.readAsString();
    final map = jsonc.decode(contents) as Map;
    return FileNode.parseMap(filePath, map);
  }
}
```
The `jsonc` package exports a top-level `jsonc` codec instance (analogous to
`dart:convert`'s `json`), so a plain `import` gives `jsonc.decode`. `builder.dart`
already imports `dart:convert`'s `json`; the two coexist without collision.

### 3. `lib/builder.dart`
Add, mirroring `JsonBasedBuilder`:
```dart
Builder jsoncBasedBuilder(BuilderOptions options) => JsoncBasedBuilder(options);

/// Generates Dart message bundles from `.i69n.jsonc` files.
class JsoncBasedBuilder implements Builder {
  const JsoncBasedBuilder(this.options);
  final BuilderOptions options;

  @override
  Future build(BuildStep buildStep) async {
    var inputId = buildStep.inputId;
    var contents = await buildStep.readAsString(inputId);
    var map = jsonc.decode(contents) as Map;
    var fileNode = FileNode.parseMap(inputId.path, map);
    var copy = inputId.changeExtension('.dart');
    await buildStep.writeAsString(copy, fileNode.build());
  }

  @override
  final buildExtensions = const {
    '.i69n.jsonc': ['.i69n.dart']
  };
}
```

### 4. `build.yaml`
Register the builder and add it to the `test/**` exclude target (same collision
guard already applied to the json/yaml builders):
```yaml
  jsoncBasedBuilder:
    import: "package:i69n/builder.dart"
    builder_factories: ["jsoncBasedBuilder"]
    build_extensions: {".i69n.jsonc": [".i69n.dart"]}
    build_to: source
    auto_apply: root_package
```
```yaml
      i69n|jsoncBasedBuilder:
        generate_for:
          exclude:
            - test/**
```

## Data flow

```text
foo.i69n.jsonc
  -> (builder OR JsoncParser) reads string
  -> jsonc.decode  (strip comments + trailing commas, then json.decode)
  -> Map
  -> FileNode.parseMap(path, map)
  -> FileNode.build()
  -> foo.i69n.dart
```

## Error handling

- **Malformed jsonc** (bad syntax after comment stripping): `jsonc.decode`
  throws, surfacing through build_runner as a build error — same failure mode as
  a malformed `.json` today. No new handling required.
- **Non-object root**: `as Map` cast fails with a clear error, matching current
  json/yaml behavior.
- The runtime `tr()` remote-bundle path is unrelated and untouched; this feature
  is build-time only.

## Testing

1. **`test/mock/testMessages.i69n.jsonc` (new)** — a copy of
   `test/mock/testMessages.i69n.json` deliberately adorned with `//` and
   `/* */` comments and at least one trailing comma, so the fixture actively
   exercises jsonc-specific syntax.
2. **`test/mock/fixture.dart`** — add `JsoncParser(jsoncPath)` to the parser
   list in `Fixture.testParsing`. The existing `parsing_test.dart` then asserts
   the jsonc input produces the identical `FileNode` and byte-identical
   generated `.g.dart` as json/yaml — proving comment/trailing-comma stripping
   is transparent. No new assertions needed in `parsing_test.dart`.
3. **`test/locale_file_test.dart`** — add a `.i69n.jsonc` case asserting
   `fileExtension == '.jsonc'` and correct `pureFileName` / `generatedFilePath`
   (locks the extension-agnostic `LocaleFile` behavior for the new suffix).
4. **`example/jsonc/` (new)** — mirror of `example/json` (default + `_cs` +
   `_en_GB`), with comments added to at least the default file to showcase the
   feature, plus the committed generated `.i69n.dart` outputs.
5. **`test/example_parity_test.dart`** — extend so each locale also parses the
   `example/jsonc/exampleMessages$locale.i69n.jsonc` input and asserts it builds
   byte-identical Dart to the YAML source (`expect(fromJsonc, fromYaml)`).

## Documentation

- **`README.md`** — document `.i69n.jsonc` as a third supported input format,
  noting comment + trailing-comma support and that it is otherwise equivalent to
  `.i69n.json`.

## Out of scope (YAGNI)

- Relaxing the existing `.i69n.json` builder to accept comments.
- `json5` superset features (unquoted keys, single-quoted strings, etc.).
- Any runtime / remote-bundle changes.

## Non-obvious constraints

- `docs/` note per project owner preference: **do not auto-commit**. The
  implementation will leave changes staged/unstaged for the owner to commit
  explicitly.
