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
  final sb = StringBuffer();
  for (final c in string.runes) {
    switch (c) {
      case 9: // \t
        sb.write('\\t');
        break;
      case 10: // \n
        sb.write('\\n');
        break;
      case 13: // \r
        sb.write('\\r');
        break;
      default:
        sb.writeCharCode(c);
        break;
    }
  }
  return sb.toString();
}
