import 'dart:io';

import 'package:i69n/src/v2/formatters/base_parser.dart';
import 'package:i69n/src/v2/shared/node.dart';
import 'package:yaml/yaml.dart';

class YamlParser implements BaseParser {
  @override
  Future<LocaleFile> parse(String filePath) async {
    final file = File(filePath);
    final String yamlString = await file.readAsString();
    final yamlMap = (loadYaml(yamlString) as YamlMap);
    return LocaleFile.parseMap(yamlMap);
  }
}
