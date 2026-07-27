import 'package:build/build.dart';
import 'package:i69n/builder.dart';
import 'package:test/test.dart';

void main() {
  test('jsoncBasedBuilder factory yields a builder for .i69n.jsonc', () {
    final builder = jsoncBasedBuilder(BuilderOptions.empty);
    expect(builder, isA<JsoncBasedBuilder>());
    expect(builder.buildExtensions, {
      '.i69n.jsonc': ['.i69n.dart'],
    });
  });
}
