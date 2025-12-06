import 'package:i69n/src/v2/shared/file.dart';
import 'package:test/test.dart';

void main() {
  final dir = 'test/mock';
  group('simple_file_path', () {
    final pureFileName = 'testMessages';
    final generatedFilePath = '$dir/testMessages.i69n.dart';
    test('testMessages.i69n.yaml', () async {
      final localeFile = LocaleFile('$dir/testMessages.i69n.yaml');
      expect(localeFile.fileName, 'testMessages.i69n.yaml');
      expect(localeFile.directory, dir);
      expect(localeFile.pureFileName, pureFileName);
      expect(localeFile.fileExtension, '.yaml');
      expect(localeFile.generatedFilePath, generatedFilePath);
    });
    test('testMessages.i69n.json', () async {
      final localeFile = LocaleFile('$dir/testMessages.i69n.json');
      expect(localeFile.fileName, 'testMessages.i69n.json');
      expect(localeFile.directory, dir);
      expect(localeFile.pureFileName, pureFileName);
      expect(localeFile.fileExtension, '.json');
      expect(localeFile.generatedFilePath, generatedFilePath);
    });
  });
  group('file_path_with_locale', () {
    final pureFileName = 'testMessages_ar';
    final generatedFilePath = '$dir/testMessages_ar.i69n.dart';
    test('testMessages_ar.i69n.yaml', () async {
      final localeFile = LocaleFile('$dir/testMessages_ar.i69n.yaml');
      expect(localeFile.fileName, 'testMessages_ar.i69n.yaml');
      expect(localeFile.directory, dir);
      expect(localeFile.pureFileName, pureFileName);
      expect(localeFile.fileExtension, '.yaml');
      expect(localeFile.generatedFilePath, generatedFilePath);
    });
    test('testMessages_ar.i69n.json', () async {
      final localeFile = LocaleFile('$dir/testMessages_ar.i69n.json');
      expect(localeFile.fileName, 'testMessages_ar.i69n.json');
      expect(localeFile.directory, dir);
      expect(localeFile.pureFileName, pureFileName);
      expect(localeFile.fileExtension, '.json');
      expect(localeFile.generatedFilePath, generatedFilePath);
    });
  });
  group('file_path_with_locale_code', () {
    final pureFileName = 'testMessages_ar_EG';
    final generatedFilePath = '$dir/testMessages_ar_EG.i69n.dart';
    test('testMessages_ar_EG.i69n.yaml', () async {
      final localeFile = LocaleFile('$dir/testMessages_ar_EG.i69n.yaml');
      expect(localeFile.fileName, 'testMessages_ar_EG.i69n.yaml');
      expect(localeFile.directory, dir);
      expect(localeFile.pureFileName, pureFileName);
      expect(localeFile.fileExtension, '.yaml');
      expect(localeFile.generatedFilePath, generatedFilePath);
    });
    test('testMessages_ar_EG.i69n.json', () async {
      final localeFile = LocaleFile('$dir/testMessages_ar_EG.i69n.json');
      expect(localeFile.fileName, 'testMessages_ar_EG.i69n.json');
      expect(localeFile.directory, dir);
      expect(localeFile.pureFileName, pureFileName);
      expect(localeFile.fileExtension, '.json');
      expect(localeFile.generatedFilePath, generatedFilePath);
    });
  });
}
