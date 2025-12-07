import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:i69n/src/v2/shared/file.dart';
import 'package:i69n/src/v2/shared/node.dart';

class FileMetadata extends Equatable {
  final LocaleFile localeFile;
  final bool isDefault;
  final String localeName;
  final String languageCode;
  static final _twoCharsLower = RegExp('^[a-z]{2,3}\$');
  static final _twoCharsUpper = RegExp('^[A-Z]{2,3}\$');
  FileMetadata(this.localeFile, this.isDefault, this.localeName, this.languageCode);

  factory FileMetadata.fromData(List<ConfigNode> nodes, LocaleFile localeFile) {
    String languageCode = _getLanguage(nodes);
    final nameParts = localeFile.filePath.split('_');
    if (nameParts.isEmpty) {
      throw Exception(_renderFileNameError(localeFile.filePath));
    }
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
        var languageCode = nameParts[1];
        if (_twoCharsLower.allMatches(languageCode).length != 1) {
          throw Exception(
              'Wrong language code $languageCode in file name ${localeFile.filePath}. Language code must match $_twoCharsLower');
        }
        languageCode = languageCode;
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
    return FileMetadata(localeFile, isDefault, localeName, languageCode);
  }

  static String _getLanguage(List<ConfigNode> nodes) {
    final languageConfig = nodes.firstWhereOrNull((n) => n.hasFlag('language'));
    return languageConfig?.value.value.first ?? '';
  }

  static String _renderFileNameError(String name) {
    return 'Wrong file name: "$name"';
  }

  @override
  List<Object> get props => [localeFile, isDefault, localeName, languageCode];
}
