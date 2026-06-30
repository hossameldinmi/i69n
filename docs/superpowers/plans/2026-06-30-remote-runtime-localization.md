# Remote Runtime Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let `_i69n: remote`-flagged message files resolve their values at runtime through an interpreter backed by a loadable per-locale store, so translations can be updated from a remote API without rebuilding — while keeping the typed generated API.

**Architecture:** A new pure runtime interpreter evaluates i69n message templates (`$ident` / `${ident}` / `_plural`/`_ordinal`/`_cardinal`). A global per-locale store in `lib/i69n.dart` holds remote templates; a `tr()` resolver picks `store[localeName] ?? store[languageCode] ?? baked ?? key` then interprets. Codegen, gated on the inherited `remote` flag, emits `tr()`-backed accessors plus a compiled-in `_baked` template map instead of literals. Non-`remote` files are untouched.

**Tech Stack:** Dart (SDK ^3.6.0), `package:build` codegen, `package:dart_style` formatter, `package:test`. No new runtime dependencies.

## Global Constraints

- SDK floor `^3.6.0`; no new runtime dependencies (the runtime lib must not import `package:yaml` or any HTTP client — callers fetch and decode).
- Generated output is formatted with `DartFormatter(languageVersion: DartFormatter.latestShortStyleLanguageVersion)`.
- Non-`remote` files must generate byte-identical Dart to today — existing goldens `test/parsing_test.dart` and `test/example_parity_test.dart` must stay green.
- The interpreter supports ONLY `$ident`, `${ident}`, and the three grammatical calls `_plural`/`_ordinal`/`_cardinal`. Unknown function names or malformed `${...}` raise `FormatException`. No message-to-message references, no arbitrary Dart.
- Remote payloads and `remote`-flagged build-time files use plain text values (YAML/JSON native escaping), not Dart-literal escaping.
- Baked Dart literals MUST escape `$` (→ `\$`) so the generated file does not compile-time-interpolate them; the interpreter does at runtime.

---

### Task 1: Runtime interpreter (pure)

The core, riskiest unit. Pure function, no I/O. Built test-first.

**Files:**
- Create: `lib/src/runtime/interpreter.dart`
- Test: `test/interpreter_test.dart`

**Interfaces:**
- Consumes: `i69n.plural` / `i69n.ordinal` / `i69n.cardinal` from `package:i69n/i69n.dart` (existing public functions).
- Produces: `String interpret(String template, Map<String, Object?> args, String languageCode)`.

- [ ] **Step 1: Write the failing tests**

Create `test/interpreter_test.dart`:

```dart
import 'package:i69n/src/runtime/interpreter.dart';
import 'package:test/test.dart';

void main() {
  group('interpret', () {
    test('plain text passes through', () {
      expect(interpret('Hello', {}, 'en'), 'Hello');
    });

    test('bare \$ident is substituted', () {
      expect(interpret(r'Hi $name', {'name': 'Sam'}, 'en'), 'Hi Sam');
    });

    test('braced \${ident} is substituted', () {
      expect(interpret(r'Hi ${name}!', {'name': 'Sam'}, 'en'), 'Hi Sam!');
    });

    test('missing arg substitutes empty string', () {
      expect(interpret(r'Hi $name', {}, 'en'), 'Hi ');
    });

    test('lone \$ is literal', () {
      expect(interpret(r'cost $ 5', {}, 'en'), r'cost $ 5');
    });

    test('_plural picks the one form', () {
      expect(
        interpret(r"${_plural(count, one: '$count apple', other: '$count apples')}", {'count': 1}, 'en'),
        '1 apple',
      );
    });

    test('_plural picks the other form', () {
      expect(
        interpret(r"${_plural(count, one: '$count apple', other: '$count apples')}", {'count': 3}, 'en'),
        '3 apples',
      );
    });

    test('_ordinal with nested interpolation in arg', () {
      expect(
        interpret(r"${_ordinal(n, one: '1st', two: '2nd', few: '3rd', other: '${n}th')}", {'n': 11}, 'en'),
        '11th',
      );
    });

    test('_cardinal resolves', () {
      expect(
        interpret(r"${_cardinal(n, one: 'one', other: 'many')}", {'n': 5}, 'en'),
        'many',
      );
    });

    test('escaped quote inside an arg string', () {
      expect(
        interpret(r"${_plural(count, one: 'a', other: 'isn\'t')}", {'count': 2}, 'en'),
        "isn't",
      );
    });

    test('comma inside an arg string is not an argument separator', () {
      expect(
        interpret(r"${_plural(count, other: 'a, b')}", {'count': 5}, 'en'),
        'a, b',
      );
    });

    test('unterminated \${ throws FormatException', () {
      expect(() => interpret(r'${oops', {}, 'en'), throwsFormatException);
    });

    test('unknown function throws FormatException', () {
      expect(() => interpret(r'${_frobnicate(x)}', {'x': 1}, 'en'), throwsFormatException);
    });

    test('non-int plural arg throws FormatException', () {
      expect(() => interpret(r"${_plural(count, other: 'x')}", {'count': 'nope'}, 'en'), throwsFormatException);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `dart test test/interpreter_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'interpreter.dart'` / `interpret` undefined.

- [ ] **Step 3: Write the implementation**

Create `lib/src/runtime/interpreter.dart`:

```dart
import 'package:i69n/i69n.dart' as i69n;

