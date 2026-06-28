import 'package:i69n/src/v2/shared/file_node.dart';
import 'package:test/test.dart';

/// Focused unit tests for `build()` branches not exercised by the full-file
/// fixture in `parsing_test.dart`: cardinal helper, notraverse / nomap flags,
/// inherited nothrow, and tab/carriage-return escaping.
String build(Map<String, Object> map) => FileNode.parseMap('fooMessages.i69n.yaml', map).build();

void main() {
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
