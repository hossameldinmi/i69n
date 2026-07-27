import 'package:test/test.dart';
import 'mock/remoteMessages.i69n.dart';
import 'mock/remoteMessages_cs.i69n.dart';

void main() {
  group('remote bundle end-to-end', () {
    test('baked defaults resolve before any load', () {
      final m = RemoteMessages();
      expect(m.title, 'Welcome');
      expect(m.greeting('Sam'), 'Hi Sam');
      expect(m.apples(1), '1 apple');
      expect(m.apples(3), '3 apples');
      expect(m.home.subtitle, 'Home');
    });

    test('a loaded value overrides the baked default', () {
      final m = RemoteMessages();
      m.load({'title': 'Greetings'});
      expect(m.title, 'Greetings');
      // A key the payload omits still falls back to baked:
      expect(m.greeting('Sam'), 'Hi Sam');
    });

    test('a loaded plural template is interpreted per locale', () {
      final m = RemoteMessages();
      m.load({
        'apples': r"${_plural(count, one: '$count fruit', other: '$count fruits')}",
      });
      expect(m.apples(1), '1 fruit');
      expect(m.apples(2), '2 fruits');
    });

    test('a loaded plural with no usable branch falls back to baked', () {
      final m = RemoteMessages();
      m.load({
        'apples': r"${_plural(count, two: 'a pair')}",
      });
      // The remote template only covers `two`; for count=3 nothing resolves.
      // The user must see the baked default, never the ??? sentinel.
      expect(m.apples(3), '3 apples');
    });

    test('load reaches nested bundles and operator[] traverses', () {
      final m = RemoteMessages();
      m.load({
        'home': {'subtitle': 'Domov'}
      });
      expect(m.home.subtitle, 'Domov');
      expect(m['home.subtitle'], 'Domov');
      expect(m['nope'], 'nope'); // unknown key -> key string
    });

    test('a locale bundle resolves its own baked defaults with its own locale', () {
      final m = RemoteMessages_cs();
      expect(m.apples(1), '1 jablko');
      expect(m.apples(2), '2 jablka'); // few — Czech rules, not English
      expect(m.home.subtitle, 'Domov');
      expect(m.title, 'Welcome'); // not in the cs file — inherited baked default
    });

    test('a payload loaded into a locale bundle reaches inherited keys', () {
      final m = RemoteMessages_cs();
      m.load({'title': 'Vítejte'});
      // `title` is not declared in the cs file, so its getter is inherited from
      // the default class — the loaded value must still win over baked.
      expect(m.title, 'Vítejte');
    });

    test('a payload loaded into a locale bundle reaches its own and nested keys', () {
      final m = RemoteMessages_cs();
      m.load({
        'apples': r'$count kusů',
        'home': {'subtitle': 'Doma'},
      });
      expect(m.apples(5), '5 kusů');
      expect(m.home.subtitle, 'Doma');
    });

    test('separate instances hold independent data', () {
      final a = RemoteMessages()..load({'title': 'A'});
      final b = RemoteMessages()..load({'title': 'B'});
      expect(a.title, 'A');
      expect(b.title, 'B');
    });
  });
}