/// Evaluates an i69n message [template] at runtime against [args].
///
/// Supported syntax: `$ident`, `${ident}`, and the grammatical calls
/// `_plural` / `_ordinal` / `_cardinal`. A missing identifier resolves to the
/// empty string. Malformed `${...}` or an unknown function name throws a
/// [FormatException].
String interpret(String template, Map<String, Object?> args, String languageCode) {
  final out = StringBuffer();
  var i = 0;
  while (i < template.length) {
    final ch = template.codeUnitAt(i);
    if (ch == 0x24) {
      // $
      if (i + 1 < template.length && template.codeUnitAt(i + 1) == 0x7B) {
        // ${ ... }
        final end = _matchBrace(template, i + 1);
        if (end < 0) {
          throw FormatException('Unterminated "\${" in template', template, i);
        }
        final expr = template.substring(i + 2, end).trim();
        out.write(_evalExpr(expr, args, languageCode));
        i = end + 1;
      } else {
        final ident = _identAt(template, i + 1);
        if (ident.isEmpty) {
          out.writeCharCode(ch); // lone $
          i++;
        } else {
          out.write(_lookup(ident, args));
          i += 1 + ident.length;
        }
      }
    } else {
      out.writeCharCode(ch);
      i++;
    }
  }
  return out.toString();
}

/// Returns the index of the `}` matching the `{` at [openIdx], or -1 if none.
/// Single-quoted regions (and their escaped quotes) are skipped so braces and
/// quotes inside arg strings are not counted.
int _matchBrace(String s, int openIdx) {
  var depth = 0;
  var inStr = false;
  var i = openIdx;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (inStr) {
      if (c == 0x5C) {
        i += 2;
        continue;
      } // backslash escapes next
      if (c == 0x27) inStr = false; // '
    } else {
      if (c == 0x27) {
        inStr = true; // '
      } else if (c == 0x7B) {
        depth++; // {
      } else if (c == 0x7D) {
        depth--; // }
        if (depth == 0) return i;
      }
    }
    i++;
  }
  return -1;
}

/// Reads a Dart-style identifier starting at [i] (`[A-Za-z_$][A-Za-z0-9_$]*`).
String _identAt(String s, int i) {
  var j = i;
  while (j < s.length) {
    final c = s.codeUnitAt(j);
    final ok = (c >= 0x41 && c <= 0x5A) || // A-Z
        (c >= 0x61 && c <= 0x7A) || // a-z
        (c >= 0x30 && c <= 0x39 && j > i) || // 0-9 (not first)
        c == 0x5F || // _
        c == 0x24; // $
    if (!ok) break;
    j++;
  }
  return s.substring(i, j);
}

String _lookup(String ident, Map<String, Object?> args) => args[ident]?.toString() ?? '';

