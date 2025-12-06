import 'package:equatable/equatable.dart';
import 'package:i69n/src/v2/shared/file.dart';
import 'package:i69n/src/v2/shared/file_metadata.dart';
import 'package:i69n/src/v2/shared/node.dart';

class FileData extends Equatable {
  final FileMetadata metadata;
  final List<Node> nodes;
  final List<Import> imports;
  FileData(this.metadata, this.nodes, this.imports);

  factory FileData.parseMap(String filePath, Map<dynamic, dynamic> map) {
    final file = LocaleFile(filePath);
    final nodes = map.entries.map((entry) => Node.create(entry.key, entry.value)).toList();
    final configNodes = _getConfigNodes(nodes);
    final imports = _getImports(configNodes);
    final fileMetadata = FileMetadata.fromData(configNodes, file);
    return FileData(fileMetadata, nodes, imports);
  }

  static List<ConfigNode> _getConfigNodes(Iterable<Node> nodes) {
    return nodes.whereType<ConfigNode>().toList();
  }

  static List<Import> _getImports(List<ConfigNode> nodes) {
    if (nodes.isEmpty) {
      return [];
    }
    final firstNode = nodes.first;
    final hasImportFlag = firstNode.hasFlag('import');
    if (hasImportFlag) return firstNode.value.value.map((e) => Import(e)).toList();
    return [];
  }

  String build() {
    return <String>[
      '// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes',
      '// GENERATED FILE, do not edit!',
      "import 'package:i69n/i69n.dart' as i69n;",
      imports.map((e) => "import '$e';").join('\n'),
      "",
      "String get _languageCode => '${metadata.languageCode}';",
      "String get _localeName => '${metadata.localeName}';",
      "",
    ].join('\n');
  }

  @override
  List<Object?> get props => [metadata, nodes, imports];
}
