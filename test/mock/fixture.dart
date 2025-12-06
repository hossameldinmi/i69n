// ignore_for_file: non_constant_identifier_names
import 'package:i69n/src/v2/formatters/json_parser.dart';
import 'package:i69n/src/v2/formatters/yaml_parser.dart';
import 'package:i69n/src/v2/shared/file_data.dart';

class Fixture {
  static Future<void> testParsing(String fileName, Future<void> Function(String filePath, FileData actual) test) async {
    final yamlPath = 'test/mock/$fileName.i69n.yaml';
    final jsonPath = 'test/mock/$fileName.i69n.json';
    final parsers = [
      (parser: YamlParser(yamlPath), filePath: yamlPath),
      (parser: JsonParser(jsonPath), filePath: jsonPath),
    ];
    for (var parser in parsers) {
      final fileNode = await parser.parser.parse();
      await test(parser.filePath, fileNode);
    }
  }
}
