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
    if (value is Map) {
      return NodeListNodeValue.create(value, parent, metadata);
    }
    // `List`, not `List<String>`: json.decode yields List<dynamic> and loadYaml
    // yields YamlList, so narrowing to List<String> matched no real input.
    if (value is List) {
      return StringListNodeValue.create(value);
    }
    if (value == null) {
      throw Exception('Message value is null — a message must have a value.');
    }
    // Scalars (String, num, bool, and YAML timestamps) all render as text.
    final text = value.toString();
    final grammatical = GrammaticalNumberNodeValue.create(text);
    if (grammatical != null) return grammatical;
    return StringNodeValue(text);
  }

  @override
  List<Object> get props => [value];
}

class NodeKey extends Equatable {
  final String key;
  final NodeKey? parent;
  final FileMetadata metadata;

  NodeKey(this.key, this.parent, this.metadata);

  static final _identifier = RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$');

  /// Validates that a (parameter-stripped) message key is a usable Dart
  /// identifier. Keys are emitted verbatim as getters, methods and `switch`
  /// cases, so an invalid one would silently produce uncompilable output.
  static String _checkKey(String key) {
    if (!_identifier.hasMatch(key)) {
      throw Exception('Invalid message key "$key": message keys must be valid Dart identifiers.');
    }
    return key;
  }

