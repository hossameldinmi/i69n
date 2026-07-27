import 'dart:io';
import 'package:dart_style/dart_style.dart';
import 'package:i69n/src/formatters/json_parser.dart';
import 'package:i69n/src/formatters/yaml_parser.dart';
import 'package:i69n/src/shared/file_node.dart';

class Fixture {
  static Future<void> testParsing(String fileName, Future<void> Function(String filePath, FileNode actual) test) async {
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

  static Future<String> getFileFormattedContent(String filePath) async {
    final content = await File(filePath).readAsString();
    var formatter = DartFormatter(
      languageVersion: DartFormatter.latestShortStyleLanguageVersion,
    );
    // Deliberately unguarded: a golden file that does not parse is a codegen
    // bug, and swallowing the error would let two broken outputs compare equal
    // as raw strings. Fail the test with the formatter's own message.
    return formatter.format(content);
  }
}