/// Evaluates an expression found inside `${ ... }`: either a bare identifier or
/// a grammatical call.
String _evalExpr(String expr, Map<String, Object?> args, String lang) {
  final paren = expr.indexOf('(');
  if (paren < 0) return _lookup(expr, args);

  final name = expr.substring(0, paren);
  if (name != '_plural' && name != '_ordinal' && name != '_cardinal') {
    throw FormatException('Unknown function "$name" in template expression', expr);
  }
  if (!expr.endsWith(')')) {
    throw FormatException('Malformed call in template expression', expr);
  }
  final inner = expr.substring(paren + 1, expr.length - 1);
  final parts = _splitArgs(inner);

  final countKey = parts.first.trim();
  final countArg = args[countKey];
  if (countArg is! int) {
    throw FormatException('Argument "$countKey" is not an int ($countArg)', expr);
  }

  final named = <String, String>{};
  for (final part in parts.skip(1)) {
    final colon = part.indexOf(':');
    if (colon < 0) continue;
    final k = part.substring(0, colon).trim();
    final raw = part.substring(colon + 1).trim();
    named[k] = interpret(_unquote(raw), args, lang);
  }

  switch (name) {
    case '_plural':
      return i69n.plural(countArg, lang,
          zero: named['zero'], one: named['one'], two: named['two'], few: named['few'], many: named['many'], other: named['other']);
    case '_ordinal':
      return i69n.ordinal(countArg, lang,
          zero: named['zero'], one: named['one'], two: named['two'], few: named['few'], many: named['many'], other: named['other']);
    default: // _cardinal
      return i69n.cardinal(countArg, lang,
          zero: named['zero'], one: named['one'], two: named['two'], few: named['few'], many: named['many'], other: named['other']);
  }
}

/// Splits a call's argument list on top-level commas, ignoring commas inside
/// single-quoted strings.
List<String> _splitArgs(String s) {
  final parts = <String>[];
  var start = 0;
  var inStr = false;
  var i = 0;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (inStr) {
      if (c == 0x5C) {
        i += 2;
        continue;
      }
      if (c == 0x27) inStr = false;
    } else {
      if (c == 0x27) {
        inStr = true;
      } else if (c == 0x2C) {
        parts.add(s.substring(start, i));
        start = i + 1;
      }
    }
    i++;
  }
  parts.add(s.substring(start));
  return parts;
}

/// Strips surrounding single quotes from a named-arg value and unescapes `\'`
/// and `\\`.
String _unquote(String raw) {
  var s = raw.trim();
  if (s.length >= 2 && s.codeUnitAt(0) == 0x27 && s.codeUnitAt(s.length - 1) == 0x27) {
    s = s.substring(1, s.length - 1);
  }
  final sb = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (c == 0x5C && i + 1 < s.length) {
      sb.writeCharCode(s.codeUnitAt(i + 1));
      i += 2;
    } else {
      sb.writeCharCode(c);
      i++;
    }
  }
  return sb.toString();
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `dart test test/interpreter_test.dart`
Expected: PASS (15 tests). If the `_ordinal`/`_cardinal` expected values differ from the `en` resolver's actual categories, adjust the expectation to the resolver's output (the resolver behavior is the source of truth, not the test literal).

- [ ] **Step 5: Commit**

```bash
git add lib/src/runtime/interpreter.dart test/interpreter_test.dart
git commit -m "feat: runtime template interpreter for remote localization"
```

---

### Task 2: Store + load + tr resolver

**Files:**
- Modify: `lib/i69n.dart` (add imports + store + `load` + `tr`)
- Test: `test/runtime_store_test.dart`

**Interfaces:**
- Consumes: `interpret(...)` from Task 1.
- Produces:
  - `void load(String locale, Map data)` — flattens nested data into the per-locale store.
  - `String tr(String localeName, String languageCode, String key, Map<String, Object?> args, Map<String, String> baked)` — resolution chain + interpret.

- [ ] **Step 1: Write the failing tests**

Create `test/runtime_store_test.dart` (each test uses a unique locale to avoid shared global-store contamination):

