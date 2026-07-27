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

    test('skips null leaves so the baked default wins', () {
      final flat = i69n.flattenMessages({'title': null, 'msg': 'M'});
      expect(flat, {'msg': 'M'});
      // End to end: the null leaf must not shadow the baked template.
      expect(i69n.tr(flat, {'title': 'Welcome'}, 'title', {}, 'en'), 'Welcome');
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

  group('tr resilience (untrusted remote data must not crash the caller)', () {
    test('a malformed remote value falls back to the baked default', () {
      // Remote overrides `title` with garbage; tr must degrade to baked, not throw.
      expect(i69n.tr({'title': r'${oops'}, {'title': 'Welcome'}, 'title', {}, 'en'), 'Welcome');
      expect(i69n.tr({'title': r'${_bogus()}'}, {'title': 'Welcome'}, 'title', {}, 'en'), 'Welcome');
    });

    test('a remote plural referencing an unpassed arg falls back to baked', () {
      // The getter passes no `x`; without a fallback this throws on every render.
      expect(i69n.tr({'label': r'${_plural(x)}'}, {'label': 'Label'}, 'label', {}, 'en'), 'Label');
    });

    test('when both remote and baked are malformed, tr returns the key', () {
      expect(i69n.tr({'k': r'${oops'}, {'k': r'${also_bad'}, 'k', {}, 'en'), 'k');
    });
  });
}
