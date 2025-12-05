import 'dart:convert';
import 'dart:io';

import 'package:i69n/src/v2/formatters/base_parser.dart';
import 'package:i69n/src/v2/shared/node.dart';

class JsonParser implements BaseParser {
  final String filePath;

  JsonParser(this.filePath);

  @override
  Future<LocaleFile> parse() async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final jsonMap = json.decode(jsonString);
    return LocaleFile.parseMap(jsonMap);
  }
}
