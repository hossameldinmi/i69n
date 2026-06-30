import 'package:test/test.dart';
import 'mock/fixture.dart';

void main() {
  test('remoteMessages.i69n generates the remote bundle (yaml + json)', () async {
    await Fixture.testParsing('remoteMessages', (filePath, actual) async {
      final expected = await Fixture.getFileFormattedContent('test/mock/remoteMessages.i69n.dart');
      expect(actual.build(), expected);
    });
  });
}
