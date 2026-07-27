import 'dart:io';
import 'package:i69n/src/formatters/base_parser.dart';
import 'package:i69n/src/shared/file_node.dart';
import 'package:yaml/yaml.dart';

class YamlParser implements BaseParser {
  final String filePath;

  YamlParser(this.filePath);
  @override
  Future<FileNode> parse() async {
    final file = File(filePath);
    final String yamlString = await file.readAsString();
    final decoded = loadYaml(yamlString);
    if (decoded is! YamlMap) {
      throw Exception('$filePath: a message file must be a YAML mapping, '
          'found ${decoded == null ? 'an empty document' : decoded.runtimeType}.');
    }
    return FileNode.parseMap(filePath, decoded);
  }
}
