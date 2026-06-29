import 'package:i69n/src/shared/file.dart';
import 'package:i69n/src/shared/file_metadata.dart';
import 'package:i69n/src/shared/node.dart';
import 'package:test/test.dart';

/// Covers the value/key factory edge branches: list values, non-string keys and
/// the unsupported-type guards.
void main() {
  final meta = FileMetadata(LocaleFile('fooMessages.i69n.yaml'), true, 'en', 'en');

  test('NodeValue.create builds a StringListNodeValue from a string list', () {
    final v = NodeValue.create(<String>['a', 'b'], null, meta);
    expect(v, isA<StringListNodeValue>());
    expect((v as StringListNodeValue).value, ['a', 'b']);
  });

  test('NodeValue.create throws on an unsupported value type', () {
    expect(() => NodeValue.create(42, null, meta), throwsException);
  });

  test('NodeKey.create rejects a key that is not a valid Dart identifier', () {
    expect(() => NodeKey.create(42, null, meta), throwsException);
  });

  test('NodeKey.create rejects a key containing a dot', () {
    expect(() => NodeKey.create('foo.bar', null, meta), throwsException);
  });

  test('StringListNodeValue.create throws on an unsupported value type', () {
    expect(() => StringListNodeValue.create(42), throwsException);
  });

  test('a message calling _plural( is classified as grammatical', () {
    final v = NodeValue.create("\${_plural(n, other: '\$n')}", null, meta);
    expect(v, isA<GrammaticalNumberNodeValue>());
  });

  test('a message merely containing the word "plural" stays a plain string', () {
    final v = NodeValue.create('Select the plural form', null, meta);
    expect(v, isA<StringNodeValue>());
  });
}
