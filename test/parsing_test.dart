import 'dart:io';

import 'package:i69n/src/v2/shared/file.dart';
import 'package:i69n/src/v2/shared/file_data.dart';
import 'package:i69n/src/v2/shared/file_metadata.dart';
import 'package:i69n/src/v2/shared/node.dart';
import 'package:test/test.dart';
import 'mock/fixture.dart';

void main() {
  test('testMessages.i69n', () async {
    await Fixture.testParsing('testMessages', (filePath, actual) async {
      final expected = FileData(FileMetadata(LocaleFile(filePath), true, 'en', 'sk'), [
        ConfigNode(StringNodeKey('_i69n_import'), StringListNodeValue(['dart:io'])),
        ConfigNode(StringNodeKey('_i69n_language'), StringListNodeValue(['sk'])),
        Node(
          StringNodeKey('generic'),
          NodeListNodeValue([
            ConfigNode(StringNodeKey('_i69n'), StringListNodeValue(['flag'])),
            Node(StringNodeKey('ok'), StringNodeValue('OK')),
            Node(StringNodeKey('done'), StringNodeValue('DONE')),
            Node(StringNodeKey('letsGo'), StringNodeValue('Let\'s go!')),
            Node(ParametrizedNodeKey('ordinalNumber', [Parameter('n', 'int')]),
                GrammaticalNumberNodeValue("\${_ordinal(n, one: '1st', two: '2nd', few: '3rd', other: '\${n}th')}")),
          ]),
        ),
        Node(
          StringNodeKey('invoice'),
          NodeListNodeValue([
            ConfigNode(StringNodeKey('_i69n'), StringListNodeValue(['noescape', 'nomap'])),
            Node(StringNodeKey('create'), StringNodeValue('Create invoice')),
            Node(StringNodeKey('delete'), StringNodeValue('Delete  invoice')),
            Node(StringNodeKey('help'),
                StringNodeValue('Use this function to generate new invoices and stuff. Awesome!')),
            Node(
              ParametrizedNodeKey('count', [Parameter('cnt', 'int')]),
              GrammaticalNumberNodeValue("You have created \$cnt \${_plural(cnt, one:'invoice', many:'invoices')}."),
            ),
            Node(StringNodeKey('something'), StringNodeValue(r"Let\'s go!")),
          ]),
        ),
        Node(
          StringNodeKey('apples'),
          NodeListNodeValue(
            [
              Node(
                ParametrizedNodeKey('_apples', [Parameter('cnt', 'int')]),
                GrammaticalNumberNodeValue(
                    "\${_plural(cnt, zero: 'no apples', one:'\$cnt apple', many:'\$cnt apples')}"),
              ),
              Node(
                ParametrizedNodeKey('count', [Parameter('cnt', 'int')]),
                StringNodeValue("You have eaten \${_apples(cnt)}."),
              ),
              Node(
                ParametrizedNodeKey('problematic', [Parameter('count', 'int')]),
                GrammaticalNumberNodeValue(
                    "\${_plural(count, zero:'didn\\'t find any tasks', one:'found 1 task', other: 'found \$count tasks')}"),
              ),
              Node(StringNodeKey('anotherProblem'), StringNodeValue('here\nthere')),
              Node(StringNodeKey('quotes'), StringNodeValue('Hello \\\"world\\\"!')),
              Node(StringNodeKey('quotes2'), StringNodeValue('Hello \\"world\\"!')),
            ],
          ),
        ),
        Node(
          StringNodeKey('friends'),
          NodeListNodeValue([
            Node(
                StringNodeKey('michael'),
                NodeListNodeValue([
                  Node(StringNodeKey('name'), StringNodeValue('Aaaaa')),
                  Node(StringNodeKey('description'), StringNodeValue('Aa Aa Aa')),
                ])),
            Node(
                StringNodeKey('eva'),
                NodeListNodeValue([
                  ConfigNode(StringNodeKey('_i69n_implements'), StringListNodeValue(['MichaelFriendsTestMessages'])),
                  Node(StringNodeKey('name'), StringNodeValue('Bbbbb')),
                  Node(StringNodeKey('description'), StringNodeValue('Bb Bb Bb')),
                ])),
          ]),
        ),
      ], [
        Import('dart:io')
      ]);
      ;
      expect(actual.imports, expected.imports);
      expect(actual.metadata, expected.metadata);
      expect(actual.nodes[0], expected.nodes[0]);
      expect(actual.nodes[1], expected.nodes[1]);
      expect(actual.nodes[2], expected.nodes[2]);
      expect(actual.nodes[3], expected.nodes[3]);
      expect(actual.nodes[4], expected.nodes[4]);
      expect(actual.nodes[5], expected.nodes[5]);

      final script = await File('test/mock/testMessages.i69n.g.dart').readAsString();
      expect(actual.build(), script);
    });
  });
}
