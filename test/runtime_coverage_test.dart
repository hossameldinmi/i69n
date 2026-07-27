import 'package:i69n/i69n.dart';
import 'package:i69n/src/utils/string_extensions.dart';
import 'package:test/test.dart';

/// Direct unit tests for runtime helpers and escapers that the codegen/e2e
/// tests only exercise indirectly (or not at all).
void main() {
  group('grammatical helpers', () {
    test('cardinal resolves like plural (cardinal rules)', () {
      expect(cardinal(1, 'en', one: 'a', other: 'b'), 'a');
      expect(cardinal(5, 'en', one: 'a', other: 'b'), 'b');
    });

    test('ordinal uses ordinal rules (uk: mod10==3, mod100!=13 -> few)', () {
      expect(ordinal(3, 'uk', few: 'F', other: 'O'), 'F');
      expect(ordinal(13, 'uk', few: 'F', other: 'O'), 'O'); // mod100==13
      expect(ordinal(23, 'uk', few: 'F', other: 'O'), 'F');
    });

    test('ordinal (cs: count==0 -> zero)', () {
      expect(ordinal(0, 'cs', zero: 'Z', other: 'O'), 'Z');
      expect(ordinal(5, 'cs', zero: 'Z', other: 'O'), 'O');
    });
  });

  test('registerResolver overrides plural rules for a locale', () {
    registerResolver('zz', (count, type) => count == 7 ? QuantityCategory.one : QuantityCategory.other);
    expect(plural(7, 'zz', one: 'ONE', other: 'OTHER'), 'ONE');
    expect(plural(2, 'zz', one: 'ONE', other: 'OTHER'), 'OTHER');
  });

  group('escapeTemplate (remote-path escaper)', () {
    test('escapes backslash, quote, dollar and control chars', () {
      expect(escapeTemplate(r'a\b'), r'a\\b');
      expect(escapeTemplate('a"b'), r'a\"b');
      expect(escapeTemplate(r'a$b'), r'a\$b');
      expect(escapeTemplate('a\tb'), r'a\tb');
      expect(escapeTemplate('a\nb'), r'a\nb');
      expect(escapeTemplate('a\rb'), r'a\rb');
    });

    test('passes ordinary text and surrogate pairs through', () {
      expect(escapeTemplate('plain'), 'plain');
      expect(escapeTemplate('👋'), '👋');
    });
  });

  group('escapeJsonDartString branches', () {
    test('control chars inside an interpolation are escaped', () {
      // The tab is inside ${...}, which is copied verbatim except control chars.
      expect(escapeJsonDartString('x \${a\tb}'), r'x ${a\tb}');
      expect(escapeJsonDartString('x \${a\nb}'), r'x ${a\nb}');
      expect(escapeJsonDartString('x \${a\rb}'), r'x ${a\rb}');
    });

    test('an unterminated interpolation brace makes the dollar literal', () {
      expect(escapeJsonDartString(r'a ${ b'), r'a \${ b');
    });
  });
}
