# Enum select (`_select`) — design

Date: 2026-07-27
Status: implemented (see CHANGELOG 3.8.0)
Branch: `feature/enum-select` (based on `feature/jsonc-support`)

## Problem

Messages often branch on a value that is not a count: grammatical gender, account
type, delivery state. i69n can already take a typed parameter
(`see_one(Gender gender)`) and can already brand a class with a custom type via
`_i69n_import`, but there is no way to pick a different text per enum value. The
only current workaround is one message per value plus a `switch` in application
code, which moves translation decisions out of the translation file.

`_plural` / `_ordinal` / `_cardinal` solve exactly this shape for numbers. This
feature adds the same shape for enums: a fourth helper, `_select`.

## Authoring syntax

```yaml
_i69n_import: package:my_app/gender.dart

person:
  see_one(Gender gender): "I see ${_select(gender, male: 'Him', female: 'Her')}"
  greet(Gender gender, String name): "${_select(gender, male: 'Mr.', female: 'Ms.', other: 'Mx.')} $name"
```

```dart
m.person.see_one(Gender.male);        // "I see Him"
m.person.greet(Gender.female, 'Eva'); // "Ms. Eva"
```

Rules:

- The first argument is the parameter to branch on.
- Every other argument is `<enum value name>: '<text>'`, single-quoted, matching
  the existing `_plural` convention.
- Case texts may themselves interpolate parameters (`male: 'his $count apples'`)
  and may nest other helpers.
- `other:` is the fallback for any value with no case of its own.
- No matching case and no `other:` renders the empty string. It never throws at
  runtime, so a partially translated locale file cannot crash the app.
- An enum value literally named `other` matches its own case first; because the
  fallback lookup is the same key, the result is identical either way.

## Runtime helper

Added to `lib/i69n.dart`, next to `plural` / `ordinal` / `cardinal`:

```dart
/// Picks the case matching [value] out of [cases]. An [Enum] resolves by its
/// `.name`, any other value by `toString()`. Falls back to the `other` case,
/// then to the empty string.
String select(Object? value, Map<String, String> cases) {
  final key = value is Enum ? value.name : (value?.toString() ?? '');
  return cases[key] ?? cases['other'] ?? '';
}
```

The parameter is `Object?` rather than `Enum`: it costs nothing, lets a message
branch on a `String` or `bool` parameter too, and is the only signature that
also works for the remote path, where payload arguments are untyped. The feature
is documented as the enum feature; other types are a side effect, not a headline.

`select` takes no language code — unlike the grammatical helpers, no CLDR rule is
involved.

## Build-time codegen

### Why a rewrite is needed

`_plural`'s named arguments are a fixed CLDR set (`zero`, `one`, ... `other`), so
the message text is emitted verbatim into the generated Dart string and resolves
against a file-level helper with those exact named parameters. `_select`'s
argument names are arbitrary enum values, and Dart has no arbitrary named
arguments — so the call cannot pass through unchanged. The build rewrites it into
a map literal.

### The rewrite

New `lib/src/utils/select_rewriter.dart`, applied to a message template after
escaping and before it is wrapped in the generated string literal:

```
message text:  "I see ${_select(gender, male: 'Him', female: 'Her')}"
generated:     String see_one(Gender gender) =>
                   "I see ${_select(gender, {'male': 'Him', 'female': 'Her'})}";
```

Algorithm — scan the template for `_select(`; match the closing paren while
skipping single-quoted regions and their backslash escapes (the same rules
`interpreter.dart`'s `_matchBrace` / `_splitArgs` already use); split the
argument list on top-level commas; the first part is the value expression, each
remaining part is split on its first colon into a case name and its quoted text.
Emit `_select(<expr>, {'<name>': <text>, ...})`. The map literal is not `const`,
because case texts may interpolate parameters.

Malformed input — unterminated paren, an argument with no colon, a case with no
name, a duplicate case name, a call with no cases at all — throws an `Exception`
during the build. Failing at build time is the point: the alternative is emitting
Dart that does not compile, with an error message that points at generated code
instead of at the translation file.

Case texts are copied through verbatim, so a case may hold a call to another
message (`male: _his(cnt)`) just as `_plural` cases can. Nesting a `_select`
inside another `_select`'s case text is not supported — the scanner tracks quoted
regions flatly, the same limitation the runtime interpreter already has for
`_plural`.

### Helper emission

`Node.hasSelectNode` reports whether a subtree contains a `_select(` call,
detected on the raw string value with a `RegExp(r'_select\(')` — deliberately
independent of the `NodeValue` subtype, so a single message may contain both
`_plural` and `_select`. `FileNode` exposes it the same way it exposes
`hasPluralNode`, and emits the file-level helper when `hasSelectNode && !remote`,
alongside the existing three:

```dart
String _select(Object? value, Map<String, String> cases) => i69n.select(value, cases);
```

## Remote parity

Remote bundles bake the original template text and interpret it at runtime, so
the baked entry keeps the authored named-argument form — the rewrite applies only
to the literal-emission path, exactly as `_plural` does today.

`_evalExpr` in `lib/src/runtime/interpreter.dart` gains a `_select` branch:

- the first argument names a key in `args`; its value resolves via `.name` for an
  `Enum`, otherwise `toString()` (an absent argument resolves to the empty string,
  matching `_lookup`'s existing behaviour for missing identifiers);
- the remaining parts are parsed by the existing named-argument loop, each case
  text unquoted and interpreted recursively so nested interpolation works;
- the result is `cases[key] ?? cases['other'] ?? ''`.

Unlike `_plural`, `_select` does not require its argument to be of a particular
type, so the branch has no type check to throw on.

## Testing

- Codegen (`test/parsing_test.dart`, `test/build_test.dart`): rewrite output for a
  plain call, a call whose case text interpolates a parameter, a message holding
  both `_plural` and `_select`, and a message where the branch is the whole value.
- Rewriter unit tests: commas and colons inside quoted case texts, escaped quotes,
  two `_select` calls in one template, and each malformed form throwing.
- Runtime (`test/i69n_test.dart`): `select` with an enum, a string, a missing case
  with and without `other:`, and a null value.
- Interpreter (`test/interpreter_test.dart`): the same matrix through a template.
- Remote (`test/remote_codegen_test.dart`, `test/remote_e2e_test.dart`): a `_select`
  message baked, loaded from a payload, and overridden by a payload.
- Fixtures: `test/mock/testMessages.i69n.{yaml,json,jsonc}` gain a `_select`
  message, keeping the shared parsing tests in step.

## Documentation

- README: a `_select` section after "Parameters and pluralization", covering the
  syntax, `other:`, the empty-string fallback, and the `_i69n_import` needed for
  the enum type; a line in the remote section noting parity.
- `example/yaml|json|jsonc/exampleMessages*`: a `_select` message plus the enum it
  needs, mirrored across all three formats — `test/example_parity_test.dart`
  requires the mirrors to match — and regenerated `.i69n.dart` output.
- CHANGELOG: new `3.8.0` entry; `pubspec.yaml` version bump to `3.8.0`.

## Out of scope

- Compile-time exhaustiveness checking against the real enum. The builder never
  reads the user's Dart source, so it cannot know an enum's values; a missing case
  degrades to `other:` or the empty string.
- Branching on anything other than a single value (no ranges, no boolean
  expressions, no nesting of select keys).
- A `select` variant that throws on an unmatched value.
