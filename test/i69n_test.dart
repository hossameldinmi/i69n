// ignore_for_file: prefer_single_quotes
import 'package:i69n/i69n.dart';
import 'package:i69n/src/utils/string_extensions.dart';
import 'package:test/test.dart';

import 'mock/gender.dart';
import 'testMessages.i69n.dart';

void main() {
  group('Plurals', () {
    test('en', () {
      expect(plural(0, 'en', zero: 'ZERO!', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('ZERO!'));
      expect(plural(0, 'en', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('OTHER!'));
      expect(plural(1, 'en', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('ONE!'));
      expect(plural(2, 'en', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('OTHER!'));
      expect(plural(3, 'en', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('OTHER!'));
      expect(plural(10, 'en', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('OTHER!'));
    });

    test('cs', () {
      expect(plural(1, 'cs', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('ONE!'));
      expect(plural(2, 'cs', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('FEW!'));
      expect(plural(3, 'cs', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('FEW!'));
      expect(plural(10, 'cs', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('OTHER!'));
    });

    test('uk', () {
      expect(plural(1, 'uk', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('ONE!'));
      expect(plural(2, 'uk', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('FEW!'));
      expect(plural(5, 'uk', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('OTHER!'));
      expect(plural(20, 'uk', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('OTHER!'));
      expect(plural(21, 'uk', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('ONE!'));
      expect(plural(22, 'uk', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('FEW!'));
      expect(plural(25, 'uk', one: 'ONE!', few: 'FEW!', other: 'OTHER!'), equals('OTHER!'));
    });
  });

  group('Select', () {
    test('enum resolves by its name', () {
      expect(select(Gender.male, {'male': 'Him', 'female': 'Her'}), equals('Him'));
      expect(select(Gender.female, {'male': 'Him', 'female': 'Her'}), equals('Her'));
    });

    test('unmatched value falls back to the other case', () {
      expect(select(Gender.unknown, {'male': 'Him', 'other': 'Them'}), equals('Them'));
    });

    test('unmatched value without an other case is empty', () {
      expect(select(Gender.unknown, {'male': 'Him', 'female': 'Her'}), equals(''));
    });

    test('a value named other prefers its own case', () {
      expect(select(Gender.other, {'other': 'Them', 'male': 'Him'}), equals('Them'));
    });

    test('non-enum values resolve by toString', () {
      expect(select('male', {'male': 'Him', 'other': 'Them'}), equals('Him'));
      expect(select(true, {'true': 'Yes', 'false': 'No'}), equals('Yes'));
      expect(select(2, {'2': 'Two', 'other': 'Many'}), equals('Two'));
    });

    test('null falls back to the other case', () {
      expect(select(null, {'male': 'Him', 'other': 'Them'}), equals('Them'));
      expect(select(null, {'male': 'Him'}), equals(''));
    });
  });

  group('Dart rendering', () {
    test('String escape', () {
      expect(escapeDartString('qwertyuiop'), equals('qwertyuiop'));
      expect(escapeDartString('1232456789'), equals('1232456789'));
      expect(escapeDartString('+ěščřžýáí'), equals('+ěščřžýáí'));
      expect(escapeDartString('ネヨフ囲人ト横執所職'), equals('ネヨフ囲人ト横執所職')); // Japanese
      expect(escapeDartString('កើតមកមានសេរីភាព'), equals('កើតមកមានសេរីភាព')); // Khmer
      expect(escapeDartString(r'$'), equals(r'$')); // does't escape dollar sign
      expect(escapeDartString(r'"'), equals(r'"')); // does't escape "
      expect(escapeDartString(r"'"), equals(r"'")); // doesn't escape '
      expect(escapeDartString(r"\"), equals(r"\")); // doesn't escape \
      expect(escapeDartString("\t"), equals(r"\t")); // does escape tab
      expect(escapeDartString("\n"), equals(r"\n")); // does escape \n
      expect(escapeDartString("""Multiline
message"""), equals(r"Multiline\nmessage")); // handles multiline strings
      expect(
          escapeDartString(
              r"XX${_plural(count, zero: 'didn\'t find any tasks', one: 'found 1 task', other: 'found $count tasks')}YY"),
          equals(
              r"XX${_plural(count, zero: 'didn\'t find any tasks', one: 'found 1 task', other: 'found $count tasks')}YY")); // doesn't escape inside ${...}
      expect(escapeDartString('👋👋👋'), equals('👋👋👋'));
      expect(escapeDartString('Hello 👋 name'), equals('Hello 👋 name'));
    });

    test('e2e test', () {
      var m = TestMessages();
      expect(m.apples.problematic(0), equals("didn't find any tasks"));
      expect(m.apples.problematic(1), equals("found 1 task"));
      expect(m.apples.problematic(2), equals("found 2 tasks"));
      expect(m.apples.problematic(3), equals("found 3 tasks"));
      expect(m.apples.quotes, equals('Hello "world"!'));
      expect(m.apples.quotes2, equals('Hello "world"!'));
      expect(m.person.sees(Gender.male), equals('I see Him'));
      expect(m.person.sees(Gender.female), equals('I see Her'));
      expect(m.person.sees(Gender.unknown), equals('I see Them'));
      expect(m.person.owns(Gender.male, 2), equals('his 2 apples'));
      expect(m.person.owns(Gender.other, 1), equals('their 1 apple'));
      expect(m.person.status(true), equals('Online'));
      expect(m.person.status(false), equals('Offline'));
    });
  });
}
