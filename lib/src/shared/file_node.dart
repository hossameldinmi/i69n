import 'package:dart_style/dart_style.dart';
import 'package:i69n/src/constants.dart';
import 'package:i69n/src/shared/file.dart';
import 'package:i69n/src/shared/file_metadata.dart';
import 'package:i69n/src/shared/node.dart';
import 'package:i69n/src/utils/string_extensions.dart';

class FileNode extends Node {
  final FileMetadata metadata;
  @override
  NodeListNodeValue get value => super.value as NodeListNodeValue;
  final List<Import> imports;
  final List<String> lintIgnore;
  FileNode(NodeKey key, NodeListNodeValue value, this.metadata, this.imports, this.lintIgnore) : super(key, value);

  factory FileNode.parseMap(String filePath, Map<dynamic, dynamic> map,
      {Map<String, dynamic> globalConfig = const {}}) {
    final file = LocaleFile(filePath);
    // The root class is always named after the default-locale object (locale
    // suffix stripped); locale files extend it.
    final defaultObjectName = file.pureFileName.split('_').first.toPascalCase();

    // File-level configuration lives in top-level `_i69n_*` keys. Read it from
    // the raw map so the node tree only has to be built once.
    final imports = _configList(map, 'import').map((e) => Import(e)).toList();
    final lintIgnore = _configList(map, 'lint_ignore');
    final language = map['${_configPrefix}_language']?.toString() ?? '';

    final metadata = FileMetadata.fromData(language, file, globalConfig: globalConfig);
    final fileKey = NodeKey(defaultObjectName, null, metadata);
    final nodes = map.entries.map((entry) => Node.create(entry.key, entry.value, fileKey, metadata)).toList();

    return FileNode(fileKey, NodeListNodeValue(nodes), metadata, imports, lintIgnore);
  }

  static const _configPrefix = '_i69n';

  /// Parses a comma-separated `_i69n_<name>` file-level config value, or returns
  /// an empty list when the key is absent.
  static List<String> _configList(Map<dynamic, dynamic> map, String name) {
    final raw = map['${_configPrefix}_$name'];
    if (raw == null) return const [];
    return StringListNodeValue.create(raw).value;
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
    output.writeln('// dart format off');
    output.writeln("import 'package:i69n/i69n.dart' as ${Constants.i69n};");
    // Locale files import the default-locale file they extend.
    if (!metadata.isDefault) {
      output.writeln("import '${metadata.localeFile.pureFileName.split('_').first}.i69n.dart';");
    }
    imports.map((e) => "import '$e';").forEach((e) => output.writeln(e));
    output.writeln('');
    output.writeln("String get _languageCode => '${metadata.languageCode}';");
    output.writeln("String get _localeName => '${metadata.localeName}';");
    output.writeln('');
    final remote = hasFlag('remote');
    if (!remote) {
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
      if (hasSelectNode) {
        output.write('''
String _select(Object? value, Map<String, String> cases) => i69n.select(value, cases);
''');
      }
    }
    output.writeln('');
    if (remote) {
      final baked = collectBaked();
      output.writeln('const Map<String, String> _baked = {');
      baked.forEach((k, v) {
        output.writeln('  \'$k\': "$v",');
      });
      output.writeln('};');
      output.writeln('');
    }
    output.write(buildClasses({}));

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
