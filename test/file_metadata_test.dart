import 'package:i69n/src/v2/shared/file.dart';
import 'package:i69n/src/v2/shared/file_metadata.dart';
import 'package:test/test.dart';

/// Covers `FileMetadata.fromData` locale resolution: default file, language-only
/// and language+country suffixes, plus the malformed-name error branches.
void main() {
  test('default file has no locale suffix', () {
    final m = FileMetadata.fromData([], LocaleFile('fooMessages.i69n.yaml'));
    expect(m.isDefault, isTrue);
    expect(m.localeName, 'en');
    expect(m.languageCode, 'en');
  });

  test('language-only suffix resolves locale name', () {
    final m = FileMetadata.fromData([], LocaleFile('fooMessages_ar.i69n.yaml'));
    expect(m.isDefault, isFalse);
    expect(m.localeName, 'ar');
  });

  test('language + country suffix resolves locale name', () {
    final m = FileMetadata.fromData([], LocaleFile('fooMessages_ar_EG.i69n.yaml'));
    expect(m.isDefault, isFalse);
    expect(m.localeName, 'ar_EG');
  });

  test('more than three name parts throws', () {
    expect(() => FileMetadata.fromData([], LocaleFile('a_b_c_d.i69n.yaml')), throwsException);
  });

  test('non lowercase language code throws', () {
    expect(() => FileMetadata.fromData([], LocaleFile('foo_EN.i69n.yaml')), throwsException);
  });

  test('non uppercase country code throws', () {
    expect(() => FileMetadata.fromData([], LocaleFile('foo_ar_eg.i69n.yaml')), throwsException);
  });
}
