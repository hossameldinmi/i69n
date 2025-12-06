import 'package:i69n/src/v2/shared/file_data.dart';

abstract class BaseParser {
  Future<FileData> parse();
}
