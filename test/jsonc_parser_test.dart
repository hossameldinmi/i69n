import 'dart:io';
import 'package:i69n/src/formatters/jsonc_parser.dart';
import 'package:test/test.dart';

void main() {
  test('JsoncParser strips // and /* */ comments and trailing commas', () async {
    final tmp = File('${Directory.systemTemp.path}/test.i69n.jsonc');
    await tmp.writeAsString('''
{
  // a line comment
  "generic": {
    "ok": "OK", /* inline block comment */
    "done": "DONE",
  },
}
''');
    addTearDown(() => tmp.deleteSync());

    final node = await JsoncParser(tmp.path).parse();
    final out = node.build();

    expect(out, contains('String get ok => "OK";'));
    expect(out, contains('String get done => "DONE";'));
  });
}
