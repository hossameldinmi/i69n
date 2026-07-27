import 'dart:convert';
import 'dart:io';

import 'package:i69n/src/formatters/base_parser.dart';
import 'package:i69n/src/shared/file_node.dart';

class JsonParser implements BaseParser {
  final String filePath;

  JsonParser(this.filePath);

  @override
  Future<FileNode> parse() async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final decoded = json.decode(jsonString);
    if (decoded is! Map) {
      throw Exception('$filePath: a message file must be a JSON object, '
          'found ${decoded.runtimeType}.');
    }

    return FileNode.parseMap(filePath, decoded);
  }
}