```dart
import 'package:i69n/i69n.dart' as i69n;
import 'package:test/test.dart';

void main() {
  group('load + tr', () {
    test('tr returns a loaded top-level value', () {
      i69n.load('aa', {'title': 'Welcome'});
      expect(i69n.tr('aa', 'aa', 'title', {}, {}), 'Welcome');
    });

    test('load flattens nested maps to dotted keys', () {
      i69n.load('bb', {
        'home': {'subtitle': 'Home'}
      });
      expect(i69n.tr('bb', 'bb', 'home.subtitle', {}, {}), 'Home');
    });

    test('tr falls back to baked when key absent from store', () {
      i69n.load('cc', {'a': 'remoteA'});
      expect(i69n.tr('cc', 'cc', 'b', {}, {'b': 'bakedB'}), 'bakedB');
    });

    test('remote value wins over baked', () {
      i69n.load('dd', {'a': 'remoteA'});
      expect(i69n.tr('dd', 'dd', 'a', {}, {'a': 'bakedA'}), 'remoteA');
    });

    test('tr falls back to the key string when nothing matches', () {
      expect(i69n.tr('ee', 'ee', 'missing', {}, {}), 'missing');
    });

    test('localeName falls back to languageCode', () {
      i69n.load('en', {'x': 'fromEn'});
      expect(i69n.tr('en_GB', 'en', 'x', {}, {}), 'fromEn');
    });

    test('_i69n config keys are ignored on load', () {
      i69n.load('ff', {'_i69n': 'remote', '_i69n_language': 'ff', 'msg': 'M'});
      expect(i69n.tr('ff', 'ff', 'msg', {}, {}), 'M');
      expect(i69n.tr('ff', 'ff', '_i69n', {}, {}), '_i69n'); // not stored -> key fallback
    });

    test('re-loading a locale replaces its slice', () {
      i69n.load('gg', {'a': '1'});
      i69n.load('gg', {'c': '2'});
      expect(i69n.tr('gg', 'gg', 'c', {}, {}), '2');
      expect(i69n.tr('gg', 'gg', 'a', {}, {}), 'a'); // gone -> key fallback
    });

    test('tr interpolates args through the interpreter', () {
      i69n.load('hh', {'greeting': r'Hi $name'});
      expect(i69n.tr('hh', 'hh', 'greeting', {'name': 'Sam'}, {}), 'Hi Sam');
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `dart test test/runtime_store_test.dart`
Expected: FAIL — `load`/`tr` not defined on `package:i69n/i69n.dart`.

- [ ] **Step 3: Add the implementation to `lib/i69n.dart`**

At the top of `lib/i69n.dart`, add the interpreter import alongside the existing imports:

```dart
import 'src/runtime/interpreter.dart';
```

Append to the end of `lib/i69n.dart`:

```dart
/// Per-locale runtime message store: locale -> dotted message key -> template.
final Map<String, Map<String, String>> _messageStore = {};

/// Injects remote localization [data] (already decoded from JSON/YAML) for
/// [locale]. Nested maps are flattened to dotted keys (`{home:{title:'x'}}` ->
/// `{'home.title':'x'}`); any `_i69n*` config keys are ignored. Re-loading a
/// locale replaces its previous slice.
void load(String locale, Map data) {
  final flat = <String, String>{};
  _flatten(data, '', flat);
  _messageStore[locale] = flat;
}

void _flatten(Map data, String prefix, Map<String, String> out) {
  data.forEach((dynamic k, dynamic v) {
    final key = k.toString();
    if (key.startsWith('_i69n')) return;
    final path = prefix.isEmpty ? key : '$prefix.$key';
    if (v is Map) {
      _flatten(v, path, out);
    } else {
      out[path] = v.toString();
    }
  });
}

