extension StringExtensions on String {
  String toPascalCase() {
    return this.split('_').map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)).join('');
  }
}

/// Escapes a Dart string literal: converts tab/newline/carriage-return to their
/// backslash form so the value is a valid single-line `"..."` literal. Surrogate
/// pairs (emoji) are preserved. All other characters pass through unchanged.
String? escapeDartString(String? string) {
  if (string == null) return null;
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

