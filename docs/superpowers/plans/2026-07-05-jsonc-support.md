# JSONC Input Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `.i69n.jsonc` (JSON with comments + trailing commas) as a third input format for the i69n code generator, producing `.i69n.dart` bundles identical to the equivalent JSON/YAML input.

**Architecture:** i69n decodes each input file into a `Map` and hands it to `FileNode.parseMap(path, map)`. Two entry points wrap that: the build_runner `Builder`s in `lib/builder.dart` (production) and the `BaseParser` implementations in `lib/src/formatters/` (tests). Add a jsonc variant to each, backed by the `jsonc` package's `jsonc.decode`. Everything downstream of the decoded `Map` is extension-agnostic and unchanged.

**Tech Stack:** Dart, `build`/`build_runner`, `jsonc` package (`jsonc.decode`), `test`.

## Global Constraints

- SDK floor: `sdk: ^3.6.0` (from `pubspec.yaml`) — every dependency must resolve under it.
- New dependency: `jsonc: ^0.0.3` in `dependencies` (not `dev_dependencies`), same tier as `yaml` — used at build time by `lib/builder.dart`.
- The `jsonc` package exports a top-level `const JsoncCodec jsonc`; import `package:jsonc/jsonc.dart` (no alias) and call `jsonc.decode(String) -> dynamic` (a `Map<String,dynamic>` for an object root). It coexists with `dart:convert`'s `json` — no name collision.
- **Do NOT touch the strict `.i69n.json` builder / `JsonParser`** — jsonc is a separate, additive path.
- **Do NOT commit** unless the human explicitly asks (project owner rule). Each task below ends with a `git add`/`git commit` step; run those ONLY if the human has opted into commits. Otherwise leave the changes staged/unstaged and stop at the test-pass step.
- Downstream types are untouched: `FileNode`, `FileNode.parseMap(String path, Map map)`, `LocaleFile`, `FileMetadata`.

---

### Task 1: Add the `jsonc` dependency

**Files:**
- Modify: `pubspec.yaml` (the `dependencies:` block)

**Interfaces:**
- Consumes: nothing.
- Produces: `package:jsonc/jsonc.dart` (top-level `jsonc` codec) available to later tasks.

- [ ] **Step 1: Add the dependency**

Run:
```bash
dart pub add jsonc
```
Expected: `+ jsonc 0.0.3` and `Changed 1 dependency!`. This inserts `jsonc: ^0.0.3` into `dependencies:` in `pubspec.yaml`.

- [ ] **Step 2: Verify it resolved under the SDK floor**

Run:
```bash
dart pub get
```
Expected: `Got dependencies!` with no version-solve error.

- [ ] **Step 3: Confirm the placement**

Run:
```bash
grep -n "jsonc" pubspec.yaml
```
Expected: a single `jsonc: ^0.0.3` line inside the `dependencies:` block (above `dev_dependencies:`). If `dart pub add` placed it elsewhere, move it into `dependencies:` manually.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml
git commit -m "build: add jsonc dependency for .i69n.jsonc support"
```

---

### Task 2: `JsoncParser` formatter

**Files:**
- Create: `lib/src/formatters/jsonc_parser.dart`
- Test: `test/jsonc_parser_test.dart`

**Interfaces:**
- Consumes: `BaseParser` (`abstract class BaseParser { Future<FileNode> parse(); }` in `lib/src/formatters/base_parser.dart`), `FileNode.parseMap(String, Map)`, `package:jsonc/jsonc.dart`.
- Produces: `class JsoncParser implements BaseParser { JsoncParser(String filePath); Future<FileNode> parse(); }` — used by Task 4 (`fixture.dart`).

- [ ] **Step 1: Write the failing test**

Create `test/jsonc_parser_test.dart`:
```dart
import 'dart:io';
import 'package:i69n/src/formatters/jsonc_parser.dart';
import 'package:test/test.dart';

