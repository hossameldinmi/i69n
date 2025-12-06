import 'package:equatable/equatable.dart';

class Import extends Equatable {
  final String value;
  Import(this.value);

  @override
  String toString() => value;

  @override
  List<Object> get props => [value];
}

abstract class NodeValue extends Equatable {
  const NodeValue();
  factory NodeValue.create(dynamic value) {
    if (value is String) {
      final grammatical = GrammaticalNumberNodeValue.create(value);
      if (grammatical != null) return grammatical;
      return StringNodeValue(value);
    }
    if (value is List<String>) {
      return StringListNodeValue.create(value);
    }
    if (value is Map) {
      return NodeListNodeValue.create(value);
    }
    throw Exception('Unsupported value type: ${value.runtimeType}');
  }
}

abstract class NodeKey extends Equatable {
  final String key;

  NodeKey._(this.key);

  factory NodeKey.create(dynamic key) {
    if (key is String) {
      if (key.contains('(')) {
        return ParametrizedNodeKey.fromKey(key);
      }
      return StringNodeKey(key);
    }
    return StringNodeKey(key.toString());
  }
}

class StringNodeKey extends NodeKey {
  StringNodeKey(super.key) : super._();

  bool startsWith(String pattern) => super.key.startsWith(pattern);

  @override
  List<Object> get props => [key];
}

class ParametrizedNodeKey extends NodeKey {
  ParametrizedNodeKey(super.key, this.parameters) : super._();
  final List<Parameter> parameters;

  factory ParametrizedNodeKey.fromKey(String key) {
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
    return ParametrizedNodeKey(baseKey, parameters);
  }

  @override
  List<Object> get props => [key, parameters];
}

class Parameter extends Equatable {
  final String name;
  final String type;

  Parameter(this.name, this.type);

  @override
  List<Object> get props => [name, type];
}

class Node extends NodeValue {
  final NodeKey key;
  final NodeValue value;

  Node(this.key, this.value);

  factory Node.create(dynamic key, dynamic value) {
    final nodeKey = NodeKey.create(key);
    final configNode = ConfigNode.create(nodeKey, value);
    if (configNode != null) {
      return configNode;
    }
    final nodeValue = NodeValue.create(value);
    return Node(nodeKey, nodeValue);
  }

  @override
  List<Object> get props => [key, value];

  bool hasPluralNode() {
    final isPlural = value is GrammaticalNumberNodeValue &&
        (value as GrammaticalNumberNodeValue).isType(GrammaticalNumberType.plural);
    if (isPlural) {
      return true;
    }
    return value is NodeListNodeValue && (value as NodeListNodeValue).value.any((e) => e.hasPluralNode());
  }

  bool hasOrdinalNode() {
    final isOrdinal = value is GrammaticalNumberNodeValue &&
        (value as GrammaticalNumberNodeValue).isType(GrammaticalNumberType.ordinal);
    if (isOrdinal) {
      return true;
    }
    return value is NodeListNodeValue && (value as NodeListNodeValue).value.any((e) => e.hasOrdinalNode());
  }

  bool hasCardinalNode() {
    final isCardinal = value is GrammaticalNumberNodeValue &&
        (value as GrammaticalNumberNodeValue).isType(GrammaticalNumberType.cardinal);
    if (isCardinal) {
      return true;
    }
    return value is NodeListNodeValue && (value as NodeListNodeValue).value.any((e) => e.hasCardinalNode());
  }
}

class StringNodeValue extends NodeValue {
  final String value;
  StringNodeValue(this.value);

  @override
  List<Object> get props => [value];
}

class StringListNodeValue extends NodeValue {
  final List<String> value;
  StringListNodeValue(this.value);

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

  @override
  List<Object> get props => [value];
}

enum GrammaticalNumberType { plural, ordinal, cardinal }

class GrammaticalNumberNodeValue extends NodeValue {
  final String value;
  final GrammaticalNumberType type;
  static final _regex = RegExp(r'plural|ordinal|cardinal');
  GrammaticalNumberNodeValue(this.value, this.type);

  static GrammaticalNumberNodeValue? create(dynamic value) {
    if (_regex.hasMatch(value)) {
      return GrammaticalNumberNodeValue(
          value, GrammaticalNumberType.values.firstWhere((e) => e.name == _regex.firstMatch(value)!.group(0)!));
    }
    return null;
  }

  bool isType(GrammaticalNumberType type) => this.type == type;

  @override
  List<Object> get props => [value, type];
}

class NodeListNodeValue extends NodeValue {
  final List<Node> value;
  NodeListNodeValue(this.value);

  factory NodeListNodeValue.create(Map value) {
    return NodeListNodeValue(value.entries.map((entry) => Node.create(entry.key, entry.value)).toList());
  }

  @override
  List<Object> get props => [value];
}

class ConfigNode extends Node {
  static const String _configKey = '_i69n';
  @override
  final StringListNodeValue value;

  ConfigNode(NodeKey key, this.value) : super(key, value);

  static ConfigNode? create(NodeKey key, dynamic value) {
    if (key is StringNodeKey && key.startsWith(_configKey)) {
      return ConfigNode(key, StringListNodeValue.create(value));
    }
    return null;
  }

  bool hasFlag(String flag) {
    final configKey = '${_configKey}_$flag';
    return key.key.startsWith(configKey);
  }
}