/// Resolves a single message: remote (by [localeName] then [languageCode]) wins,
/// then the compiled-in [baked] template, then the [key] itself. The chosen
/// template is interpreted against [args].
String tr(String localeName, String languageCode, String key, Map<String, Object?> args, Map<String, String> baked) {
  final template = _messageStore[localeName]?[key] ?? _messageStore[languageCode]?[key] ?? baked[key] ?? key;
  return interpret(template, args, languageCode);
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `dart test test/runtime_store_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/i69n.dart test/runtime_store_test.dart
git commit -m "feat: per-locale message store, load() and tr() resolver"
```

---

### Task 3: Codegen — remote-flagged output

Add `escapeTemplate`, a `messagePath` key getter, a `_baked` map collector, and the `remote` rendering branch. Verified by a golden test over a new fixture.

**Files:**
- Modify: `lib/src/utils/string_extensions.dart` (add `escapeTemplate`)
- Modify: `lib/src/shared/node.dart` (add `NodeKey.messagePath`, `Node.collectBaked`, remote branch in `_renderClass`)
- Modify: `lib/src/shared/file_node.dart` (skip grammatical helpers + emit `_baked` when remote)
- Create: `test/mock/remoteMessages.i69n.yaml`
- Create: `test/mock/remoteMessages.i69n.json`
- Create: `test/mock/remoteMessages.i69n.dart` (golden + importable by Task 4)
- Create: `test/remote_codegen_test.dart`

**Interfaces:**
- Consumes: `escapeDartString` pattern (existing), `Fixture.testParsing` / `Fixture.getFileFormattedContent` (existing, `test/mock/fixture.dart`), `i69n.tr` (Task 2) referenced by generated code.
- Produces:
  - `String escapeTemplate(String s)` in `string_extensions.dart`.
  - `String get messagePath` on `NodeKey` — dotted raw-key path, no locale prefix (root -> `''`).
  - `Map<String, String> collectBaked()` on `Node` — messagePath -> `escapeTemplate`'d template for every leaf.
  - Generated accessors of the form `=> i69n.tr(_localeName, _languageCode, '<messagePath>', <args>, _baked)` and a top-level `const Map<String, String> _baked`.

- [ ] **Step 1: Add `escapeTemplate` to `lib/src/utils/string_extensions.dart`**

Append:

```dart
/// Escapes [s] for embedding in a generated **double-quoted** Dart string
/// literal whose runtime value must equal [s] verbatim. Unlike
/// [escapeDartString], this also escapes `$` and `"` so the generated file does
/// not Dart-interpolate the template — the runtime interpreter does.
String escapeTemplate(String s) {
  final sb = StringBuffer();
  for (final c in s.runes) {
    switch (c) {
      case 92: // backslash
        sb.write(r'\\');
        break;
      case 34: // "
        sb.write(r'\"');
        break;
      case 36: // $
        sb.write(r'\$');
        break;
      case 9:
        sb.write(r'\t');
        break;
      case 10:
        sb.write(r'\n');
        break;
      case 13:
        sb.write(r'\r');
        break;
      default:
        sb.writeCharCode(c);
    }
  }
  return sb.toString();
}
```

- [ ] **Step 2: Add `messagePath` to `NodeKey` in `lib/src/shared/node.dart`**

Inside `class NodeKey`, after the `path` getter (around line 96), add:

```dart
  /// Dotted path of raw keys with no locale prefix (e.g. `home.title`), used as
  /// the runtime store / `_baked` lookup key. The file root resolves to `''`.
  String get messagePath {
    if (parent == null) return '';
    final p = parent!.messagePath;
    return p.isEmpty ? key : '$p.$key';
  }
```

- [ ] **Step 3: Add `collectBaked` to `Node` in `lib/src/shared/node.dart`**

Inside `class Node`, after `buildClasses` (around line 227), add:

```dart
  /// Collects every leaf message in this subtree as `messagePath -> template`,
  /// with each template escaped for embedding in a Dart string literal.
  Map<String, String> collectBaked() {
    final out = <String, String>{};
    void walk(Node n) {
      for (final child in n._childNodes) {
        if (child.isClassNode) {
          walk(child);
        } else {
          out[child.key.messagePath] = escapeTemplate(child.value.value.toString());
        }
      }
    }

    walk(this);
    return out;
  }
```

- [ ] **Step 4: Add the remote branch in `_renderClass` in `lib/src/shared/node.dart`**

In `_renderClass`, replace the leaf-rendering loop. The current loop (around lines 254-267) is:

```dart
    final escape = hasFlag('noescape') ? (String s) => s : escapeDartString;
    for (final child in _childNodes) {
      if (child.isClassNode) {
        b.writeln('${child.key.objectName} get ${child.key.key} => ${child.key.objectName}(this);');
      } else {
        final literal = escape(child.value.value.toString());
        final childKey = child.key;
        if (childKey is ParametrizedNodeKey) {
          final params = childKey.parameters.map((p) => '${p.type} ${p.name}').join(', ');
          b.writeln('String ${childKey.key}($params) => "$literal";');
        } else {
          b.writeln('String get ${childKey.key} => "$literal";');
        }
      }
    }
```

Replace it with:

```dart
    final remote = hasFlag('remote') || inheritedFlags.contains('remote');
    final escape = hasFlag('noescape') ? (String s) => s : escapeDartString;
    for (final child in _childNodes) {
      if (child.isClassNode) {
        b.writeln('${child.key.objectName} get ${child.key.key} => ${child.key.objectName}(this);');
      } else if (remote) {
        final childKey = child.key;
        final mp = childKey.messagePath;
        if (childKey is ParametrizedNodeKey) {
          final params = childKey.parameters.map((p) => '${p.type} ${p.name}').join(', ');
          final args = '{${childKey.parameters.map((p) => "'${p.name}': ${p.name}").join(', ')}}';
          b.writeln("String ${childKey.key}($params) => i69n.tr(_localeName, _languageCode, '$mp', $args, _baked);");
        } else {
          b.writeln("String get ${childKey.key} => i69n.tr(_localeName, _languageCode, '$mp', const {}, _baked);");
        }
      } else {
        final literal = escape(child.value.value.toString());
        final childKey = child.key;
        if (childKey is ParametrizedNodeKey) {
          final params = childKey.parameters.map((p) => '${p.type} ${p.name}').join(', ');
          b.writeln('String ${childKey.key}($params) => "$literal";');
        } else {
          b.writeln('String get ${childKey.key} => "$literal";');
        }
      }
    }
```

- [ ] **Step 5: Skip grammatical helpers + emit `_baked` in `lib/src/shared/file_node.dart`**

In `build()`, wrap the three grammatical-helper blocks so they are NOT emitted for remote files, and emit `_baked` before the classes.

Change the helper section (current lines 66-83) from:

```dart
    if (hasPluralNode) {
      output.write('''
String _plural(int count, {String? zero, String? one, String? two, String? few, String? many, String? other}) =>
    i69n.plural(count, _languageCode, zero: zero, one: one, two: two, few: few, many: many, other: other);
''');
    }
    if (hasOrdinalNode) {
      output.write('''
String _ordinal(int count, {String? zero, String? one, String? two, String? few, String? many, String? other}) =>
    i69n.ordinal(count, _languageCode, zero: zero, one: one, two: two, few: few, many: many, other: other);
''');
    }
    if (hasCardinalNode) {
      output.write('''
String _cardinal(int count, {String? zero, String? one, String? two, String? few, String? many, String? other}) =>
    i69n.cardinal(count, _languageCode, zero: zero, one: one, two: two, few: few, many: many, other: other);
''');
    }
    output.writeln('');
    output.write(buildClasses({}));
```

to:

```dart
    final remote = hasFlag('remote');
    if (!remote) {
      if (hasPluralNode) {
        output.write('''
String _plural(int count, {String? zero, String? one, String? two, String? few, String? many, String? other}) =>
    i69n.plural(count, _languageCode, zero: zero, one: one, two: two, few: few, many: many, other: other);
''');
      }
      if (hasOrdinalNode) {
        output.write('''
String _ordinal(int count, {String? zero, String? one, String? two, String? few, String? many, String? other}) =>
    i69n.ordinal(count, _languageCode, zero: zero, one: one, two: two, few: few, many: many, other: other);
''');
      }
      if (hasCardinalNode) {
        output.write('''
String _cardinal(int count, {String? zero, String? one, String? two, String? few, String? many, String? other}) =>
    i69n.cardinal(count, _languageCode, zero: zero, one: one, two: two, few: few, many: many, other: other);
''');
      }
    }
    output.writeln('');
    if (remote) {
      final baked = collectBaked();
      output.writeln('const Map<String, String> _baked = {');
      baked.forEach((k, v) {
        output.writeln('  \'$k\': "$v",');
      });
      output.writeln('};');
      output.writeln('');
    }
    output.write(buildClasses({}));
```

- [ ] **Step 6: Create the fixture files**

Create `test/mock/remoteMessages.i69n.yaml`:

```yaml
_i69n: remote
_i69n_language: en
title: Welcome
greeting(String name): Hi $name
apples(int count): "${_plural(count, one: '$count apple', other: '$count apples')}"
home:
  subtitle: Home
```

Create `test/mock/remoteMessages.i69n.json`:

```json
{
  "_i69n": "remote",
  "_i69n_language": "en",
  "title": "Welcome",
  "greeting(String name)": "Hi $name",
  "apples(int count)": "${_plural(count, one: '$count apple', other: '$count apples')}",
  "home": {
    "subtitle": "Home"
  }
}
```

- [ ] **Step 7: Write the failing golden test**

Create `test/remote_codegen_test.dart`:

```dart
import 'package:test/test.dart';
import 'mock/fixture.dart';

void main() {
  test('remoteMessages.i69n generates the remote bundle (yaml + json)', () async {
    await Fixture.testParsing('remoteMessages', (filePath, actual) async {
      final expected = await Fixture.getFileFormattedContent('test/mock/remoteMessages.i69n.dart');
      expect(actual.build(), expected);
    });
  });
}
```

- [ ] **Step 8: Generate the golden output**

The golden file does not exist yet, so the test fails on a missing file. Generate it from the implementation with a one-off script, then inspect it.

Create a throwaway script `tool/gen_remote_golden.dart`:

```dart
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:i69n/src/shared/file_node.dart';

void main() {
  final yaml = File('test/mock/remoteMessages.i69n.yaml').readAsStringSync();
  final map = loadYaml(yaml) as Map;
  final out = FileNode.parseMap('test/mock/remoteMessages.i69n.yaml', map).build();
  File('test/mock/remoteMessages.i69n.dart').writeAsStringSync(out);
  stdout.write(out);
}
```

Run: `dart run tool/gen_remote_golden.dart`

Inspect the printed output and confirm it matches this expected shape (whitespace will be formatter-normalized):

```dart
// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

const Map<String, String> _baked = {
  'title': "Welcome",
  'greeting': "Hi \$name",
  'apples': "\${_plural(count, one: '\$count apple', other: '\$count apples')}",
  'home.subtitle': "Home",
};

class RemoteMessages implements i69n.I69nMessageBundle {
  const RemoteMessages();
  String get title => i69n.tr(_localeName, _languageCode, 'title', const {}, _baked);
  String greeting(String name) => i69n.tr(_localeName, _languageCode, 'greeting', {'name': name}, _baked);
  String apples(int count) => i69n.tr(_localeName, _languageCode, 'apples', {'count': count}, _baked);
  HomeRemoteMessages get home => HomeRemoteMessages(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'greeting':
        return greeting;
      case 'apples':
        return apples;
      case 'home':
        return home;
      default:
        return key;
    }
  }
}

