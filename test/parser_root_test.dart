import 'dart:io';

import 'package:i69n/src/formatters/json_parser.dart';
import 'package:i69n/src/formatters/yaml_parser.dart';
import 'package:test/test.dart';

/// A message file whose root is not a mapping is an authoring mistake. The
/// parsers must say so, naming the file, instead of letting a cast blow up with
/// a type error that points at package internals.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('i69n_root_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  String write(String name, String content) {
    final path = '${dir.path}/$name';
    File(path).writeAsStringSync(content);
    return path;
  }

  test('a JSON root that is a list is rejected by name', () async {
    final path = write('fooMessages.i69n.json', '["a", "b"]');
    await expectLater(
      JsonParser(path).parse(),
      throwsA(
          isA<Exception>().having((e) => e.toString(), 'message', allOf(contains('fooMessages'), contains('object')))),
    );
  });

  test('a JSON root that is a scalar is rejected by name', () async {
    final path = write('fooMessages.i69n.json', '"just a string"');
    await expectLater(JsonParser(path).parse(), throwsA(isA<Exception>()));
  });

  test('a YAML root that is a list is rejected by name', () async {
    final path = write('fooMessages.i69n.yaml', '- a\n- b\n');
    await expectLater(
      YamlParser(path).parse(),
      throwsA(
          isA<Exception>().having((e) => e.toString(), 'message', allOf(contains('fooMessages'), contains('mapping')))),
    );
  });

  test('an empty YAML file is rejected by name', () async {
    final path = write('fooMessages.i69n.yaml', '');
    await expectLater(YamlParser(path).parse(), throwsA(isA<Exception>()));
  });

  test('a well-formed root still parses', () async {
    final jsonPath = write('fooMessages.i69n.json', '{"a": "A"}');
    final yamlPath = write('fooMessages.i69n.yaml', 'a: A\n');
    expect((await JsonParser(jsonPath).parse()).build(), contains('String get a => "A";'));
    expect((await YamlParser(yamlPath).parse()).build(), contains('String get a => "A";'));
  });
}
