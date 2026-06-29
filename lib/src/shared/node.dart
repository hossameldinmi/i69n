import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:i69n/src/constants.dart';
import 'package:i69n/src/shared/file_metadata.dart';
import 'package:i69n/src/utils/string_extensions.dart';

class Import extends Equatable {
  final String value;
  Import(this.value);

  @override
  String toString() => value;

  @override
  List<Object> get props => [value];
}

abstract class NodeValue<V extends Object> extends Equatable {
  final V value;
  const NodeValue(this.value);
  static NodeValue create(dynamic value, NodeKey? parent, FileMetadata metadata) {
    if (value is String) {
      final grammatical = GrammaticalNumberNodeValue.create(value);
      if (grammatical != null) return grammatical;
      return StringNodeValue(value);
    }
    if (value is List<String>) {
      return StringListNodeValue.create(value);
    }
    if (value is Map) {
      return NodeListNodeValue.create(value, parent, metadata);
    }
    throw Exception('Unsupported value type: ${value.runtimeType}');
  }

  @override
  List<Object> get props => [value];
}

class NodeKey extends Equatable {
  final String key;
  final NodeKey? parent;
  final FileMetadata metadata;

  NodeKey(this.key, this.parent, this.metadata);

  factory NodeKey.create(dynamic key, NodeKey? parent, FileMetadata metadata) {
    if (key is String) {
      if (key.contains('(')) {
        return ParametrizedNodeKey.fromKey(key, parent, metadata);
      }
      return NodeKey(key, parent, metadata);
    }
    return NodeKey(key.toString(), parent, metadata);
  }
  bool startsWith(String pattern) => key.startsWith(pattern);

  @override
  List<Object?> get props => [key, parent];

  bool get hasParent => parent != null;

  /// The locale-independent class name (e.g. `GenericExampleMessages`). The root
  /// key already carries the default object name (locale suffix stripped).
  String get fullKey {
    if (hasParent) {
      return '${key.toPascalCase()}${parent!.fullKey.toPascalCase()}';
    }
    return key.toPascalCase();
  }

  /// The generated class name. For the default locale this equals [fullKey];
  /// for a locale file it appends the locale suffix (e.g.
  /// `GenericExampleMessages_cs`).
  String get objectName => metadata.isDefault ? fullKey : '${fullKey}_${metadata.localeName}';

  /// Dotted runtime path used in `operator[]` error messages. The root resolves
  /// to the file's language code; descendants append their raw key.
  String get path {
    if (hasParent) {
      return '${parent!.path}.$key';
    }
    return metadata.languageCode;
  }
}

class ParametrizedNodeKey extends NodeKey {
  ParametrizedNodeKey(super.key, super.parent, this.parameters, super.metadata);
  final List<Parameter> parameters;

  factory ParametrizedNodeKey.fromKey(String key, NodeKey? parent, FileMetadata metadata) {
    final openParenIndex = key.indexOf('(');
    final baseKey = openParenIndex != -1 ? key.substring(0, openParenIndex) : key;
    final parameters = <Parameter>[];
    if (openParenIndex != -1) {
      final closeParenIndex = key.indexOf(')', openParenIndex);
      if (closeParenIndex != -1) {
        final paramsString = key.substring(openParenIndex + 1, closeParenIndex);
        if (paramsString.isNotEmpty) {
          final paramParts = paramsString.split(',');
          for (final paramPart in paramParts) {
            final trimmedPart = paramPart.trim();
            final parts = trimmedPart.split(' ');
            if (parts.length == 2) {
              parameters.add(Parameter(parts[1], parts[0]));
            }
          }
        }
      }
    }
    return ParametrizedNodeKey(baseKey, parent, parameters, metadata);
  }

  @override
  List<Object?> get props => [...super.props, parameters];
}

class Parameter extends Equatable {
  final String name;
  final String type;

  Parameter(this.name, this.type);

  @override
  List<Object> get props => [name, type];
}

class Node extends NodeValue<NodeValue> {
  final NodeKey key;
  Node(this.key, super.value);

