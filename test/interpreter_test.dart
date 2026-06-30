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
