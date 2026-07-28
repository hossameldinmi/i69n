/// Rewrites the authored `_select(value, case: 'text', ...)` calls in a message
/// [template] into calls the generated Dart can actually compile:
/// `_select(value, {'case': 'text', ...})`.
///
/// Dart has no arbitrary named arguments, so unlike `_plural`'s fixed CLDR
/// argument names, enum case names cannot pass through verbatim - they become a
/// map literal instead. The map is not `const`: case texts may interpolate the
/// message's parameters.
///
/// Structural problems (an unterminated call, a case with no colon or no name,
/// a duplicate case, a call with no cases at all) throw during the build. That
/// is the point: the alternative is emitting Dart that does not compile, with
/// an error pointing at generated code instead of at the message file.
///
/// The remote path does not use this: remote bundles bake the authored template
/// and interpret it at runtime, where named arguments parse fine.
String rewriteSelectCalls(String template) => _processSelectCalls(template, rewrite: true);

/// Runs the same structural validation as [rewriteSelectCalls] but leaves the
/// template unchanged. The remote path bakes the authored template verbatim
/// (the runtime interpreter parses the named-arg form), so it does not rewrite —
/// but a malformed `_select` must still fail the build, not silently bake and
/// misrender at runtime. Throws on the same structural problems.
void validateSelectCalls(String template) => _processSelectCalls(template, rewrite: false);

String _processSelectCalls(String template, {required bool rewrite}) {
  const call = '_select(';
  final out = StringBuffer();
  var i = 0;
  while (i < template.length) {
    final start = template.indexOf(call, i);
    if (start < 0) {
      if (rewrite) out.write(template.substring(i));
      break;
    }
    if (!_isCallStart(template, start)) {
      if (rewrite) out.write(template.substring(i, start + call.length));
      i = start + call.length;
      continue;
    }
    final open = start + call.length - 1;
    final close = _matchParen(template, open);
    if (close < 0) {
      throw Exception('Invalid _select in message "$template": unterminated call, no matching ")".');
    }
    // Always runs — validates; the returned map literal is only emitted when rewriting.
    final rewritten = _rewriteCall(template.substring(open + 1, close), template);
    if (rewrite) {
      out.write(template.substring(i, start));
      out.write(call);
      out.write(rewritten);
      out.write(')');
    }
    i = close + 1;
  }
  return out.toString();
}

/// Whether the `_select(` found at [index] starts an identifier, rather than
/// ending a longer one such as `my_select(`.
bool _isCallStart(String s, int index) {
  if (index == 0) return true;
  final c = s.codeUnitAt(index - 1);
  final isIdentChar = (c >= 0x41 && c <= 0x5A) || // A-Z
      (c >= 0x61 && c <= 0x7A) || // a-z
      (c >= 0x30 && c <= 0x39) || // 0-9
      c == 0x5F || // _
      c == 0x24; // $
  return !isIdentChar;
}

/// Renders one call's [args] (the text between the parens) as
/// `value, {'case': 'text', ...}`. [template] is only used for error messages.
String _rewriteCall(String args, String template) {
  final parts = _splitArgs(args);
  final value = parts.first.trim();
  if (value.isEmpty) {
    throw Exception('Invalid _select in message "$template": missing the value to branch on.');
  }
  final cases = <String, String>{};
  for (final part in parts.skip(1)) {
    if (part.trim().isEmpty) continue;
    final colon = _topLevelColon(part);
    if (colon < 0) {
      throw Exception('Invalid _select in message "$template": case "${part.trim()}" has no ": text" part.');
    }
    final name = part.substring(0, colon).trim();
    final text = part.substring(colon + 1).trim();
    if (name.isEmpty) {
      throw Exception('Invalid _select in message "$template": a case is missing its name.');
    }
    if (text.isEmpty) {
      throw Exception('Invalid _select in message "$template": case "$name" is missing its text.');
    }
    if (cases.containsKey(name)) {
      throw Exception('Invalid _select in message "$template": duplicate case "$name".');
    }
    cases[name] = text;
  }
  if (cases.isEmpty) {
    throw Exception('Invalid _select in message "$template": at least one case is required.');
  }
  final entries = cases.entries.map((e) => "'${_escapeKey(e.key)}': ${e.value}").join(', ');
  return '$value, {$entries}';
}

/// Escapes a case name for embedding as a single-quoted Dart string-literal key.
/// Case names are usually enum value names, but `_select` matches by
/// `toString()`, so a name may carry a backslash or quote that would otherwise
/// break the generated map literal.
String _escapeKey(String key) => key.replaceAll('\\', r'\\').replaceAll("'", r"\'");

/// Returns the index of the `)` matching the `(` at [openIdx], or -1 if none.
/// Single-quoted regions (and their backslash escapes) are skipped, so parens
/// inside a case text are not counted.
int _matchParen(String s, int openIdx) {
  var depth = 0;
  var inStr = false;
  var i = openIdx;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (inStr) {
      if (c == 0x5C) {
        i += 2; // backslash escapes next
        continue;
      }
      if (c == 0x27) inStr = false; // '
    } else {
      if (c == 0x27) {
        inStr = true; // '
      } else if (c == 0x28) {
        depth++; // (
      } else if (c == 0x29) {
        depth--; // )
        if (depth == 0) return i;
      }
    }
    i++;
  }
  return -1;
}

/// Splits an argument list on top-level commas, ignoring commas inside
/// single-quoted strings and nested parens.
List<String> _splitArgs(String s) {
  final parts = <String>[];
  var start = 0;
  var depth = 0;
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
      } else if (c == 0x28) {
        depth++;
      } else if (c == 0x29) {
        depth--;
      } else if (c == 0x2C && depth == 0) {
        parts.add(s.substring(start, i));
        start = i + 1;
      }
    }
    i++;
  }
  parts.add(s.substring(start));
  return parts;
}

/// Index of the colon separating a case name from its text, skipping colons
/// inside the text itself.
int _topLevelColon(String s) {
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
      } else if (c == 0x3A) {
        return i;
      }
    }
    i++;
  }
  return -1;
}
