import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

class LocaleFile extends Equatable {
  final String filePath;
  LocaleFile(this.filePath);
  String get directory => p.dirname(filePath);
  String get fileName => p.basename(filePath);
  String get pureFileName => fileName.split('.i69n.').first;
  String get fileExtension => p.extension(filePath);
  String get generatedFilePath => p.join(directory, pureFileName + '.i69n.dart');

  @override
  List<Object> get props => [filePath];
}
