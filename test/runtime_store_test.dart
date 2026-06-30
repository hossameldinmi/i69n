import 'package:i69n/i69n.dart' as i69n;
import 'package:test/test.dart';

void main() {
  group('flattenMessages', () {
    test('flattens nested maps to dotted keys', () {
      final flat = i69n.flattenMessages({
        'title': 'Welcome',
        'home': {'subtitle': 'Home'}
      });
      expect(flat, {'title': 'Welcome', 'home.subtitle': 'Home'});
    });

    test('ignores _i69n config keys', () {
      final flat = i69n.flattenMessages({'_i69n': 'remote', '_i69n_language': 'en', 'msg': 'M'});
      expect(flat, {'msg': 'M'});
    });

    test('stringifies non-string leaf values', () {
      final flat = i69n.flattenMessages({'n': 3});
      expect(flat, {'n': '3'});
    });
  });

  group('tr', () {
    test('a loaded value wins over baked', () {
      expect(i69n.tr({'a': 'loadedA'}, {'a': 'bakedA'}, 'a', {}, 'en'), 'loadedA');
    });

    test('falls back to baked when key absent from data', () {
      expect(i69n.tr({}, {'b': 'bakedB'}, 'b', {}, 'en'), 'bakedB');
    });

    test('falls back to the key string when nothing matches', () {
      expect(i69n.tr({}, {}, 'missing', {}, 'en'), 'missing');
    });

    test('interpolates args through the interpreter', () {
      expect(i69n.tr({}, {'greeting': r'Hi $name'}, 'greeting', {'name': 'Sam'}, 'en'), 'Hi Sam');
    });

    test('resolves a plural template against the language code', () {
      const tpl = r"${_plural(count, one: '$count apple', other: '$count apples')}";
      expect(i69n.tr({}, {'apples': tpl}, 'apples', {'count': 1}, 'en'), '1 apple');
      expect(i69n.tr({}, {'apples': tpl}, 'apples', {'count': 3}, 'en'), '3 apples');
    });
  });
}
