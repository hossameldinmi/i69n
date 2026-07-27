import 'dart:convert';

import 'package:i69n/src/shared/file_node.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Focused unit tests for `build()` branches not exercised by the full-file
/// fixture in `parsing_test.dart`: cardinal helper, notraverse / nomap flags,
/// inherited nothrow, and tab/carriage-return escaping.
String build(Map<String, Object> map) => FileNode.parseMap('fooMessages.i69n.yaml', map).build();

/// Same, but through the `.json` path — JSON values escape automatically.
String buildJson(Map<String, Object> map) => FileNode.parseMap('fooMessages.i69n.json', map).build();

void main() {
  group('JSON value escaping', () {
    test('a natural JSON double quote is escaped in the generated literal', () {
      final out = buildJson({'quotes': 'Hello "world"!'});
      expect(out, contains(r'String get quotes => "Hello \"world\"!";'));
    });

    test('a natural JSON backslash is escaped in the generated literal', () {
      final out = buildJson({'path': r'C:\Users\me'});
      expect(out, contains(r'String get path => "C:\\Users\\me";'));
    });

    test(r'an authored \$ still suppresses interpolation', () {
      final out = buildJson({'price': r'cost \$5'});
      expect(out, contains(r'String get price => "cost \$5";'));
    });

    test(r'a bare $param stays raw for Dart interpolation', () {
      final out = buildJson({'greet(String name)': r'Hi $name!'});
      expect(out, contains(r'String greet(String name) => "Hi $name!";'));
    });

    test(r'a $ that starts no interpolation is escaped', () {
      // "Cost: $5" would otherwise generate a Dart syntax error.
      expect(buildJson({'price': r'Cost: $5'}), contains(r'String get price => "Cost: \$5";'));
      expect(buildJson({'pct': r'100% $'}), contains(r'String get pct => "100% \$";'));
      expect(buildJson({'sym': r'$ $ $'}), contains(r'String get sym => "\$ \$ \$";'));
    });

    test(r'a $ before an unterminated ${ is escaped', () {
      expect(buildJson({'oops': r'a ${ b'}), contains(r'String get oops => "a \${ b";'));
    });

    test(r'content inside ${...} is left untouched', () {
      final out = buildJson({
        'problematic(int count)': r"${_plural(count, zero:'didn\'t find any', other: 'found $count')}",
      });
      expect(out, contains(r"${_plural(count, zero: 'didn\'t find any', other: 'found $count')}"));
    });

    test('noescape disables JSON escaping too', () {
      final out = buildJson({
        '_i69n': 'noescape',
        'quotes': r'Hello \"world\"!',
      });
      expect(out, contains(r'String get quotes => "Hello \"world\"!";'));
    });

    test('the YAML path keeps the manual-escaping convention', () {
      // Same raw value through .yaml must NOT be auto-escaped.
      final out = build({'quotes': r'Hello \"world\"!'});
      expect(out, contains(r'String get quotes => "Hello \"world\"!";'));
    });
  });

  group('Decoded input types', () {
    test('a YamlList config value is accepted', () {
      final map = loadYaml('''
_i69n_import:
  - dart:io
  - dart:math
a: A
''') as Map;
      final out = FileNode.parseMap('fooMessages.i69n.yaml', map).build();
      expect(out, contains("import 'dart:io';"));
      expect(out, contains("import 'dart:math';"));
    });

    test('a JSON list config value is accepted', () {
      final map = json.decode('{"_i69n": ["nomap", "notraverse"], "a": "A"}') as Map;
      final out = FileNode.parseMap('fooMessages.i69n.json', map).build();
      expect(out, contains('see _i69n: nomap, notraverse flag.'));
    });

    test('a non-string scalar message value renders as text', () {
      final map = loadYaml('count: 5\nenabled: true\n') as Map;
      final out = FileNode.parseMap('fooMessages.i69n.yaml', map).build();
      expect(out, contains('String get count => "5";'));
      expect(out, contains('String get enabled => "true";'));
    });
  });

  test('emits _cardinal helper only when a cardinal node exists', () {
    final out = build({
      'pages(int n)': "\${_cardinal(n, other: '\$n')}",
    });
    expect(out, contains('i69n.cardinal('));
    expect(out, contains('String pages(int n) =>'));
    expect(out, isNot(contains('i69n.plural(')));
    expect(out, isNot(contains('i69n.ordinal(')));
  });

  test('notraverse drops the dotted-key traverse block but keeps the map switch', () {
    final out = build({
      '_i69n': 'notraverse',
      'a': 'A',
    });
    expect(out, contains("case 'a':"));
    expect(out, isNot(contains("key.indexOf('.')")));
  });

  test('nomap + notraverse together produce the combined disabled-throw', () {
    final out = build({
      '_i69n': 'nomap,notraverse',
      'a': 'A',
    });
    expect(out, contains('see _i69n: nomap, notraverse flag.'));
    expect(out, isNot(contains('switch (')));
    expect(out, isNot(contains("key.indexOf('.')")));
  });

  group('Global build.yaml options', () {
    String buildWith(Map<String, Object> map, Map<String, dynamic> config) =>
        FileNode.parseMap('fooMessages.i69n.yaml', map, globalConfig: config).build();

    test('no global config keeps the map switch and traverse block', () {
      final out = buildWith({'a': 'A'}, {});
      expect(out, contains("case 'a':"));
      expect(out, contains("key.indexOf('.')"));
    });

    test('global nomap disables the map switch', () {
      final out = buildWith({'a': 'A'}, {'nomap': true});
      expect(out, contains('see _i69n: nomap flag.'));
      expect(out, isNot(contains("case 'a':")));
    });

    test('global notraverse disables the dotted-key traverse block', () {
      final out = buildWith({'a': 'A'}, {'notraverse': true});
      expect(out, contains("case 'a':"));
      expect(out, isNot(contains("key.indexOf('.')")));
    });

    test('local map overrides global nomap', () {
      final out = buildWith({'_i69n': 'map', 'a': 'A'}, {'nomap': true});
      expect(out, contains("case 'a':"));
    });

    test('local traverse overrides global notraverse', () {
      final out = buildWith({'_i69n': 'traverse', 'a': 'A'}, {'notraverse': true});
      expect(out, contains("key.indexOf('.')"));
    });

    test('the local override is per message object, not file-wide', () {
      final out = buildWith({
        '_i69n': 'map',
        'sub': {'a': 'A'}
      }, {
        'nomap': true
      });
      // Root has the override, the nested class does not.
      expect(out, contains("case 'sub':"));
      expect(out, contains('see _i69n: nomap flag.'));
    });
  });

  test('remote declared on a nested node fails the build', () {
    // `_baked` is only emitted for file-level remote bundles, so a mid-tree
    // remote flag would generate tr(..., _baked) against a missing constant.
    expect(
      () => build({
        'sub': {'_i69n': 'remote', 'a': 'A'}
      }),
      throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('file-level'))),
    );
  });

  test('remote on the file root stays valid', () {
    final out = build({'_i69n': 'remote', 'a': 'A'});
    expect(out, contains('const Map<String, String> _baked'));
    expect(out, contains('void load(Map data)'));
  });

  test('nothrow on a parent is inherited by child classes', () {
    final out = build({
      '_i69n': 'nothrow',
      'sub': {'a': 'A'},
    });
    // Both the root class and the (non-flagged) child class must throw on miss.
    final throws = "doesn\\'t exist".allMatches(out).length;
    expect(throws, 2);
    expect(out, isNot(contains('default: return key')));
  });

  test('escapeDartString converts tab and carriage return', () {
    final out = build({
      'tabbed': 'a\tb',
      'returned': 'a\rb',
    });
    expect(out, contains(r'a\tb'));
    expect(out, contains(r'a\rb'));
  });

  test('lint_ignore flags are appended comma-separated to ignore_for_file', () {
    final out = build({
      '_i69n_lint_ignore': 'foo,bar',
      'a': 'A',
    });
    expect(out.split('\n').first, contains('prefer_single_quotes, foo, bar'));
  });

  test('unformattable output falls back to the raw source', () {
    // noescape + a raw newline yields an invalid string literal, so the
    // DartFormatter throws and build() returns the unformatted source.
    final out = build({
      '_i69n': 'noescape',
      'bad': 'line1\nline2',
    });
    expect(out, contains('line1\nline2'));
  });

  test('FileNode equality compares value, metadata, imports and lintIgnore', () {
    final a = FileNode.parseMap('fooMessages.i69n.yaml', {'a': 'A'});
    final b = FileNode.parseMap('fooMessages.i69n.yaml', {'a': 'A'});
    expect(a, equals(b));
  });
}
