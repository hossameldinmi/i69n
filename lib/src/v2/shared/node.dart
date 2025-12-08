import 'package:equatable/equatable.dart';

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
  static NodeValue create(dynamic value) {
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

  @override
  List<Object> get props => [value];
}

class NodeKey extends Equatable {
  final String key;

  NodeKey(this.key);

  factory NodeKey.create(dynamic key) {
    if (key is String) {
      if (key.contains('(')) {
        return ParametrizedNodeKey.fromKey(key);
      }
      return NodeKey(key);
    }
    return NodeKey(key.toString());
  }
  bool startsWith(String pattern) => key.startsWith(pattern);

  @override
  List<Object> get props => [key];
}

class ParametrizedNodeKey extends NodeKey {
  ParametrizedNodeKey(super.key, this.parameters);
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

class Node extends NodeValue<NodeValue> {
  final NodeKey key;
  Node(this.key, super.value);

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

  factory NodeListNodeValue.create(Map value) {
    return NodeListNodeValue(value.entries.map((entry) => Node.create(entry.key, entry.value)).toList());
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

  bool hasFlag(String flag) {
    final configKey = '${_configKey}_$flag';
    return key.key.startsWith(configKey);
  }
}
