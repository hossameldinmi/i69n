import 'package:i69n/i69n.dart' as i69n;
import 'package:test/test.dart';
import 'mock/remoteMessages.i69n.dart';

void main() {
  group('remote bundle end-to-end', () {
    const m = RemoteMessages();
    test('baked defaults resolve before any load', () {
      expect(m.title, 'Welcome');
      expect(m.greeting('Sam'), 'Hi Sam');
      expect(m.apples(1), '1 apple');
      expect(m.apples(3), '3 apples');
      expect(m.home.subtitle, 'Home');
    });

    test('a loaded remote value overrides the baked default', () {
      i69n.load('en', {'title': 'Greetings'});
      expect(m.title, 'Greetings');
      // A key the remote payload omits still falls back to baked:
      expect(m.greeting('Sam'), 'Hi Sam');
    });

    test('a remote plural template is interpreted per locale', () {
      i69n.load('en', {
        'apples': r"${_plural(count, one: '$count fruit', other: '$count fruits')}",
      });
      expect(m.apples(1), '1 fruit');
      expect(m.apples(2), '2 fruits');
    });

    test('operator[] traverses to a nested remote value', () {
      i69n.load('en', {
        'home': {'subtitle': 'Domov'}
      });
      expect(m['home.subtitle'], 'Domov');
      expect(m['nope'], 'nope'); // unknown key -> key string
    });
  });
}