void main() {
  test('JsoncParser strips // and /* */ comments and trailing commas', () async {
    final tmp = File('${Directory.systemTemp.path}/jsonc_parser_probe.i69n.jsonc');
    await tmp.writeAsString('''
{
  // a line comment
  "generic": {
    "ok": "OK", /* inline block comment */
    "done": "DONE",
  },
}
''');
    addTearDown(() => tmp.deleteSync());

    final node = await JsoncParser(tmp.path).parse();
    final out = node.build();

    expect(out, contains("String get ok => 'OK';"));
    expect(out, contains("String get done => 'DONE';"));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/jsonc_parser_test.dart -n "JsoncParser strips"`
Expected: FAIL — compile error, `Target of URI doesn't exist: 'package:i69n/src/formatters/jsonc_parser.dart'`.

- [ ] **Step 3: Write the parser**

Create `lib/src/formatters/jsonc_parser.dart`:
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
    final jsoncString = await file.readAsString();
    final jsoncMap = jsonc.decode(jsoncString) as Map;

    return FileNode.parseMap(filePath, jsoncMap);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/jsonc_parser_test.dart -n "JsoncParser strips"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/formatters/jsonc_parser.dart test/jsonc_parser_test.dart
git commit -m "feat: add JsoncParser formatter"
```

---

### Task 3: `jsoncBasedBuilder`

**Files:**
- Modify: `lib/builder.dart`
- Modify: `build.yaml`
- Test: `test/jsonc_builder_test.dart`

**Interfaces:**
- Consumes: `package:build/build.dart` (`Builder`, `BuilderOptions`, `BuildStep`), `FileNode.parseMap(String, Map)`, `package:jsonc/jsonc.dart`.
- Produces: top-level `Builder jsoncBasedBuilder(BuilderOptions options)` and `class JsoncBasedBuilder implements Builder` with `buildExtensions = {'.i69n.jsonc': ['.i69n.dart']}`.

- [ ] **Step 1: Write the failing test**

Create `test/jsonc_builder_test.dart` (mirrors how the json/yaml builders are exercised — drives the builder class directly, no build_runner harness needed). `BuilderOptions.empty` is a `const` provided by `package:build` (`static const empty = BuilderOptions({})`):
```dart
import 'package:build/build.dart';
import 'package:i69n/builder.dart';
import 'package:test/test.dart';

void main() {
  test('jsoncBasedBuilder factory yields a builder for .i69n.jsonc', () {
    final builder = jsoncBasedBuilder(BuilderOptions.empty);
    expect(builder, isA<JsoncBasedBuilder>());
    expect(builder.buildExtensions, {
      '.i69n.jsonc': ['.i69n.dart'],
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/jsonc_builder_test.dart`
Expected: FAIL — `jsoncBasedBuilder` / `JsoncBasedBuilder` are not defined in `package:i69n/builder.dart`.

- [ ] **Step 3: Add the builder to `lib/builder.dart`**

Add the import at the top of `lib/builder.dart` (it currently imports `dart:convert`, `package:build/build.dart`, `package:i69n/src/shared/file_node.dart`, `package:yaml/yaml.dart`):
```dart
import 'package:jsonc/jsonc.dart';
```

Add the factory next to `jsonBasedBuilder`:
```dart
Builder jsoncBasedBuilder(BuilderOptions options) => JsoncBasedBuilder(options);
```

Add the class after `JsonBasedBuilder`:
```dart
/// Generates Dart message bundles from `.i69n.jsonc` files
/// (JSON with comments and trailing commas).
class JsoncBasedBuilder implements Builder {
  const JsoncBasedBuilder(this.options);

  final BuilderOptions options;

  @override
  Future build(BuildStep buildStep) async {
    var inputId = buildStep.inputId;
    var contents = await buildStep.readAsString(inputId);

    var jsoncMap = jsonc.decode(contents) as Map;
    var fileNode = FileNode.parseMap(inputId.path, jsoncMap);

    var copy = inputId.changeExtension('.dart');
    await buildStep.writeAsString(copy, fileNode.build());
  }

  @override
  final buildExtensions = const {
    '.i69n.jsonc': ['.i69n.dart']
  };
}
```

- [ ] **Step 4: Register the builder in `build.yaml`**

In `build.yaml`, add under `builders:` (after `jsonBasedBuilder`):
```yaml
  jsoncBasedBuilder:
    import: "package:i69n/builder.dart"
    builder_factories: ["jsoncBasedBuilder"]
    build_extensions: {".i69n.jsonc": [".i69n.dart"]}
    build_to: source
    auto_apply: root_package
```

And add the matching `test/**` exclude under `targets: $default: builders:` (alongside the existing yaml/json excludes):
```yaml
      i69n|jsoncBasedBuilder:
        generate_for:
          exclude:
            - test/**
```

- [ ] **Step 5: Run test to verify it passes**

Run: `dart test test/jsonc_builder_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/builder.dart build.yaml test/jsonc_builder_test.dart
git commit -m "feat: add jsoncBasedBuilder for .i69n.jsonc build_runner inputs"
```

---

### Task 4: Wire jsonc into the shared fixture (full-file parity)

**Files:**
- Create: `test/mock/testMessages.i69n.jsonc`
- Modify: `test/mock/fixture.dart`

**Interfaces:**
- Consumes: `JsoncParser` (Task 2), existing `Fixture.testParsing(String fileName, Future<void> Function(String filePath, FileNode actual) test)`.
- Produces: `Fixture.testParsing` now also runs the `.i69n.jsonc` input through `JsoncParser`, so `test/parsing_test.dart` asserts jsonc yields the identical `FileNode` and byte-identical generated `.g.dart` as json/yaml — no change to `parsing_test.dart` needed.

- [ ] **Step 1: Create the jsonc fixture (copy of the json fixture, adorned with comments + a trailing comma)**

Create `test/mock/testMessages.i69n.jsonc` — same content as `test/mock/testMessages.i69n.json` but with jsonc-only syntax added so the fixture actively exercises comment/trailing-comma stripping. It MUST decode to the exact same map as the json fixture:
```jsonc
{
  // Import dart:io so the generated bundle can use it.
  "_i69n_import": "dart:io",
  "_i69n_language": "sk",
  "generic": {
    "_i69n": "flag",
    "ok": "OK",
    "done": "DONE",
    "letsGo": "Let's go!",
    "ordinalNumber(int n)": "${_ordinal(n, one: '1st', two: '2nd', few: '3rd', other: '${n}th')}"
  },
  /* Invoice-related messages.
     noescape + nomap flags exercised here. */
  "invoice": {
    "_i69n": "noescape,nomap",
    "create": "Create invoice",
    "delete": "Delete  invoice",
    "help": "Use this function to generate new invoices and stuff. Awesome!",
    "count(int cnt)": "You have created $cnt ${_plural(cnt, one:'invoice', many:'invoices')}.",
    "something": "Let\\'s go!"
  },
  "apples": {
    "_apples(int cnt)": "${_plural(cnt, zero: 'no apples', one:'$cnt apple', many:'$cnt apples')}",
    "count(int cnt)": "You have eaten ${_apples(cnt)}.",
    "problematic(int count)": "${_plural(count, zero:'didn\\'t find any tasks', one:'found 1 task', other: 'found $count tasks')}",
    "anotherProblem": "here\nthere",
    "quotes": "Hello \\\"world\\\"!",
    "quotes2": "Hello \\\"world\\\"!"
  },
  "friends": {
    "michael": {
      "name": "Aaaaa",
      "description": "Aa Aa Aa"
    },
    "eva": {
      "_i69n_implements": "MichaelFriendsTestMessages",
      "name": "Bbbbb",
      "description": "Bb Bb Bb"
    },
  },
}
```
Note the trailing commas after the `eva` object and after `friends`, plus the `//` and `/* */` comments — these are the jsonc-only features under test.

- [ ] **Step 2: Add `JsoncParser` to the fixture parser list**

In `test/mock/fixture.dart`, add the import and extend the `parsers` list. Change:
```dart
import 'package:i69n/src/formatters/json_parser.dart';
import 'package:i69n/src/formatters/yaml_parser.dart';
```
to also include:
```dart
import 'package:i69n/src/formatters/jsonc_parser.dart';
```
and change:
```dart
    final yamlPath = 'test/mock/$fileName.i69n.yaml';
    final jsonPath = 'test/mock/$fileName.i69n.json';
    final parsers = [
      (parser: YamlParser(yamlPath), filePath: yamlPath),
      (parser: JsonParser(jsonPath), filePath: jsonPath),
    ];
```
to:
```dart
    final yamlPath = 'test/mock/$fileName.i69n.yaml';
    final jsonPath = 'test/mock/$fileName.i69n.json';
    final jsoncPath = 'test/mock/$fileName.i69n.jsonc';
    final parsers = [
      (parser: YamlParser(yamlPath), filePath: yamlPath),
      (parser: JsonParser(jsonPath), filePath: jsonPath),
      (parser: JsoncParser(jsoncPath), filePath: jsoncPath),
    ];
```

- [ ] **Step 3: Run the existing parsing test to verify jsonc reaches full-file parity**

Run: `dart test test/parsing_test.dart`
Expected: PASS. The test now runs three times (yaml, json, jsonc); the jsonc run must produce the identical `FileNode` field-by-field and the same generated script as `test/mock/testMessages.i69n.g.dart`. If it fails, the jsonc fixture content diverged from the json fixture — reconcile it (comments/trailing commas aside, the decoded map must match exactly).

- [ ] **Step 4: Commit**

```bash
git add test/mock/testMessages.i69n.jsonc test/mock/fixture.dart
git commit -m "test: cover .i69n.jsonc in the shared full-file fixture"
```

---

### Task 5: `LocaleFile` extension coverage for `.jsonc`

**Files:**
- Modify: `test/locale_file_test.dart`

**Interfaces:**
- Consumes: `LocaleFile(String filePath)` with getters `fileName`, `pureFileName`, `fileExtension`, `generatedFilePath` (from `lib/src/shared/file.dart`; `fileExtension` returns `p.extension(filePath)`, `pureFileName` = `fileName.split('.i69n.').first`).
- Produces: a regression test locking `LocaleFile`'s behavior for the `.jsonc` suffix. No production change — `LocaleFile` is already extension-agnostic.

- [ ] **Step 1: Add a `.jsonc` test group**

In `test/locale_file_test.dart`, mirror the existing `testMessages.i69n.json` group with a `.jsonc` one. Add:
```dart
  test('testMessages.i69n.jsonc', () async {
    final dir = 'test/mock';
    final localeFile = LocaleFile('$dir/testMessages.i69n.jsonc');
    expect(localeFile.fileName, 'testMessages.i69n.jsonc');
    expect(localeFile.pureFileName, 'testMessages');
    expect(localeFile.fileExtension, '.jsonc');
    expect(localeFile.generatedFilePath, '$dir/testMessages.i69n.dart');
  });
```
Check the exact `dir` value and surrounding assertions already used in the file's `.json` test (around lines 17–22) and match that style; adjust the `dir` string if the existing tests use a different variable/literal.

- [ ] **Step 2: Run the test to verify it passes**

Run: `dart test test/locale_file_test.dart -n "testMessages.i69n.jsonc"`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/locale_file_test.dart
git commit -m "test: lock LocaleFile behavior for .jsonc extension"
```

---

### Task 6: `example/jsonc/` mirror + parity test

**Files:**
- Create: `example/jsonc/exampleMessages.i69n.jsonc`
- Create: `example/jsonc/exampleMessages_cs.i69n.jsonc`
- Create: `example/jsonc/exampleMessages_en_GB.i69n.jsonc`
- Create: `example/jsonc/jsonc_example.dart`
- Generated (by build_runner): `example/jsonc/exampleMessages.i69n.dart`, `example/jsonc/exampleMessages_cs.i69n.dart`, `example/jsonc/exampleMessages_en_GB.i69n.dart`
- Modify: `test/example_parity_test.dart`

**Interfaces:**
- Consumes: `jsoncBasedBuilder` (Task 3, registered in `build.yaml`), `FileNode.parseMap`, `package:jsonc/jsonc.dart`.
- Produces: an `example/jsonc/` tree mirroring `example/json/`, and a parity assertion that jsonc builds byte-identical Dart to the YAML source for every locale.

- [ ] **Step 1: Create the three jsonc source files (mirror of `example/json/`, with a showcase comment)**

Create `example/jsonc/exampleMessages.i69n.jsonc` — identical decoded content to `example/json/exampleMessages.i69n.json`, with comments added to demonstrate the feature:
```jsonc
{
  // Default (English) messages. JSONC lets us annotate translations inline.
  "generic": {
    "_i69n": "flag",
    "ok": "OK",
    "done": "DONE",
    "letsGo": "Let's go!"
  },
  "invoice": {
    "_i69n": "noescape,nomap",
    "create": "Create invoice",
    "delete": "Delete  invoice",
    "help": "Use this function to generate new invoices and stuff. Awesome!",
    "count(int cnt)": "You have created $cnt ${_plural(cnt, one:'invoice', many:'invoices')}."
  },
  "apples": {
    "_apples(int cnt)": "${_plural(cnt, zero: 'no apples', one:'$cnt apple', many:'$cnt apples')}",
    "count(int cnt)": "You have eaten ${_apples(cnt)}."
  }
}
```

Create `example/jsonc/exampleMessages_cs.i69n.jsonc` — decoded content identical to `example/json/exampleMessages_cs.i69n.json`:
```jsonc
{
  // Czech translation.
  "generic": {
    "_i69n": "flag",
    "done": "Hotovo"
  },
  "invoice": {
    "create": "Vytvořit fakturu",
    "delete": "Smazat fakturu",
    "help": "Tuhle funkci použij na vytváření faktur. Boží!",
    "count(int a)": "Už jsi vytvořil ${_plural(a, one:'fakturu', few:'faktury', many:'faktur')}."
  },
  "apples": {
    "_apples(int cnt)": "${_plural(cnt, zero: 'fakt málo jablek', one:'jedno jablko', few: '$cnt jablka', many:'$cnt jablek')}",
    "count(int cnt)": "Snědl jsi ${_apples(cnt)}."
  }
}
```

Create `example/jsonc/exampleMessages_en_GB.i69n.jsonc` — decoded content identical to `example/json/exampleMessages_en_GB.i69n.json`:
```jsonc
{
  // British English variant.
  "generic": {
    "_i69n": "flag",
    "ok": "OK",
    "done": "DONE",
    "letsGo": "Let us go!"
  },
  "invoice": {
    "_i69n": "noescape,nomap",
    "create": "Create invoice",
    "delete": "Delete  invoice",
    "help": "Use this function to generate new invoices and stuff. Awesome!",
    "count(int cnt)": "You have created $cnt ${_plural(cnt, one:'invoice', many:'invoices')} indeed."
  },
  "apples": {
    "_apples(int cnt)": "${_plural(cnt, zero: 'no apples', one:'$cnt apple', many:'$cnt apples')}",
    "count(int cnt)": "You have eaten ${_apples(cnt)}."
  }
}
```

- [ ] **Step 2: Add the runnable example driver**

Create `example/jsonc/jsonc_example.dart` by copying `example/json/json_example.dart` verbatim (its imports are relative — `exampleMessages.i69n.dart`, `exampleMessages_cs.i69n.dart` — so the same file works unchanged in the jsonc directory). Copy it exactly, changing nothing.

- [ ] **Step 3: Generate the Dart bundles**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
```
Expected: `Succeeded`. This creates `example/jsonc/exampleMessages*.i69n.dart` from the new `.i69n.jsonc` sources (the `test/**` exclude does not apply to `example/**`).

- [ ] **Step 4: Verify the generated jsonc bundles match the json ones**

Run:
```bash
diff <(sed -n '/^import/,$p' example/json/exampleMessages.i69n.dart) <(sed -n '/^import/,$p' example/jsonc/exampleMessages.i69n.dart)
```
Expected: no differences except any leading source-path comment. If the class names differ (e.g. generated class derived from filename), that is expected only if filenames differ — they do not here (both `exampleMessages`), so bodies should match. Investigate any real difference before proceeding.

- [ ] **Step 5: Extend the parity test**

In `test/example_parity_test.dart`, add a jsonc import and a jsonc-vs-yaml assertion. Change the imports to add:
```dart
import 'package:jsonc/jsonc.dart';
```
and inside the `for (final locale in ['', '_cs', '_en_GB'])` loop, add a second test:
```dart
    test('yaml and jsonc produce identical Dart for exampleMessages$locale', () {
      final yamlPath = 'example/yaml/exampleMessages$locale.i69n.yaml';
      final jsoncPath = 'example/jsonc/exampleMessages$locale.i69n.jsonc';

      final fromYaml = FileNode.parseMap(yamlPath, loadYaml(File(yamlPath).readAsStringSync()) as Map).build();
      final fromJsonc = FileNode.parseMap(jsoncPath, jsonc.decode(File(jsoncPath).readAsStringSync()) as Map).build();

      expect(fromJsonc, fromYaml);
    });
```

- [ ] **Step 6: Run the parity test**

Run: `dart test test/example_parity_test.dart`
Expected: PASS — all six tests (three yaml-vs-json, three yaml-vs-jsonc) green.

- [ ] **Step 7: Commit**

```bash
git add example/jsonc test/example_parity_test.dart
git commit -m "test: add example/jsonc mirror with yaml parity"
```

---

### Task 7: Document `.i69n.jsonc` in the README

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: user-facing docs for the new format.

- [ ] **Step 1: Add a supported-formats note**

In `README.md`, after the YAML "How to use with Flutter" example (immediately after line 87, before the "Add `build_runner`..." paragraph on line 89), insert:
```markdown
### Input formats

i69n reads three input formats, distinguished by extension:

* `.i69n.yaml` — YAML (shown above).
* `.i69n.json` — strict JSON.
* `.i69n.jsonc` — JSON with `//` line comments, `/* ... */` block comments, and
  trailing commas. Otherwise identical to `.i69n.json`. Useful for annotating
  translations inline.

All three generate the same `.i69n.dart` output; pick whichever your team prefers.
```

- [ ] **Step 2: Verify the edit reads correctly**

Run: `grep -n "i69n.jsonc" README.md`
Expected: at least one match in the new "Input formats" section.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document .i69n.jsonc input format"
```

---

### Task 8: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Run the whole test suite**

Run: `dart test`
Expected: all tests PASS, including `parsing_test.dart` (now 3x), `example_parity_test.dart` (now 6 tests), `jsonc_parser_test.dart`, `jsonc_builder_test.dart`, `locale_file_test.dart`.

- [ ] **Step 2: Analyze**

Run: `dart analyze`
Expected: `No issues found!` (or only pre-existing warnings unrelated to this change).

- [ ] **Step 3: Confirm the strict json path is untouched**

Run:
```bash
git diff --stat -- lib/src/formatters/json_parser.dart
grep -c "class JsonBasedBuilder" lib/builder.dart
```
Expected: `json_parser.dart` shows no changes at all (uncommitted diff empty — it was never edited), and `JsonBasedBuilder` still present exactly once in `builder.dart` (the jsonc builder is added alongside, not in place of it). If commits were made per-task, compare the whole feature instead with `git diff --stat master...HEAD -- lib/src/formatters/json_parser.dart` (expect empty).

---

## Notes for the executor

- If `dart test` / `dart run build_runner` is not how this repo runs tooling, check `pubspec.yaml` and any CI config — but this is a pure Dart package (no Flutter SDK in `environment`), so `dart` commands are correct.
- The `jsonc` package's `jsonc.decode` returns `dynamic`; the `as Map` cast matches the existing `json.decode(...) as Map` pattern in `builder.dart`. A non-object root fails the cast with a clear error — same behavior as the json path today.
- Do not "improve" `FileNode`, `LocaleFile`, or the interpreter — jsonc support is fully additive and stops at the decoded `Map`.
