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
/// Same as cardinal.
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

/// Flattens decoded remote localization [data] into dotted message keys
/// (`{home:{title:'x'}}` -> `{'home.title':'x'}`), ignoring any `_i69n*` config
/// keys. A remote bundle's `load` uses this to populate its instance data.
Map<String, String> flattenMessages(Map data) {
  final out = <String, String>{};
  _flatten(data, '', out, 0);
  return out;
}

/// Defensive cap on nesting of untrusted remote payloads. Real bundles are a
/// handful of levels deep; anything past this is ignored rather than recursed,
/// so a pathologically nested payload cannot overflow the stack in `load`.
const _maxFlattenDepth = 32;

void _flatten(Map data, String prefix, Map<String, String> out, int depth) {
  if (depth > _maxFlattenDepth) return;
  data.forEach((dynamic k, dynamic v) {
    final key = k.toString();
    if (key.startsWith('_i69n')) return;
    final path = prefix.isEmpty ? key : '$prefix.$key';
    if (v == null) {
      // A null leaf means "no translation" — skip it so the baked default
      // wins, instead of rendering the literal string "null".
      return;
    }
    if (v is Map) {
      _flatten(v, path, out, depth + 1);
    } else {
      out[path] = v.toString();
    }
  });
}

/// Resolves a single message against a bundle's loaded [data]: a loaded value
/// wins, then the compiled-in [baked] template, then the [key] itself. The
/// chosen template is interpreted against [args].
///
/// Loaded values come from an untrusted remote source, so a malformed template
/// (unterminated `${`, unknown function, non-int count, over-deep nesting)
/// must not crash the caller: on failure it falls back to the compiled-in
/// [baked] default, and finally to the raw [key]. A bad remote push therefore
/// degrades to the built-in string instead of throwing out of a getter.
String tr(Map<String, String> data, Map<String, String> baked, String key, Map<String, Object?> args, String languageCode) {
  final loaded = data[key];
  if (loaded != null) {
    try {
      return interpret(loaded, args, languageCode);
    } catch (_) {
      // Fall through to the baked default below.
    }
  }
  final template = baked[key] ?? key;
  try {
    return interpret(template, args, languageCode);
  } catch (_) {
    return key;
  }
}