  factory Node.create(dynamic key, dynamic value, NodeKey? parentKey, FileMetadata metadata) {
    final nodeKey = NodeKey.create(key, parentKey, metadata);
    final configNode = ConfigNode.create(nodeKey, value);
    if (configNode != null) {
      return configNode;
    }
    final nodeValue = NodeValue.create(value, nodeKey, metadata);
    return Node(nodeKey, nodeValue);
  }

  @override
  List<Object> get props => [key, value];

  bool get hasPluralNode {
    final isPlural = value is GrammaticalNumberNodeValue &&
        (value as GrammaticalNumberNodeValue).isType(GrammaticalNumberType.plural);
    if (isPlural) {
      return true;
    }
    return value is NodeListNodeValue && (value as NodeListNodeValue).hasPluralNode;
  }

  bool get hasOrdinalNode {
    final isOrdinal = value is GrammaticalNumberNodeValue &&
        (value as GrammaticalNumberNodeValue).isType(GrammaticalNumberType.ordinal);
    if (isOrdinal) {
      return true;
    }
    return value is NodeListNodeValue && (value as NodeListNodeValue).hasOrdinalNode;
  }

  bool get hasCardinalNode {
    final isCardinal = value is GrammaticalNumberNodeValue &&
        (value as GrammaticalNumberNodeValue).isType(GrammaticalNumberType.cardinal);
    if (isCardinal) {
      return true;
    }
    return value is NodeListNodeValue && (value as NodeListNodeValue).hasCardinalNode;
  }

  /// Whether this node renders as a Dart class (i.e. it has child nodes).
  bool get isClassNode => value is NodeListNodeValue;

  List<Node> get _configNodes {
    final v = value;
    if (v is NodeListNodeValue) return v.value.whereType<ConfigNode>().toList();
    return const [];
  }

  List<Node> get _childNodes {
    final v = value;
    if (v is NodeListNodeValue) return v.value.where((n) => n is! ConfigNode).toList();
    return const [];
  }

  /// Flags declared in the bare `_i69n` config node (comma separated list).
  Set<String> get flags {
    final cfg = _configNodes.firstWhereOrNull((c) => c.key.key == ConfigNode._configKey);
    if (cfg is! ConfigNode) return {};
    return cfg.value.value.map((e) => e.trim()).toSet();
  }

  bool hasFlag(String flag) => flags.contains(flag);

  /// Value of a `_i69n_<name>` config node, or null when absent.
  String? flagValue(String name) {
    final cfg = _configNodes.firstWhereOrNull((c) => c.key.key == '${ConfigNode._configKey}_$name');
    if (cfg is! ConfigNode || cfg.value.value.isEmpty) return null;
    return cfg.value.value.first;
  }

  /// Renders this class node and, depth-first, every descendant class node.
  String buildClasses(Set<String> inheritedFlags) {
    final buffer = StringBuffer();
    buffer.write(_renderClass(inheritedFlags));
    final childInherited = {...inheritedFlags, ...flags};
    for (final child in _childNodes) {
      if (child.isClassNode) {
        buffer.write(child.buildClasses(childInherited));
      }
    }
    return buffer.toString();
  }

  String _renderClass(Set<String> inheritedFlags) {
    final b = StringBuffer();
    final className = key.objectName;
    final isDefault = key.metadata.isDefault;
    final implementsName = flagValue('implements');
    if (isDefault) {
      final implementsClause =
          implementsName != null ? '${Constants.i69nMessageBundle}, $implementsName' : Constants.i69nMessageBundle;
      b.writeln('class $className implements $implementsClause {');
    } else {
      // Locale files extend the default-locale class so missing keys fall back.
      final implementsClause = implementsName != null ? ' implements $implementsName' : '';
      b.writeln('class $className extends ${key.fullKey}$implementsClause {');
    }
    if (key.hasParent) {
      b.writeln('final ${key.parent!.objectName} _parent;');
      if (isDefault) {
        b.writeln('const $className(this._parent);');
      } else {
        b.writeln('const $className(this._parent) : super(_parent);');
      }
    } else {
      b.writeln('const $className();');
    }
    final escape = hasFlag('noescape') ? (String s) => s : escapeDartString;
    for (final child in _childNodes) {
      if (child.isClassNode) {
        b.writeln('${child.key.objectName} get ${child.key.key} => ${child.key.objectName}(this);');
      } else {
        final literal = escape(child.value.value.toString());
        final childKey = child.key;
        if (childKey is ParametrizedNodeKey) {
          final params = childKey.parameters.map((p) => '${p.type} ${p.name}').join(', ');
          b.writeln('String ${childKey.key}($params) => "$literal";');
        } else {
          b.writeln('String get ${childKey.key} => "$literal";');
        }
      }
    }
    _renderMapOperator(b, inheritedFlags);
    b.writeln('}');
    b.writeln('');
    return b.toString();
  }