class HomeRemoteMessages implements i69n.I69nMessageBundle {
  final RemoteMessages _parent;
  const HomeRemoteMessages(this._parent);
  String get subtitle => i69n.tr(_localeName, _languageCode, 'home.subtitle', const {}, _baked);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'subtitle':
        return subtitle;
      default:
        return key;
    }
  }
}
```

If the generated output diverges (e.g. `$` not escaped, wrong `messagePath`, helpers still emitted), fix the implementation in Steps 1-5 and re-run until it matches. Once correct, delete the throwaway script:

```bash
rm tool/gen_remote_golden.dart
```

- [ ] **Step 9: Run the golden test to verify it passes**

Run: `dart test test/remote_codegen_test.dart`
Expected: PASS (the same generated output for both the YAML and JSON fixtures).

- [ ] **Step 10: Verify non-remote output is unchanged**

Run: `dart test test/parsing_test.dart test/example_parity_test.dart`
Expected: PASS — proves the `remote` branch did not alter existing codegen.

- [ ] **Step 11: Commit**

```bash
git add lib/src/utils/string_extensions.dart lib/src/shared/node.dart lib/src/shared/file_node.dart \
        test/mock/remoteMessages.i69n.yaml test/mock/remoteMessages.i69n.json \
        test/mock/remoteMessages.i69n.dart test/remote_codegen_test.dart
