import 'dart:io';

import 'package:jsonc/jsonc.dart';
import 'package:i69n/src/formatters/base_parser.dart';
import 'package:i69n/src/shared/file_node.dart';

class JsoncParser implements BaseParser {
  final String filePath;

  JsoncParser(this.filePath);

  @override
  Future<FileNode> parse() async {
    final file = File(filePath);
    final jsoncString = await file.readAsString();
    final jsoncMap = jsonc.decode(jsoncString) as Map;

    return FileNode.parseMap(filePath, jsoncMap);
  }
}
