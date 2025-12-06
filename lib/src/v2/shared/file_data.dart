import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';
import 'package:equatable/equatable.dart';
import 'package:i69n/src/v2/shared/file.dart';
import 'package:i69n/src/v2/shared/file_metadata.dart';
import 'package:i69n/src/v2/shared/node.dart';

class FileData extends Equatable {
  final FileMetadata metadata;
  final List<Node> nodes;
  final List<Import> imports;
  final List<String> lintIgnore;
  FileData(this.metadata, this.nodes, this.imports, this.lintIgnore);

  factory FileData.parseMap(String filePath, Map<dynamic, dynamic> map) {
    final file = LocaleFile(filePath);
    final nodes = map.entries.map((entry) => Node.create(entry.key, entry.value)).toList();
    final configNodes = _getConfigNodes(nodes);
    final imports = _getImports(configNodes);
    final fileMetadata = FileMetadata.fromData(configNodes, file);
    final ignores = _getIgnores(configNodes);
    return FileData(fileMetadata, nodes, imports, ignores);
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

  static List<String> _getIgnores(List<ConfigNode> nodes) {
    if (nodes.isEmpty) {
      return [];
    }
    final ignoreNode = nodes.firstWhereOrNull((e) => e.hasFlag('lint_ignore'));
    if (ignoreNode == null) return [];
    return ignoreNode.value.value.map((e) => e).toList();
  }

  String build() {
    final output = StringBuffer();
    output.write(
        '// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes');
    if (lintIgnore.isNotEmpty) {
      output.write(', ');
      output.writeAll(lintIgnore);
    }
    output.writeln('');
    output.writeln('// GENERATED FILE, do not edit!');
    output.writeln("import 'package:i69n/i69n.dart' as i69n;");
    imports.map((e) => "import '$e';").forEach((e) => output.writeln(e));
    output.writeln('');
    output.writeln("String get _languageCode => '${metadata.languageCode}';");
    output.writeln("String get _localeName => '${metadata.localeName}';");
    output.writeln('');
    try {
      var formatter = DartFormatter(
        languageVersion: DartFormatter.latestShortStyleLanguageVersion,
      );
      return formatter.format(output.toString());
    } catch (e) {
      print(
          'Cannot format ${metadata.languageCode}, ${metadata.localeFile.filePath} messages. You might need to escape some special characters with a backslash. Please investigate generated class.');
      return output.toString();
    }
  }

  @override
  List<Object?> get props => [metadata, nodes, imports];
}
