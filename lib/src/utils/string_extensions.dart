extension StringExtensions on String {
  String toPascalCase() {
    return this.split('_').map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)).join('');
  }
}

/// Escapes a Dart string literal: converts tab/newline/carriage-return to their
/// backslash form so the value is a valid single-line `"..."` literal. Surrogate
/// pairs (emoji) are preserved. All other characters pass through unchanged.
///
/// NOTE: `"` and `\` are intentionally NOT escaped here. Non-remote message
/// values follow a manual-escaping convention — authors write `\"` in the
/// source YAML/JSON (see `test/mock/testMessages` `quotes`) — and `$` is left
/// raw so getters can Dart-interpolate `$param`. Auto-escaping would
/// double-escape those inputs. The remote path uses [escapeTemplate] instead,
/// which fully escapes because remote templates are never Dart-interpolated.
String escapeDartString(String string) {
  if (string.isEmpty) return string;

  var sb = StringBuffer();
  // Iterate over the Unicode code points (runes)
  for (var c in string.runes) {
    switch (c) {
      case 9: // \t (Horizontal Tab)
        sb.write('\\t');
        break;
      case 10: // \n (Line Feed)
        sb.write('\\n');
        break;
      case 13: // \r (Carriage Return)
        sb.write('\\r');
        break;
      default:
        // For all other code points, convert the code point back to its string representation
        // This correctly handles both single-unit characters and surrogate pairs (emojis)
        sb.writeCharCode(c);
        break;
    }
  }
  return sb.toString();
}

/// Escapes a **JSON-sourced** message value for embedding in a generated
/// double-quoted Dart string literal.
///
/// JSON has no room for the YAML manual-escaping convention: `"` has exactly
/// one spelling in a JSON string, so a decoded value like `Hello "world"` must
/// be escaped here or the generated Dart does not compile. Rules:
///
/// * outside `${...}`: `"` and `\` are escaped so the text is literal — except
///   an authored `\$`, which passes through (that is how an author suppresses
///   Dart interpolation of a dollar sign);
/// * a bare `$param` stays raw so getters can Dart-interpolate parameters;
/// * inside `${...}` the content is a Dart expression and passes through
///   untouched (its internal escaping is Dart's, e.g. `'didn\'t'`);
/// * tab / newline / carriage-return are escaped everywhere, as in
///   [escapeDartString].
String escapeJsonDartString(String s) {
  final sb = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (c == 0x24 /* $ */ && i + 1 < s.length && s.codeUnitAt(i + 1) == 0x7B /* { */) {
      final end = _matchInterpolationBrace(s, i + 1);
      if (end >= 0) {
        // Dart-expression territory: copy verbatim, but keep control characters
        // out of the single-line literal.
        for (var j = i; j <= end; j++) {
          final e = s.codeUnitAt(j);
          if (e == 9) {
            sb.write(r'\t');
          } else if (e == 10) {
            sb.write(r'\n');
          } else if (e == 13) {
            sb.write(r'\r');
          } else {
            sb.writeCharCode(e);
          }
        }
        i = end + 1;
        continue;
      }
    }
    switch (c) {
      case 92: // backslash
        if (i + 1 < s.length && s.codeUnitAt(i + 1) == 0x24) {
          sb.write(r'\$'); // authored \$ keeps suppressing interpolation
          i += 2;
          continue;
        }
        sb.write(r'\\');
        break;
      case 34: // "
        sb.write(r'\"');
        break;
      case 9:
        sb.write(r'\t');
        break;
      case 10:
        sb.write(r'\n');
        break;
      case 13:
        sb.write(r'\r');
        break;
      default:
        sb.writeCharCode(c);
    }
    i++;
  }
  return sb.toString();
}

/// Returns the index of the `}` matching the `{` at [openIdx], or -1 if none.
/// Single-quoted regions (and their backslash escapes) are skipped, mirroring
/// the runtime interpreter's brace matching.
int _matchInterpolationBrace(String s, int openIdx) {
  var depth = 0;
  var inStr = false;
  var i = openIdx;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (inStr) {
      if (c == 0x5C) {
        i += 2;
        continue;
      }
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

/// Escapes [s] for embedding in a generated **double-quoted** Dart string
/// literal whose runtime value must equal [s] verbatim. Unlike
/// [escapeDartString], this also escapes `$` and `"` so the generated file does
/// not Dart-interpolate the template — the runtime interpreter does.
String escapeTemplate(String s) {
  final sb = StringBuffer();
  for (final c in s.runes) {
    switch (c) {
      case 92: // backslash
        sb.write(r'\\');
        break;
      case 34: // "
        sb.write(r'\"');
        break;
      case 36: // $
        sb.write(r'\$');
        break;
      case 9:
        sb.write(r'\t');
        break;
      case 10:
        sb.write(r'\n');
        break;
      case 13:
        sb.write(r'\r');
        break;
      default:
        sb.writeCharCode(c);
    }
  }
  return sb.toString();
}
