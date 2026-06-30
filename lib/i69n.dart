import 'src/cs.dart' as cs;
import 'src/en.dart' as en;
import 'src/runtime/interpreter.dart';
import 'src/uk.dart' as uk;

///
/// Language specific function, which is provided with a number and should return one of possible categories.
/// count is never null.
///
typedef CategoryResolver = QuantityCategory Function(int count, QuantityType type);

enum QuantityCategory { zero, one, two, few, many, other }

enum QuantityType { cardinal, ordinal }

abstract class I69nMessageBundle {
  Object operator [](String messageKey);
}

void registerResolver(String languageCode, CategoryResolver resolver) {
  _resolverRegistry[languageCode] = resolver;
}

///
/// Same as ordinal.
///
String plural(int count, String languageCode,
    {String? zero, String? one, String? two, String? few, String? many, String? other}) {
  return _resolvePlural(count, languageCode, QuantityType.cardinal,
      zero: zero, one: one, two: two, few: few, many: many, other: other);
}

///
/// See: http://cldr.unicode.org/index/cldr-spec/plural-rules
///
String cardinal(int count, String languageCode,
    {String? zero, String? one, String? two, String? few, String? many, String? other}) {
  return _resolvePlural(count, languageCode, QuantityType.cardinal,
      zero: zero, one: one, two: two, few: few, many: many, other: other);
}

///
/// See: http://cldr.unicode.org/index/cldr-spec/plural-rules
///
String ordinal(int count, String languageCode,
    {String? zero, String? one, String? two, String? few, String? many, String? other}) {
  return _resolvePlural(count, languageCode, QuantityType.ordinal,
      zero: zero, one: one, two: two, few: few, many: many, other: other);
}

Map<String, CategoryResolver> _resolverRegistry = {
  'en': en.quantityResolver,
  'cs': cs.quantityResolver,
  'uk': uk.quantityResolver,
};

String _resolvePlural(int count, String languageCode, QuantityType type,
    {String? zero, String? one, String? two, String? few, String? many, String? other}) {
  final c = _resolveCategory(languageCode, count, type);
  many ??= other;
  switch (c) {
    case QuantityCategory.zero:
      return _firstNotNull([zero, many, other])!;
    case QuantityCategory.one:
      return _firstNotNull([one, many, other])!;
    case QuantityCategory.two:
      return _firstNotNull([two, few, many, other])!;
    case QuantityCategory.few:
      return _firstNotNull([few, many, other])!;
    case QuantityCategory.many:
      return _firstNotNull([many, other, few])!;
    case QuantityCategory.other:
      return _firstNotNull([other, many, few])!;
  }
}

QuantityCategory _defaultResolver(int count, QuantityType type) {
  switch (count) {
    case 0:
      return QuantityCategory.zero;
    case 1:
      return QuantityCategory.one;
    case 2:
      return QuantityCategory.two;
    case 3:
      return QuantityCategory.few;
    case 4:
      return QuantityCategory.few;
  }
  return QuantityCategory.other;
}

QuantityCategory _resolveCategory(String languageCode, int count, QuantityType type) {
  final resolver = _resolverRegistry[languageCode] ?? _defaultResolver;
  return resolver(count, type);
}

String? _firstNotNull(List<String?> possibilities) {
  return possibilities.firstWhere((a) => a != null, orElse: () => '???');
}

/// Per-locale runtime message store: locale -> dotted message key -> template.
final Map<String, Map<String, String>> _messageStore = {};

/// Injects remote localization [data] (already decoded from JSON/YAML) for
/// [locale]. Nested maps are flattened to dotted keys (`{home:{title:'x'}}` ->
/// `{'home.title':'x'}`); any `_i69n*` config keys are ignored. Re-loading a
/// locale replaces its previous slice.
void load(String locale, Map data) {
  final flat = <String, String>{};
  _flatten(data, '', flat);
  _messageStore[locale] = flat;
}

void _flatten(Map data, String prefix, Map<String, String> out) {
  data.forEach((dynamic k, dynamic v) {
    final key = k.toString();
    if (key.startsWith('_i69n')) return;
    final path = prefix.isEmpty ? key : '$prefix.$key';
    if (v is Map) {
      _flatten(v, path, out);
    } else {
      out[path] = v.toString();
    }
  });
}

/// Resolves a single message: remote (by [localeName] then [languageCode]) wins,
/// then the compiled-in [baked] template, then the [key] itself. The chosen
/// template is interpreted against [args].
String tr(String localeName, String languageCode, String key, Map<String, Object?> args, Map<String, String> baked) {
  final template = _messageStore[localeName]?[key] ?? _messageStore[languageCode]?[key] ?? baked[key] ?? key;
  return interpret(template, args, languageCode);
}