  factory NodeKey.create(dynamic key, NodeKey? parent, FileMetadata metadata) {
    if (key is String) {
      if (key.contains('(')) {
        return ParametrizedNodeKey.fromKey(key, parent, metadata);
      }
      return NodeKey(_checkKey(key), parent, metadata);
    }
    return NodeKey(_checkKey(key.toString()), parent, metadata);
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

  /// Dotted path of raw keys with no locale prefix (e.g. `home.title`), used as
  /// the runtime store / `_baked` lookup key. The file root resolves to `''`.
  String get messagePath {
    if (parent == null) return '';
    final p = parent!.messagePath;
    return p.isEmpty ? key : '$p.$key';
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
      if (closeParenIndex == -1) {
        throw Exception('Missing closing parenthesis in parametrized key "$key".');
      }
      final paramsString = key.substring(openParenIndex + 1, closeParenIndex);
      if (paramsString.isNotEmpty) {
        final paramParts = paramsString.split(',');
        for (final paramPart in paramParts) {
          final trimmedPart = paramPart.trim();
          // Split on whitespace runs so "String  name" still parses as a pair;
          // anything that is not exactly "<type> <name>" is a hard error rather
          // than a silently dropped parameter.
          final parts = trimmedPart.split(RegExp(r'\s+'));
          if (parts.length != 2) {
            throw Exception('Invalid parameter declaration "$trimmedPart" in key "$key". Expected "<type> <name>".');
          }
          parameters.add(Parameter(parts[1], parts[0]));
        }
      }
    }
    return ParametrizedNodeKey(NodeKey._checkKey(baseKey), parent, parameters, metadata);
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

class Node extends Equatable {
  final NodeKey key;
  final NodeValue value;
  Node(this.key, this.value);

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
    // `remote` is a file-level flag: only the file root emits `_baked` and the
    // data store. Introduced mid-tree it would render tr(..., _baked) against a
    // constant that does not exist, so reject it with a clear message instead
    // of emitting Dart that cannot compile.
    if (key.hasParent && hasFlag('remote') && !inheritedFlags.contains('remote')) {
      throw Exception('The "remote" flag is file-level: declare _i69n: remote at the top of the file, '
          'not on the nested message object "$path".');
    }
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

  /// Collects every leaf message in this subtree as `messagePath -> template`,
  /// with each template escaped for embedding in a Dart string literal.
  Map<String, String> collectBaked() {
    final out = <String, String>{};
    void walk(Node n) {
      for (final child in n._childNodes) {
        if (child.isClassNode) {
          walk(child);
        } else {
          out[child.key.messagePath] = escapeTemplate(child.value.value.toString());
        }
      }
    }

    walk(this);
    return out;
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
    final remote = hasFlag('remote') || inheritedFlags.contains('remote');
    if (key.hasParent) {
      b.writeln('final ${key.parent!.objectName} _parent;');
      if (isDefault) {
        b.writeln('const $className(this._parent);');
      } else {
        b.writeln('const $className(this._parent) : super(_parent);');
      }
      if (remote && isDefault) {
        // Child bundles read the data loaded into the root via the parent
        // chain. The member is PUBLIC on purpose: locale files are separate
        // libraries, and a library-private `_messages` cannot be inherited
        // across them — each locale class would shadow its own empty store and
        // loaded payloads would silently never apply to inherited keys.
        b.writeln('Map<String, String> get i69nRemoteMessages => _parent.i69nRemoteMessages;');
      }
      // Locale classes inherit the store accessor from the default class.
    } else {
      // A remote root holds its loaded data, so it cannot be const.
      b.writeln('${remote ? '' : 'const '}$className();');
      if (remote && isDefault) {
        // Public for the same cross-library reason as above. `i69nRemoteData`
        // and `i69nRemoteMessages` are internal API — do not use directly.
        b.writeln('final Map<String, String> i69nRemoteData = {};');
        b.writeln('void load(Map data) { i69nRemoteData..clear()..addAll(i69n.flattenMessages(data)); }');
        b.writeln('Map<String, String> get i69nRemoteMessages => i69nRemoteData;');
      }
      // A locale root inherits the store and `load` from the default class, so
      // one loaded payload feeds inherited and locale-declared keys alike.
    }
    // JSON and JSONC values escape automatically ("" has one spelling in JSON);
    // YAML keeps the legacy manual-escaping convention for upstream compatibility.
    final ext = key.metadata.localeFile.fileExtension;
    final isJson = ext == '.json' || ext == '.jsonc';
    final escape = hasFlag('noescape') ? (String s) => s : (isJson ? escapeJsonDartString : escapeDartString);
    for (final child in _childNodes) {
      if (child.isClassNode) {
        b.writeln('${child.key.objectName} get ${child.key.key} => ${child.key.objectName}(this);');
      } else if (remote) {
        final childKey = child.key;
        final mp = childKey.messagePath;
        if (childKey is ParametrizedNodeKey) {
          final params = childKey.parameters.map((p) => '${p.type} ${p.name}').join(', ');
          final args = '{${childKey.parameters.map((p) => "'${p.name}': ${p.name}").join(', ')}}';
          b.writeln(
              "String ${childKey.key}($params) => i69n.tr(i69nRemoteMessages, _baked, '$mp', $args, _languageCode);");
        } else {
          b.writeln(
              "String get ${childKey.key} => i69n.tr(i69nRemoteMessages, _baked, '$mp', const {}, _languageCode);");
        }
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
    // Local flag wins; else the build.yaml global applies unless the local
    // `map` / `traverse` override cancels it (see README "Global configuration
    // for map operators").
    final meta = key.metadata;
    final disableMap = hasFlag('nomap') || (!hasFlag('map') && meta.hasGlobalFlag('nomap'));
    final disableTraverse = hasFlag('notraverse') || (!hasFlag('traverse') && meta.hasGlobalFlag('notraverse'));
    if (disableMap && disableTraverse) {
      b.writeln("throw Exception('[] operator is disabled in $path, see _i69n: nomap, notraverse flag.');");
      b.writeln('}');
      return;
    }
    if (!disableTraverse) {
      b.writeln("var index = key.indexOf('.');");
      b.writeln('if (index > 0) {');
      b.writeln("return (this[key.substring(0, index)] as ${Constants.i69nMessageBundle})[key.substring(index + 1)];");
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
    // Any decoded list: json.decode yields List<dynamic>, loadYaml yields
    // YamlList, so a JSON config like `"_i69n": ["remote", "nomap"]` lands here.
    if (value is List) {
      return StringListNodeValue(value.map((e) => e.toString()).toList());
    }
    if (value is num || value is bool) {
      return StringListNodeValue([value.toString()]);
    }
    throw Exception('Unsupported value type: ${value.runtimeType}');
  }
}

enum GrammaticalNumberType { plural, ordinal, cardinal }

class GrammaticalNumberNodeValue extends NodeValue<String> {
  final GrammaticalNumberType _type;
  // Matches an actual helper call (`_plural(`, `_ordinal(`, `_cardinal(`) so a
  // message that merely contains the word "plural" is not misclassified.
  static final _regex = RegExp(r'_(plural|ordinal|cardinal)\(');
  GrammaticalNumberNodeValue(super.value, this._type);

  static GrammaticalNumberNodeValue? create(String value) {
    final match = _regex.firstMatch(value);
    if (match == null) return null;
    return GrammaticalNumberNodeValue(
      value,
      GrammaticalNumberType.values.firstWhere((e) => e.name == match.group(1)!),
    );
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
