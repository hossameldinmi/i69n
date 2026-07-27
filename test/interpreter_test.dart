import 'package:i69n/src/runtime/interpreter.dart';
import 'package:test/test.dart';

import 'mock/gender.dart';

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

    test('_select picks the case matching an enum arg', () {
      expect(
        interpret(r"I see ${_select(gender, male: 'Him', female: 'Her')}", {'gender': Gender.female}, 'en'),
        'I see Her',
      );
    });

    test('_select accepts a plain string arg', () {
      expect(
        interpret(r"${_select(gender, male: 'Him', female: 'Her')}", {'gender': 'male'}, 'en'),
        'Him',
      );
    });

    test('_select falls back to the other case', () {
      expect(
        interpret(r"${_select(gender, male: 'Him', other: 'Them')}", {'gender': Gender.unknown}, 'en'),
        'Them',
      );
    });

    test('_select without a matching case renders empty', () {
      expect(
        interpret(r"${_select(gender, male: 'Him')}", {'gender': Gender.female}, 'en'),
        '',
      );
    });

    test('_select with a missing arg falls back to the other case', () {
      expect(
        interpret(r"${_select(gender, male: 'Him', other: 'Them')}", {}, 'en'),
        'Them',
      );
    });

    test('_select case text interpolates other args', () {
      expect(
        interpret(
          r"${_select(gender, male: 'his $count apples', female: 'her $count apples')}",
          {'gender': Gender.male, 'count': 3},
          'en',
        ),
        'his 3 apples',
      );
    });

    test('a colon inside an arg string is not the name separator', () {
      expect(
        interpret(r"${_select(gender, male: 'note: his', other: 'note: theirs')}", {'gender': Gender.male}, 'en'),
        'note: his',
      );
      expect(
        interpret(r"${_plural(count, other: 'ratio: 1:2')}", {'count': 5}, 'en'),
        'ratio: 1:2',
      );
    });

    test('unterminated \${ throws FormatException', () {
      expect(() => interpret(r'${oops', {}, 'en'), throwsFormatException);
    });

    test('unknown function throws FormatException', () {
      expect(() => interpret(r'${_frobnicate(x)}', {'x': 1}, 'en'), throwsFormatException);
    });

    test('a plural with no usable branch throws instead of rendering ???', () {
      // count=5 resolves to `other`, falling back through many/few — none
      // exist, only `two`. The interpreter must throw so `tr` can fall back to
      // the baked default instead of showing the ??? sentinel to the user.
      expect(
        () => interpret(r"${_plural(count, two: 'a pair')}", {'count': 5}, 'en'),
        throwsFormatException,
      );
    });

    test('a plural whose args have no colons throws instead of rendering ???', () {
      expect(
        () => interpret(r"${_plural(count, garbage)}", {'count': 5}, 'en'),
        throwsFormatException,
      );
    });

    test('non-int plural arg throws FormatException', () {
      expect(() => interpret(r"${_plural(count, other: 'x')}", {'count': 'nope'}, 'en'), throwsFormatException);
    });

    test('a malformed UNSELECTED branch does not throw (lazy evaluation)', () {
      // count=1 selects `one`; the broken `other` branch must never be evaluated.
      expect(
        interpret(r"${_plural(count, one: 'ok', other: '${oops')}", {'count': 1}, 'en'),
        'ok',
      );
    });
  });
}
