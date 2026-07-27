# JSON → Dart Code Generation (v2 `build()`)

Date: 2026-06-28
Branch: `feature/json-support`

## Problem

> **Historical snapshot.** This document records the problem as it stood before
> the pipeline shipped. The code now lives in `lib/src/shared/` (not
> `lib/src/v2/shared/`), and `Node.build()` / `FileNode.build()` are complete —
> see `test/parsing_test.dart` and `test/build_test.dart` for the current
> contract.

The v2 pipeline parses both YAML and JSON locale files into a `FileNode` tree
(`lib/src/v2/shared/`). Parsing works — `test/parsing_test.dart` verifies the
tree for both formats and passes. The remaining gap is **code generation**:
`Node.build()` / `FileNode.build()` are incomplete. They currently concatenate
raw string values (`OKDONELet's go!...`) instead of emitting Dart classes, so
the generated output does not compile and the test's `build()` assertion fails.

Goal: complete `build()` so v2 produces the same Dart output v1 produces
(`lib/src/i69n_impl.dart` is the reference), for the **default-locale** file
covered by the test contract.

## Scope

In scope:
- Recursive class generation from the `FileNode` tree.
- Full v1 parity for the default locale: nested bundle classes, `_parent`
  field, string getters, parametrized methods, plural/ordinal/cardinal helper
  calls (already emitted conditionally in the header), `operator[]` map with
  traverse, and the `noescape` / `nomap` / `notraverse` / `nothrow` /
  `implements` flags.
- Expanding the expected fixture `test/mock/testMessages.i69n.g.dart` from the
  current top-class stub to the full expected output (7 classes).

Out of scope:
- Non-default locale files (`extends DefaultObjectName`, `super(_parent)`,
  locale suffixes). The test file is default-locale only.
- Global builder options (`BuilderOptions` / global `nomap`/`notraverse`).
  v2 has no options plumbing yet; only per-node `_i69n` flags are honored.

## Reference semantics (ported from `lib/src/i69n_impl.dart`)

Reserved keys excluded from properties/map: any `ConfigNode` (key starts with
`_i69n`). This is cleaner than v1, which only reserved `_i69n`,
`_i69n_language`, `_i69n_import` and accidentally emitted other `_i69n_*` keys
(e.g. `_i69n_implements`) as getters.

### Class header
- A "class node" is any `Node` whose value is a `NodeListNodeValue`
  (the `FileNode` root included).
- Root: `class <FullKey> implements i69n.I69nMessageBundle {`
- With `_i69n_implements: X`: append `, X` to the implements list.

### Constructor
- Root (no parent): `const <FullKey>();`
- Nested: `final <ParentFullKey> _parent;` then `const <FullKey>(this._parent);`

### Properties
For each non-config child, in declaration order:
- child is a class node → `<ChildFullKey> get <key> => <ChildFullKey>(this);`
- scalar, plain key → `String get <key> => "<esc(value)>";`
- scalar, parametrized key `name(int n)` → `String name(int n) => "<esc(value)>";`
- `esc` = `escapeDartString` (escapes `\t`, `\n`, `\r`; preserves emoji /
  surrogate pairs) unless the node has its own `noescape` flag, in which case
  the value passes through unchanged.

### `operator[]`
Let `path` = `metadata.languageCode` for the root, else
`<parent.path>.<key.key>` (original key, not PascalCase).
- `nomap` && `notraverse` → single throw:
  `'[] operator is disabled in <path>, see _i69n: nomap, notraverse flag.'`
- otherwise, unless `notraverse`, emit the traverse block:
  ```dart
  var index = key.indexOf('.');
  if (index > 0) {
    return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
  }
  ```
- if `nomap` → throw `'[] operator is disabled in <path>, see _i69n: nomap flag.'`
- else → `switch (key)` with one `case '<key>': return <key>;` per non-config
  child (parameter list stripped from the key), then
  `default: return key;` — or, when `nothrow` is set on this node or any
  ancestor, `default: throw Exception('Message $key doesn\'t exist in $this');`

## Helpers (on `Node`)
- `configNodes` → children that are `ConfigNode`.
- `flags` → values of the bare `_i69n` config node (the comma list).
- `hasFlag(f)` / `flagValue(name)` → read `_i69n` / `_i69n_<name>`.
- `path` → as defined above.
- `hasInheritedFlag(f)` → own flag OR ancestor flag. Requires parent-node
  context, threaded through the `build()` recursion (the tree's `NodeKey` knows
  its parent key but not the parent `Node`).
- class name → existing `key.fullKey`.

## Output ordering
Depth-first, parent before children, children in declaration order — matching
v1's `prepareTodoList`. For the test file:
`TestMessages, GenericTestMessages, InvoiceTestMessages, ApplesTestMessages,
FriendsTestMessages, MichaelFriendsTestMessages, EvaFriendsTestMessages`.

## Approach
String-template generation (Approach A): port v1's `StringBuffer` rendering into
the recursive `build()` methods, then run the assembled source through
`DartFormatter` (already done in `FileNode.build()`). The test compares against
a `DartFormatter`-normalized fixture, so only semantic equality is required.
This drops the partial `code_builder` usage in `Node.build()`.

## Testing
`test/parsing_test.dart` is the contract. It runs both the YAML and JSON
parsers through the same assertions, so a passing `build()` proves JSON→Dart
generation. Work TDD: expand the fixture to the full expected output first,
watch it fail, then implement `build()` until green. Verify the generated
fixture compiles (`dart analyze`).
