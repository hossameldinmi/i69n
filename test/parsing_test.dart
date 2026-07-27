import 'package:i69n/src/shared/file.dart';
import 'package:i69n/src/shared/file_node.dart';
import 'package:i69n/src/shared/file_metadata.dart';
import 'package:i69n/src/shared/node.dart';
import 'package:test/test.dart';
import 'mock/fixture.dart';

void main() {
  test('testMessages.i69n', () async {
    await Fixture.testParsing('testMessages', (filePath, actual) async {
      final fileMetadata = FileMetadata(LocaleFile(filePath), true, 'en', 'sk');
      final fileKey = NodeKey('TestMessages', null, fileMetadata);
      final genericKey = NodeKey('generic', fileKey, fileMetadata);
      final invoiceKey = NodeKey('invoice', fileKey, fileMetadata);
      final applesKey = NodeKey('apples', fileKey, fileMetadata);
      final friendsKey = NodeKey('friends', fileKey, fileMetadata);
      final michaelKey = NodeKey('michael', friendsKey, fileMetadata);
      final evaKey = NodeKey('eva', friendsKey, fileMetadata);
      final expected = FileNode(
        fileKey,
        NodeListNodeValue([
          ConfigNode(NodeKey('_i69n_import', fileKey, fileMetadata), StringListNodeValue(['dart:io'])),
          ConfigNode(NodeKey('_i69n_language', fileKey, fileMetadata), StringListNodeValue(['sk'])),
          Node(
            genericKey,
            NodeListNodeValue([
              ConfigNode(NodeKey('_i69n', genericKey, fileMetadata), StringListNodeValue(['flag'])),
              Node(NodeKey('ok', genericKey, fileMetadata), StringNodeValue('OK')),
              Node(NodeKey('done', genericKey, fileMetadata), StringNodeValue('DONE')),
              Node(NodeKey('letsGo', genericKey, fileMetadata), StringNodeValue('Let\'s go!')),
              Node(
                  ParametrizedNodeKey('ordinalNumber', genericKey, [Parameter('n', 'int')], fileMetadata),
                  GrammaticalNumberNodeValue(
                    "\${_ordinal(n, one: '1st', two: '2nd', few: '3rd', other: '\${n}th')}",
                    GrammaticalNumberType.ordinal,
                  )),
            ]),
          ),
          Node(
            invoiceKey,
            NodeListNodeValue([
              ConfigNode(NodeKey('_i69n', invoiceKey, fileMetadata), StringListNodeValue(['noescape', 'nomap'])),
              Node(NodeKey('create', invoiceKey, fileMetadata), StringNodeValue('Create invoice')),
              Node(NodeKey('delete', invoiceKey, fileMetadata), StringNodeValue('Delete  invoice')),
              Node(NodeKey('help', invoiceKey, fileMetadata),
                  StringNodeValue('Use this function to generate new invoices and stuff. Awesome!')),
              Node(
                ParametrizedNodeKey('count', invoiceKey, [Parameter('cnt', 'int')], fileMetadata),
                GrammaticalNumberNodeValue(
                  "You have created \$cnt \${_plural(cnt, one:'invoice', many:'invoices')}.",
                  GrammaticalNumberType.plural,
                ),
              ),
              Node(NodeKey('something', invoiceKey, fileMetadata), StringNodeValue(r"Let\'s go!")),
            ]),
          ),
          Node(
            applesKey,
            NodeListNodeValue(
              [
                Node(
                  ParametrizedNodeKey('_apples', applesKey, [Parameter('cnt', 'int')], fileMetadata),
                  GrammaticalNumberNodeValue(
                    "\${_plural(cnt, zero: 'no apples', one:'\$cnt apple', many:'\$cnt apples')}",
                    GrammaticalNumberType.plural,
                  ),
                ),
                Node(
                  ParametrizedNodeKey('count', applesKey, [Parameter('cnt', 'int')], fileMetadata),
                  StringNodeValue("You have eaten \${_apples(cnt)}."),
                ),
                Node(
                  ParametrizedNodeKey('problematic', applesKey, [Parameter('count', 'int')], fileMetadata),
                  GrammaticalNumberNodeValue(
                    "\${_plural(count, zero:'didn\\'t find any tasks', one:'found 1 task', other: 'found \$count tasks')}",
                    GrammaticalNumberType.plural,
                  ),
                ),
                Node(NodeKey('anotherProblem', applesKey, fileMetadata), StringNodeValue('here\nthere')),
                Node(NodeKey('quotes', applesKey, fileMetadata), StringNodeValue('Hello \\\"world\\\"!')),
                Node(NodeKey('quotes2', applesKey, fileMetadata), StringNodeValue('Hello \\"world\\"!')),
              ],
            ),
          ),
          Node(
            friendsKey,
            NodeListNodeValue([
              Node(
                  michaelKey,
                  NodeListNodeValue([
                    Node(NodeKey('name', michaelKey, fileMetadata), StringNodeValue('Aaaaa')),
                    Node(NodeKey('description', michaelKey, fileMetadata), StringNodeValue('Aa Aa Aa')),
                  ])),
              Node(
                  evaKey,
                  NodeListNodeValue([
                    ConfigNode(NodeKey('_i69n_implements', evaKey, fileMetadata),
                        StringListNodeValue(['MichaelFriendsTestMessages'])),
                    Node(NodeKey('name', evaKey, fileMetadata), StringNodeValue('Bbbbb')),
                    Node(NodeKey('description', evaKey, fileMetadata), StringNodeValue('Bb Bb Bb')),
                  ])),
            ]),
          ),
        ]),
        fileMetadata,
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
      if (filePath.endsWith('.yaml')) {
        // The apples group holds the quote-escaping cases. Their RAW values
        // legitimately differ per format — YAML uses the manual-escaping
        // convention, JSON is natural text escaped at build time — so the tree
        // comparison is YAML-only. The generated-script comparison below still
        // proves both formats build the identical Dart.
        expect(actual.value.value[4], expected.value.value[4]);
      }
      expect(actual.value.value[5], expected.value.value[5]);

      final expectedScript = await Fixture.getFileFormattedContent('test/mock/testMessages.i69n.g.dart');
      final actualScript = actual.build();
      expect(actualScript, expectedScript);
    });
  });
}
