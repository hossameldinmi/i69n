import 'dart:convert';
import 'dart:io';

import 'package:i69n/src/shared/file_node.dart';
import 'package:jsonc/jsonc.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The YAML and JSON inputs under example/ describe the same messages, so the
/// generator must produce byte-identical Dart from either format, across the
/// default locale and both locale variants.
void main() {
  for (final locale in ['', '_cs', '_en_GB']) {
    test('yaml and json produce identical Dart for exampleMessages$locale', () {
      final yamlPath = 'example/yaml/exampleMessages$locale.i69n.yaml';
      final jsonPath = 'example/json/exampleMessages$locale.i69n.json';

      final fromYaml = FileNode.parseMap(yamlPath, loadYaml(File(yamlPath).readAsStringSync()) as Map).build();
      final fromJson = FileNode.parseMap(jsonPath, json.decode(File(jsonPath).readAsStringSync()) as Map).build();

      expect(fromJson, fromYaml);
    });

    test('yaml and jsonc produce identical Dart for exampleMessages$locale', () {
      final yamlPath = 'example/yaml/exampleMessages$locale.i69n.yaml';
      final jsoncPath = 'example/jsonc/exampleMessages$locale.i69n.jsonc';

      final fromYaml = FileNode.parseMap(yamlPath, loadYaml(File(yamlPath).readAsStringSync()) as Map).build();
      final fromJsonc = FileNode.parseMap(jsoncPath, jsonc.decode(File(jsoncPath).readAsStringSync()) as Map).build();

      expect(fromJsonc, fromYaml);
    });
  }
}
