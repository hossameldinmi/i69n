import 'dart:core';
import 'dart:developer';
import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';
import 'package:i69n/src/v2/constants.dart';
import 'package:i69n/src/v2/shared/file.dart';
import 'package:i69n/src/v2/shared/file_metadata.dart';
import 'package:i69n/src/v2/shared/node.dart';
import 'package:i69n/src/v2/utils/string_extensions.dart';

class FileNode extends Node {
  final FileMetadata metadata;
  @override
  NodeListNodeValue get value => super.value as NodeListNodeValue;
  final List<Import> imports;
  final List<String> lintIgnore;
  FileNode(NodeKey key, NodeListNodeValue value, this.metadata, this.imports, this.lintIgnore) : super(key, value);

  factory FileNode.parseMap(String filePath, Map<dynamic, dynamic> map) {
    final file = LocaleFile(filePath);
    NodeKey fileKey = NodeKey(file.pureFileName.toPascalCase(), null, FileMetadata(file, true, 'en', 'en'));
    List<Node> nodes = map.entries
        .map((entry) => Node.create(entry.key, entry.value, fileKey, FileMetadata(file, true, 'en', 'en')))
        .toList();
    final configNodes = _getConfigNodes(nodes);
    final imports = _getImports(configNodes);
    final fileMetadata = FileMetadata.fromData(configNodes, file);
    fileKey = NodeKey(file.pureFileName.toPascalCase(), null, fileMetadata);
    final ignores = _getIgnores(configNodes);
    nodes = map.entries.map((entry) => Node.create(entry.key, entry.value, fileKey, fileMetadata)).toList();
    return FileNode(
      fileKey,
      NodeListNodeValue(nodes),
      fileMetadata,
      imports,
      ignores,
    );
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
      output.writeAll(lintIgnore, ', ');
    }
    output.writeln('');
    output.writeln('// GENERATED FILE, do not edit!');
    output.writeln("import 'package:i69n/i69n.dart' as ${Constants.i69n};");
    imports.map((e) => "import '$e';").forEach((e) => output.writeln(e));
    output.writeln('');
    output.writeln("String get _languageCode => '${metadata.languageCode}';");
    output.writeln("String get _localeName => '${metadata.localeName}';");
    output.writeln('');
    if (hasPluralNode) {
      output.write('''
String _plural(int count, {String? zero, String? one, String? two, String? few, String? many, String? other}) =>
    i69n.plural(count, _languageCode, zero: zero, one: one, two: two, few: few, many: many, other: other);
''');
    }
    if (hasOrdinalNode) {
      output.write('''
String _ordinal(int count, {String? zero, String? one, String? two, String? few, String? many, String? other}) =>
    i69n.ordinal(count, _languageCode, zero: zero, one: one, two: two, few: few, many: many, other: other);
''');
    }
    if (hasCardinalNode) {
      output.write('''
String _cardinal(int count, {String? zero, String? one, String? two, String? few, String? many, String? other}) =>
    i69n.cardinal(count, _languageCode, zero: zero, one: one, two: two, few: few, many: many, other: other);
''');
    }
    output.writeln('');
    final clsStr = buildClasses({});
    log(clsStr);
    output.write(clsStr);

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
  List<Object> get props => [...super.props, lintIgnore, imports, metadata];

  @override
  bool get hasPluralNode => value.hasPluralNode;

  @override
  bool get hasOrdinalNode => value.hasOrdinalNode;

  @override
  bool get hasCardinalNode => value.hasCardinalNode;
}