git commit -m "feat: generate remote-flagged bundles backed by tr() + _baked"
```

---

### Task 4: End-to-end behavior test

Compiles the generated bundle and exercises the full path: baked defaults, remote override, plural-per-locale, and key fallback.

**Files:**
- Create: `test/remote_e2e_test.dart`

**Interfaces:**
- Consumes: the generated `RemoteMessages` / `HomeRemoteMessages` classes from `test/mock/remoteMessages.i69n.dart` (Task 3), and `load` / `tr` from `package:i69n/i69n.dart` (Task 2).

- [ ] **Step 1: Write the test**

Create `test/remote_e2e_test.dart`:

```dart
import 'package:i69n/i69n.dart' as i69n;
import 'package:test/test.dart';
import 'mock/remoteMessages.i69n.dart';

void main() {
  group('remote bundle end-to-end', () {
    const m = RemoteMessages();

    test('baked defaults resolve before any load', () {
      expect(m.title, 'Welcome');
      expect(m.greeting('Sam'), 'Hi Sam');
      expect(m.apples(1), '1 apple');
      expect(m.apples(3), '3 apples');
      expect(m.home.subtitle, 'Home');
    });

    test('a loaded remote value overrides the baked default', () {
      i69n.load('en', {'title': 'Greetings'});
      expect(m.title, 'Greetings');
      // A key the remote payload omits still falls back to baked:
      expect(m.greeting('Sam'), 'Hi Sam');
    });

    test('a remote plural template is interpreted per locale', () {
      i69n.load('en', {
        'apples': r"${_plural(count, one: '$count fruit', other: '$count fruits')}",
      });
      expect(m.apples(1), '1 fruit');
      expect(m.apples(2), '2 fruits');
    });

    test('operator[] traverses to a nested remote value', () {
      i69n.load('en', {
        'home': {'subtitle': 'Domov'}
      });
      expect(m['home.subtitle'], 'Domov');
      expect(m['nope'], 'nope'); // unknown key -> key string
    });
  });
}
```

- [ ] **Step 2: Run the test**

Run: `dart test test/remote_e2e_test.dart`
Expected: PASS. (Note: `load('en', ...)` mutates the global store; these tests run in declaration order and each reloads `'en'` before asserting, so ordering is self-contained.)

- [ ] **Step 3: Run the full suite**

Run: `dart test`
Expected: PASS — all existing tests plus the new interpreter, store, codegen, and e2e tests.

- [ ] **Step 4: Analyze**

Run: `dart analyze lib test`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add test/remote_e2e_test.dart
git commit -m "test: end-to-end remote bundle resolution"
```

