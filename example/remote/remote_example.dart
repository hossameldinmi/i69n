// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:convert';

import 'remoteMessages.i69n.dart';

void main() {
  final m = RemoteMessages();

  // Before any remote data is loaded, accessors resolve to the values baked in
  // at build time (the `_baked` map generated from remoteMessages.i69n.yaml).
  print('--- baked defaults ---');
  print(m.title); // Welcome
  print(m.greeting('Sam')); // Hi Sam
  print(m.apples(1)); // 1 apple
  print(m.apples(3)); // 3 apples
  print(m.home.subtitle); // Home

  // In a real app you would fetch this over HTTP and decode it yourself; i69n
  // adds no networking or YAML dependency to the runtime. Here we simulate the
  // decoded payload with jsonDecode.
  final remotePayload = jsonDecode('''
{
  "title": "Greetings",
  "apples": "\${_plural(count, one: '\$count fruit', other: '\$count fruits')}",
  "home": { "subtitle": "Dashboard" }
}
''') as Map;

  // Inject it into this bundle instance. Loaded values win over the baked
  // defaults; any key the payload omits (e.g. `greeting`) still falls back to
  // baked. Share this one instance across your app (e.g. via an InheritedWidget
  // or a provider) so every screen reads the loaded data.
  m.load(remotePayload);

  print('--- after remote load ---');
  print(m.title); // Greetings  (overridden)
  print(m.greeting('Sam')); // Hi Sam     (still baked)
  print(m.apples(1)); // 1 fruit    (remote plural, resolved per locale)
  print(m.apples(3)); // 3 fruits
  print(m.home.subtitle); // Dashboard

  // Dynamic, string-keyed access works the same as the compile-time API:
  print('--- dynamic keys ---');
  print('Static:  ${m.home.subtitle}');
  print('Dynamic: ${m.home['subtitle']}');
  print('Or even: ${m['home.subtitle']}');
}
