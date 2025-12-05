// ignore_for_file: non_constant_identifier_names

import 'package:i69n/src/v2/formatters/base_parser.dart';
import 'package:i69n/src/v2/formatters/json_parser.dart';
import 'package:i69n/src/v2/formatters/yaml_parser.dart';
import 'package:i69n/src/v2/shared/node.dart';

Future<void> testParsing(String fileName, void Function(BaseParser parser, LocaleFile file) test) async {
  final parsers = [
    YamlParser('test/mock/$fileName.yaml'),
    JsonParser('test/mock/$fileName.json'),
  ];
  for (var parser in parsers) {
    final file = await parser.parse();
    test(parser, file);
  }
}
