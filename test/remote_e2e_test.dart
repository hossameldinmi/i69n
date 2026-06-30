import 'package:test/test.dart';
import 'mock/remoteMessages.i69n.dart';

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

    test('load reaches nested bundles and operator[] traverses', () {
      final m = RemoteMessages();
      m.load({
        'home': {'subtitle': 'Domov'}
      });
      expect(m.home.subtitle, 'Domov');
      expect(m['home.subtitle'], 'Domov');
      expect(m['nope'], 'nope'); // unknown key -> key string
    });

    test('separate instances hold independent data', () {
      final a = RemoteMessages()..load({'title': 'A'});
      final b = RemoteMessages()..load({'title': 'B'});
      expect(a.title, 'A');
      expect(b.title, 'B');
    });
  });
}
