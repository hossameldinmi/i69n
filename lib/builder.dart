// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:build/build.dart';
import 'package:i69n/src/shared/file_node.dart';
import 'package:yaml/yaml.dart';

Builder yamlBasedBuilder(BuilderOptions options) => YamlBasedBuilder(options);

Builder jsonBasedBuilder(BuilderOptions options) => JsonBasedBuilder(options);

/// Generates Dart message bundles from `.i69n.yaml` files.
class YamlBasedBuilder implements Builder {
  const YamlBasedBuilder(this.options);

  final BuilderOptions options;

  @override
  Future build(BuildStep buildStep) async {
    var inputId = buildStep.inputId;
    var contents = await buildStep.readAsString(inputId);

    var yamlMap = loadYaml(contents) as Map;
    var fileNode = FileNode.parseMap(inputId.path, yamlMap, globalConfig: options.config);

    var copy = inputId.changeExtension('.dart');
    await buildStep.writeAsString(copy, fileNode.build());
  }

  @override
  final buildExtensions = const {
    '.i69n.yaml': ['.i69n.dart']
  };
}

/// Generates Dart message bundles from `.i69n.json` files.
class JsonBasedBuilder implements Builder {
  const JsonBasedBuilder(this.options);

  final BuilderOptions options;

  @override
  Future build(BuildStep buildStep) async {
    var inputId = buildStep.inputId;
    var contents = await buildStep.readAsString(inputId);

    var jsonMap = json.decode(contents) as Map;
    var fileNode = FileNode.parseMap(inputId.path, jsonMap, globalConfig: options.config);

    var copy = inputId.changeExtension('.dart');
    await buildStep.writeAsString(copy, fileNode.build());
  }

  @override
  final buildExtensions = const {
    '.i69n.json': ['.i69n.dart']
  };
}
