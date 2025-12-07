import 'package:i69n/src/v2/shared/file_node.dart';

abstract class BaseParser {
  Future<FileNode> parse();
}
