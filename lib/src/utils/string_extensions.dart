extension StringExtensions on String {
  String toPascalCase() {
    return this.split('_').map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)).join('');
  }
}

/// Escapes a Dart string literal: converts tab/newline/carriage-return to their
/// backslash form so the value is a valid single-line `"..."` literal. Surrogate
/// pairs (emoji) are preserved. All other characters pass through unchanged.
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

