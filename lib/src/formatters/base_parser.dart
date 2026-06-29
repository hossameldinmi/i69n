import 'package:i69n/src/shared/file_node.dart';

abstract class BaseParser {
  Future<FileNode> parse();
}