  void _renderMapOperator(StringBuffer b, Set<String> inheritedFlags) {
    b.writeln('Object operator [](String key) {');
    final disableMap = hasFlag('nomap');
    final disableTraverse = hasFlag('notraverse');
    if (disableMap && disableTraverse) {
      b.writeln("throw Exception('[] operator is disabled in $path, see _i69n: nomap, notraverse flag.');");
      b.writeln('}');
      return;
    }
    if (!disableTraverse) {
      b.writeln("var index = key.indexOf('.');");
      b.writeln('if (index > 0) {');
      b.writeln(
          "return (this[key.substring(0, index)] as ${Constants.i69nMessageBundle})[key.substring(index + 1)];");
      b.writeln('}');
    }
    if (disableMap) {
      b.writeln("throw Exception('[] operator is disabled in $path, see _i69n: nomap flag.');");
    } else {
      b.writeln('switch (key) {');
      for (final child in _childNodes) {
        b.writeln("case '${child.key.key}': return ${child.key.key};");
      }
      if (!key.metadata.isDefault) {
        // Locale classes delegate unknown keys to the default-locale superclass.
        b.writeln('default: return super[key];');
      } else {
        final nothrow = hasFlag('nothrow') || inheritedFlags.contains('nothrow');
        if (nothrow) {
          b.writeln(r"default: throw Exception('Message $key doesn\'t exist in $this');");
        } else {
          b.writeln('default: return key;');
        }
      }
      b.writeln('}');
    }
    b.writeln('}');
  }

  String get path => key.path;
}

class StringNodeValue extends NodeValue<String> {
  const StringNodeValue(super.value);
}

class StringListNodeValue extends NodeValue<List<String>> {
  const StringListNodeValue(super.value);

  factory StringListNodeValue.create(dynamic value) {
    if (value is String) {
      final parts = value.split(',');
      return StringListNodeValue(parts);
    }
    if (value is List<String>) {
      return StringListNodeValue(value);
    }
    throw Exception('Unsupported value type: ${value.runtimeType}');
  }
}

enum GrammaticalNumberType { plural, ordinal, cardinal }

class GrammaticalNumberNodeValue extends NodeValue<String> {
  final GrammaticalNumberType _type;
  static final _regex = RegExp(r'plural|ordinal|cardinal');
  GrammaticalNumberNodeValue(super.value, this._type);

  static GrammaticalNumberNodeValue? create(dynamic value) {
    if (_regex.hasMatch(value)) {
      return GrammaticalNumberNodeValue(
        value,
        GrammaticalNumberType.values.firstWhere((e) => e.name == _regex.firstMatch(value)!.group(0)!),
      );
    }
    return null;
  }

  bool isType(GrammaticalNumberType type) => this._type == type;

  @override
  List<Object> get props => [...super.props, _type];
}

class NodeListNodeValue extends NodeValue<List<Node>> {
  NodeListNodeValue(super.value);

  factory NodeListNodeValue.create(Map value, NodeKey? parent, FileMetadata metadata) {
    return NodeListNodeValue(
        value.entries.map((entry) => Node.create(entry.key, entry.value, parent, metadata)).toList());
  }

  bool get hasPluralNode => value.any((e) => e.hasPluralNode);

  bool get hasCardinalNode => value.any((e) => e.hasCardinalNode);

  bool get hasOrdinalNode => value.any((e) => e.hasOrdinalNode);
}

class ConfigNode extends Node {
  static const String _configKey = '_i69n';
  @override
  final StringListNodeValue value;

  ConfigNode(NodeKey key, this.value) : super(key, value);

  static ConfigNode? create(NodeKey key, dynamic value) {
    if (key.startsWith(_configKey)) {
      return ConfigNode(key, StringListNodeValue.create(value));
    }
    return null;
  }
}
