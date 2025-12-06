import 'dart:io';

import 'package:i69n/src/v2/formatters/base_parser.dart';
import 'package:i69n/src/v2/shared/file_data.dart';
import 'package:yaml/yaml.dart';

class YamlParser implements BaseParser {
  final String filePath;

  YamlParser(this.filePath);
  @override
  Future<FileData> parse() async {
    final file = File(filePath);
    final String yamlString = await file.readAsString();
    final yamlMap = (loadYaml(yamlString) as YamlMap);
    return FileData.parseMap(filePath, yamlMap);
  }
}
