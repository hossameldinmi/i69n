import 'package:i69n/src/v2/shared/file.dart';
import 'package:i69n/src/v2/shared/file_node.dart';
import 'package:i69n/src/v2/shared/file_metadata.dart';
import 'package:i69n/src/v2/shared/node.dart';
import 'package:test/test.dart';
import 'mock/fixture.dart';

void main() {
  test('testMessages.i69n', () async {
    await Fixture.testParsing('testMessages', (filePath, actual) async {
      final expected = FileNode(
        'testMessages',
        NodeListNodeValue([
          ConfigNode(NodeKey('_i69n_import'), StringListNodeValue(['dart:io'])),
          ConfigNode(NodeKey('_i69n_language'), StringListNodeValue(['sk'])),
          Node(
            NodeKey('generic'),
            NodeListNodeValue([
              ConfigNode(NodeKey('_i69n'), StringListNodeValue(['flag'])),
              Node(NodeKey('ok'), StringNodeValue('OK')),
              Node(NodeKey('done'), StringNodeValue('DONE')),
              Node(NodeKey('letsGo'), StringNodeValue('Let\'s go!')),
              Node(
                  ParametrizedNodeKey('ordinalNumber', [Parameter('n', 'int')]),
                  GrammaticalNumberNodeValue(
                    "\${_ordinal(n, one: '1st', two: '2nd', few: '3rd', other: '\${n}th')}",
                    GrammaticalNumberType.ordinal,
                  )),
            ]),
          ),
          Node(
            NodeKey('invoice'),
            NodeListNodeValue([
              ConfigNode(NodeKey('_i69n'), StringListNodeValue(['noescape', 'nomap'])),
              Node(NodeKey('create'), StringNodeValue('Create invoice')),
              Node(NodeKey('delete'), StringNodeValue('Delete  invoice')),
              Node(NodeKey('help'), StringNodeValue('Use this function to generate new invoices and stuff. Awesome!')),
              Node(
                ParametrizedNodeKey('count', [Parameter('cnt', 'int')]),
                GrammaticalNumberNodeValue(
                  "You have created \$cnt \${_plural(cnt, one:'invoice', many:'invoices')}.",
                  GrammaticalNumberType.plural,
                ),
              ),
              Node(NodeKey('something'), StringNodeValue(r"Let\'s go!")),
            ]),
          ),
          Node(
            NodeKey('apples'),
            NodeListNodeValue(
              [
                Node(
                  ParametrizedNodeKey('_apples', [Parameter('cnt', 'int')]),
                  GrammaticalNumberNodeValue(
                    "\${_plural(cnt, zero: 'no apples', one:'\$cnt apple', many:'\$cnt apples')}",
                    GrammaticalNumberType.plural,
                  ),
                ),
                Node(
                  ParametrizedNodeKey('count', [Parameter('cnt', 'int')]),
                  StringNodeValue("You have eaten \${_apples(cnt)}."),
                ),
                Node(
                  ParametrizedNodeKey('problematic', [Parameter('count', 'int')]),
                  GrammaticalNumberNodeValue(
                    "\${_plural(count, zero:'didn\\'t find any tasks', one:'found 1 task', other: 'found \$count tasks')}",
                    GrammaticalNumberType.plural,
                  ),
                ),
                Node(NodeKey('anotherProblem'), StringNodeValue('here\nthere')),
                Node(NodeKey('quotes'), StringNodeValue('Hello \\\"world\\\"!')),
                Node(NodeKey('quotes2'), StringNodeValue('Hello \\"world\\"!')),
              ],
            ),
          ),
          Node(
            NodeKey('friends'),
            NodeListNodeValue([
              Node(
                  NodeKey('michael'),
                  NodeListNodeValue([
                    Node(NodeKey('name'), StringNodeValue('Aaaaa')),
                    Node(NodeKey('description'), StringNodeValue('Aa Aa Aa')),
                  ])),
              Node(
                  NodeKey('eva'),
                  NodeListNodeValue([
                    ConfigNode(NodeKey('_i69n_implements'), StringListNodeValue(['MichaelFriendsTestMessages'])),
                    Node(NodeKey('name'), StringNodeValue('Bbbbb')),
                    Node(NodeKey('description'), StringNodeValue('Bb Bb Bb')),
                  ])),
            ]),
          ),
        ]),
        FileMetadata(LocaleFile(filePath), true, 'en', 'sk'),
        [
          Import('dart:io'),
        ],
        [],
      );
      ;
      expect(actual.imports, expected.imports);
      expect(actual.metadata, expected.metadata);
      expect(actual.value.value[0], expected.value.value[0]);
      expect(actual.value.value[1], expected.value.value[1]);
      expect(actual.value.value[2], expected.value.value[2]);
      expect(actual.value.value[3], expected.value.value[3]);
      expect(actual.value.value[4], expected.value.value[4]);
      expect(actual.value.value[5], expected.value.value[5]);

      final expectedScript = await Fixture.getFileFormattedContent('test/mock/testMessages.i69n.g.dart');
      final actualScript = actual.build();
      expect(actualScript, expectedScript);
    });
  });
}
