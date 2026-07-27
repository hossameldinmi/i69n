import 'package:i69n/src/utils/select_rewriter.dart';
import 'package:test/test.dart';

void main() {
  group('rewriteSelectCalls', () {
    test('a template without a call is unchanged', () {
      expect(rewriteSelectCalls('I see nobody'), 'I see nobody');
      expect(
        rewriteSelectCalls(r"${_plural(cnt, one: 'apple', other: 'apples')}"),
        r"${_plural(cnt, one: 'apple', other: 'apples')}",
      );
    });

    test('named cases become a map literal', () {
      expect(
        rewriteSelectCalls(r"I see ${_select(gender, male: 'Him', female: 'Her')}"),
        r"I see ${_select(gender, {'male': 'Him', 'female': 'Her'})}",
      );
    });

    test('surrounding text is preserved', () {
      expect(
        rewriteSelectCalls(r"${_select(g, male: 'Mr.', other: 'Mx.')} $name, hello"),
        r"${_select(g, {'male': 'Mr.', 'other': 'Mx.'})} $name, hello",
      );
    });

    test('interpolation inside a case text survives', () {
      expect(
        rewriteSelectCalls(r"${_select(gender, male: 'his $count apples', female: 'her $count apples')}"),
        r"${_select(gender, {'male': 'his $count apples', 'female': 'her $count apples'})}",
      );
    });

    test('commas and colons inside a case text are not argument separators', () {
      expect(
        rewriteSelectCalls(r"${_select(g, male: 'one, two: three', other: 'none')}"),
        r"${_select(g, {'male': 'one, two: three', 'other': 'none'})}",
      );
    });

    test('an escaped quote inside a case text is not the end of the text', () {
      expect(
        rewriteSelectCalls(r"${_select(g, male: 'it\'s his', other: 'theirs')}"),
        r"${_select(g, {'male': 'it\'s his', 'other': 'theirs'})}",
      );
    });

    test('a case value may be another message call', () {
      expect(
        rewriteSelectCalls(r"${_select(g, male: _his(count), other: _theirs(count))}"),
        r"${_select(g, {'male': _his(count), 'other': _theirs(count)})}",
      );
    });

    test('two calls in one template are both rewritten', () {
      expect(
        rewriteSelectCalls(r"${_select(a, x: 'X')} and ${_select(b, y: 'Y')}"),
        r"${_select(a, {'x': 'X'})} and ${_select(b, {'y': 'Y'})}",
      );
    });

    test('an identifier merely ending in _select is left alone', () {
      expect(rewriteSelectCalls(r"${my_select(g, male: 'Him')}"), r"${my_select(g, male: 'Him')}");
    });

    test('extra whitespace is normalised', () {
      expect(
        rewriteSelectCalls("\${_select( gender ,  male :  'Him' )}"),
        r"${_select(gender, {'male': 'Him'})}",
      );
    });

    test('an unterminated call throws', () {
      expect(
        () => rewriteSelectCalls(r"${_select(gender, male: 'Him'"),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('unterminated'))),
      );
    });

    test('a case without a colon throws', () {
      expect(
        () => rewriteSelectCalls(r"${_select(gender, 'Him')}"),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains("'Him'"))),
      );
    });

    test('a duplicate case name throws', () {
      expect(
        () => rewriteSelectCalls(r"${_select(gender, male: 'Him', male: 'He')}"),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('male'))),
      );
    });

    test('a call without cases throws', () {
      expect(
        () => rewriteSelectCalls(r'${_select(gender)}'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('at least one case'))),
      );
    });

    test('an empty case name throws', () {
      expect(
        () => rewriteSelectCalls(r"${_select(gender, : 'Him')}"),
        throwsA(isA<Exception>()),
      );
    });
  });
}