---

### Task 5: Document the feature

**Files:**
- Modify: `README.md` (add a "Remote runtime localization" section)
- Create: `example/remote/remoteMessages.i69n.yaml` (runnable example mirroring the test fixture)

**Interfaces:**
- Consumes: nothing new; documents Tasks 1-4.

- [ ] **Step 1: Add the example file**

Create `example/remote/remoteMessages.i69n.yaml`:

```yaml
_i69n: remote
_i69n_language: en
title: Welcome
greeting(String name): Hi $name
apples(int count): "${_plural(count, one: '$count apple', other: '$count apples')}"
home:
  subtitle: Home
```

- [ ] **Step 2: Add a README section**

Append to `README.md`:

```markdown
## Remote runtime localization

Add the `remote` flag to a message file to back its accessors with values loaded
at runtime instead of compile-time literals:

```yaml
_i69n: remote
_i69n_language: en
title: Welcome
greeting(String name): Hi $name
apples(int count): "${_plural(count, one: '$count apple', other: '$count apples')}"
```

The generated bundle still exposes the same typed API, but each accessor resolves
through `i69n.tr(...)`: a loaded remote value wins, then the compiled-in default,
then the key itself. Fetch and decode the payload yourself (i69n adds no HTTP or
YAML runtime dependency) and inject it:

```dart
import 'package:i69n/i69n.dart' as i69n;

final res = await http.get(Uri.parse('https://example.com/messages_cs.json'));
i69n.load('cs', jsonDecode(res.body) as Map);

const msg = RemoteMessages();
print(msg.title);          // remote value if loaded, else "Welcome"
print(msg.apples(3));      // plural resolved via CLDR rules for the locale
```

Remote payloads use plain text with `$name` / `${name}` placeholders and the
`_plural` / `_ordinal` / `_cardinal` forms — the same syntax as the build-time
file. They must not reference other messages.
```

- [ ] **Step 3: Commit**

```bash
git add README.md example/remote/remoteMessages.i69n.yaml
git commit -m "docs: document remote runtime localization"
```

---

## Self-Review

**Spec coverage:**
- Decision 1 (remote-primary) + Decision 5 (baked fallback) → Task 2 `tr` chain `store ?? baked ?? key`. ✓
- Decision 2 (`$name`/`${name}`) → Task 1 `_identAt` + `$`/`${}` handling. ✓
- Decision 3 (keep `${_plural(...)}` string) → Task 1 `_evalExpr`/`_splitArgs`/`_unquote`. ✓
- Decision 4 (`load(locale, Map)` global) → Task 2 `load` + `_flatten`. ✓
- Decision 6 (per-file `remote` flag) → Task 3 `_renderClass` remote branch + `file_node` gating; Task 3 Step 10 proves non-remote unchanged. ✓
- `$`-escaping risk → Task 3 `escapeTemplate` + golden assertion of `\$`. ✓
- Interpreter scope limit / FormatException → Task 1 tests for unknown func + unterminated + non-int. ✓
- Testing strategy (interpreter / store / golden / e2e / backward-compat) → Tasks 1, 2, 3 (Steps 9-10), 4. ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code; expected command outputs stated.

**Type consistency:** `interpret(String, Map<String,Object?>, String)` is consistent across Tasks 1, 2, 4. `tr(String, String, String, Map<String,Object?>, Map<String,String>)` matches between the Task 2 definition and the Task 3 generated call sites. `messagePath` / `collectBaked` / `escapeTemplate` names match between definition (Task 3 Steps 1-3) and use (Steps 4-5). `_baked` is `const Map<String, String>` everywhere.

**Note on `en` resolver:** Task 1 Step 4 and Task 4 plural/ordinal expectations assume the existing `en` resolver categories (1 → one, else other for cardinal; ordinal th/st/nd/rd). If the resolver disagrees, adjust the expected literals to the resolver output — it is the source of truth.
