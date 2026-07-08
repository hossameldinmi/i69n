import 'package:test/test.dart';
import 'mock/fixture.dart';

void main() {
  test('remoteMessages.i69n generates the remote bundle (yaml + json + jsonc)', () async {
    await Fixture.testParsing('remoteMessages', (filePath, actual) async {
      final expected = await Fixture.getFileFormattedContent('test/mock/remoteMessages.i69n.dart');
      expect(actual.build(), expected);
    });
  });

  test('remoteMessages_cs.i69n generates a locale bundle sharing the root store', () async {
    await Fixture.testParsing('remoteMessages_cs', (filePath, actual) async {
      final generated = actual.build();
      final expected = await Fixture.getFileFormattedContent('test/mock/remoteMessages_cs.i69n.dart');
      expect(generated, expected);
      // The locale class must NOT shadow the store — no second field, no
      // second load(), only the inherited public accessor.
      expect(generated, isNot(contains('final Map<String, String> i69nRemoteData')));
      expect(generated, isNot(contains('void load(')));
    });
  });
}
