import 'package:i69n/i69n.dart' as i69n;

/// Evaluates an i69n message [template] at runtime against [args].
///
/// Supported syntax: `$ident`, `${ident}`, and the grammatical calls
/// `_plural` / `_ordinal` / `_cardinal`. A missing identifier resolves to the
/// empty string. Malformed `${...}` or an unknown function name throws a
/// [FormatException].
String interpret(String template, Map<String, Object?> args, String languageCode) {
  final out = StringBuffer();
  var i = 0;
  while (i < template.length) {
    final ch = template.codeUnitAt(i);
    if (ch == 0x24) {
      // $
      if (i + 1 < template.length && template.codeUnitAt(i + 1) == 0x7B) {
        // ${ ... }
        final end = _matchBrace(template, i + 1);
        if (end < 0) {
          throw FormatException('Unterminated "\${" in template', template, i);
        }
        final expr = template.substring(i + 2, end).trim();
        out.write(_evalExpr(expr, args, languageCode));
        i = end + 1;
      } else {
        final ident = _identAt(template, i + 1);
        if (ident.isEmpty) {
          out.writeCharCode(ch); // lone $
          i++;
        } else {
          out.write(_lookup(ident, args));
          i += 1 + ident.length;
        }
      }
    } else {
      out.writeCharCode(ch);
      i++;
    }
  }
  return out.toString();
}

/// Returns the index of the `}` matching the `{` at [openIdx], or -1 if none.
/// Single-quoted regions (and their escaped quotes) are skipped so braces and
/// quotes inside arg strings are not counted.
int _matchBrace(String s, int openIdx) {
  var depth = 0;
  var inStr = false;
  var i = openIdx;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (inStr) {
      if (c == 0x5C) {
        i += 2;
        continue;
      } // backslash escapes next
      if (c == 0x27) inStr = false; // '
    } else {
      if (c == 0x27) {
        inStr = true; // '
      } else if (c == 0x7B) {
        depth++; // {
      } else if (c == 0x7D) {
        depth--; // }
        if (depth == 0) return i;
      }
    }
    i++;
  }
  return -1;
}

/// Reads a Dart-style identifier starting at [i] (`[A-Za-z_$][A-Za-z0-9_$]*`).
String _identAt(String s, int i) {
  var j = i;
  while (j < s.length) {
    final c = s.codeUnitAt(j);
    final ok = (c >= 0x41 && c <= 0x5A) || // A-Z
        (c >= 0x61 && c <= 0x7A) || // a-z
        (c >= 0x30 && c <= 0x39 && j > i) || // 0-9 (not first)
        c == 0x5F || // _
        c == 0x24; // $
    if (!ok) break;
    j++;
  }
  return s.substring(i, j);
}

String _lookup(String ident, Map<String, Object?> args) => args[ident]?.toString() ?? '';

/// Evaluates an expression found inside `${ ... }`: either a bare identifier or
/// a grammatical call.
String _evalExpr(String expr, Map<String, Object?> args, String lang) {
  final paren = expr.indexOf('(');
  if (paren < 0) return _lookup(expr, args);

  final name = expr.substring(0, paren);
  if (name != '_plural' && name != '_ordinal' && name != '_cardinal') {
    throw FormatException('Unknown function "$name" in template expression', expr);
  }
  if (!expr.endsWith(')')) {
    throw FormatException('Malformed call in template expression', expr);
  }
  final inner = expr.substring(paren + 1, expr.length - 1);
  final parts = _splitArgs(inner);

  final countKey = parts.first.trim();
  final countArg = args[countKey];
  if (countArg is! int) {
    throw FormatException('Argument "$countKey" is not an int ($countArg)', expr);
  }

  final named = <String, String>{};
  for (final part in parts.skip(1)) {
    final colon = part.indexOf(':');
    if (colon < 0) continue;
    final k = part.substring(0, colon).trim();
    final raw = part.substring(colon + 1).trim();
    named[k] = interpret(_unquote(raw), args, lang);
  }

  switch (name) {
    case '_plural':
      return i69n.plural(countArg, lang,
          zero: named['zero'], one: named['one'], two: named['two'], few: named['few'], many: named['many'], other: named['other']);
    case '_ordinal':
      return i69n.ordinal(countArg, lang,
          zero: named['zero'], one: named['one'], two: named['two'], few: named['few'], many: named['many'], other: named['other']);
    default: // _cardinal
      return i69n.cardinal(countArg, lang,
          zero: named['zero'], one: named['one'], two: named['two'], few: named['few'], many: named['many'], other: named['other']);
  }
}

/// Splits a call's argument list on top-level commas, ignoring commas inside
/// single-quoted strings.
List<String> _splitArgs(String s) {
  final parts = <String>[];
  var start = 0;
  var inStr = false;
  var i = 0;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (inStr) {
      if (c == 0x5C) {
        i += 2;
        continue;
      }
      if (c == 0x27) inStr = false;
    } else {
      if (c == 0x27) {
        inStr = true;
      } else if (c == 0x2C) {
        parts.add(s.substring(start, i));
        start = i + 1;
      }
    }
    i++;
  }
  parts.add(s.substring(start));
  return parts;
}

/// Strips surrounding single quotes from a named-arg value and unescapes `\'`
/// and `\\`.
String _unquote(String raw) {
  var s = raw.trim();
  if (s.length >= 2 && s.codeUnitAt(0) == 0x27 && s.codeUnitAt(s.length - 1) == 0x27) {
    s = s.substring(1, s.length - 1);
  }
  final sb = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (c == 0x5C && i + 1 < s.length) {
      sb.writeCharCode(s.codeUnitAt(i + 1));
      i += 2;
    } else {
      sb.writeCharCode(c);
      i++;
    }
  }
  return sb.toString();
}
