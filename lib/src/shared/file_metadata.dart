import 'package:equatable/equatable.dart';
import 'package:i69n/src/shared/file.dart';

class FileMetadata extends Equatable {
  final LocaleFile localeFile;
  final bool isDefault;
  final String localeName;
  final String languageCode;

  /// Builder-level configuration from `build.yaml` (`options:` on the builder),
  /// e.g. `{'nomap': true}`. A node-local `map` / `traverse` flag overrides the
  /// global `nomap` / `notraverse`.
  final Map<String, dynamic> globalConfig;
  static final _twoCharsLower = RegExp('^[a-z]{2,3}\$');
  static final _twoCharsUpper = RegExp('^[A-Z]{2,3}\$');
  FileMetadata(this.localeFile, this.isDefault, this.localeName, this.languageCode, {this.globalConfig = const {}});

  bool hasGlobalFlag(String flag) => globalConfig[flag] == true;

  factory FileMetadata.fromData(String language, LocaleFile localeFile,
      {Map<String, dynamic> globalConfig = const {}}) {
    String languageCode = language;
    final nameParts = localeFile.pureFileName.split('_');
    late bool isDefault;
    late String localeName;

    if (nameParts.length == 1) {
      isDefault = true;
      if (languageCode.isEmpty) {
        languageCode = 'en';
      }
      localeName = 'en';
    } else {
      isDefault = false;

      if (nameParts.length > 3) {
        throw Exception(_renderFileNameError(localeFile.filePath));
      }
      if (nameParts.length >= 2) {
        languageCode = nameParts[1];
        if (_twoCharsLower.allMatches(languageCode).length != 1) {
          throw Exception(
              'Wrong language code $languageCode in file name ${localeFile.filePath}. Language code must match $_twoCharsLower');
        }
        localeName = languageCode;
      }
      if (nameParts.length == 3) {
        var countryCode = nameParts[2];
        if (_twoCharsUpper.allMatches(countryCode).length != 1) {
          throw Exception(
              'Wrong country code $countryCode in file name ${localeFile.filePath}. Country code must match $_twoCharsUpper');
        }
        localeName = '${languageCode}_$countryCode';
      }
    }
    return FileMetadata(localeFile, isDefault, localeName, languageCode, globalConfig: globalConfig);
  }

  static String _renderFileNameError(String name) {
    return 'Wrong file name: "$name"';
  }

  @override
  List<Object> get props => [localeFile, isDefault, localeName, languageCode];
}
