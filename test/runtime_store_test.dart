import 'package:i69n/i69n.dart' as i69n;
import 'package:test/test.dart';

void main() {
  group('load + tr', () {
    test('tr returns a loaded top-level value', () {
      i69n.load('aa', {'title': 'Welcome'});
      expect(i69n.tr('aa', 'aa', 'title', {}, {}), 'Welcome');
    });

    test('load flattens nested maps to dotted keys', () {
      i69n.load('bb', {
        'home': {'subtitle': 'Home'}
      });
      expect(i69n.tr('bb', 'bb', 'home.subtitle', {}, {}), 'Home');
    });

    test('tr falls back to baked when key absent from store', () {
      i69n.load('cc', {'a': 'remoteA'});
      expect(i69n.tr('cc', 'cc', 'b', {}, {'b': 'bakedB'}), 'bakedB');
    });

    test('remote value wins over baked', () {
      i69n.load('dd', {'a': 'remoteA'});
      expect(i69n.tr('dd', 'dd', 'a', {}, {'a': 'bakedA'}), 'remoteA');
    });

    test('tr falls back to the key string when nothing matches', () {
      expect(i69n.tr('ee', 'ee', 'missing', {}, {}), 'missing');
    });

    test('localeName falls back to languageCode', () {
      i69n.load('en', {'x': 'fromEn'});
      expect(i69n.tr('en_GB', 'en', 'x', {}, {}), 'fromEn');
    });

    test('_i69n config keys are ignored on load', () {
      i69n.load('ff', {'_i69n': 'remote', '_i69n_language': 'ff', 'msg': 'M'});
      expect(i69n.tr('ff', 'ff', 'msg', {}, {}), 'M');
      expect(i69n.tr('ff', 'ff', '_i69n', {}, {}), '_i69n'); // not stored -> key fallback
    });

    test('re-loading a locale replaces its slice', () {
      i69n.load('gg', {'a': '1'});
      i69n.load('gg', {'c': '2'});
      expect(i69n.tr('gg', 'gg', 'c', {}, {}), '2');
      expect(i69n.tr('gg', 'gg', 'a', {}, {}), 'a'); // gone -> key fallback
    });

    test('tr interpolates args through the interpreter', () {
      i69n.load('hh', {'greeting': r'Hi $name'});
      expect(i69n.tr('hh', 'hh', 'greeting', {'name': 'Sam'}, {}), 'Hi Sam');
    });
  });
}
