// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

const Map<String, String> _baked = {
  'title': "Welcome",
  'greeting': "Hi \$name",
  'apples': "\${_plural(count, one: '\$count apple', other: '\$count apples')}",
  'home.subtitle': "Home",
};

class RemoteMessages implements i69n.I69nMessageBundle {
  RemoteMessages();
  final Map<String, String> _data = {};
  void load(Map data) {
    _data
      ..clear()
      ..addAll(i69n.flattenMessages(data));
  }

  Map<String, String> get _messages => _data;
  String get title =>
      i69n.tr(_messages, _baked, 'title', const {}, _languageCode);
  String greeting(String name) =>
      i69n.tr(_messages, _baked, 'greeting', {'name': name}, _languageCode);
  String apples(int count) =>
      i69n.tr(_messages, _baked, 'apples', {'count': count}, _languageCode);
  HomeRemoteMessages get home => HomeRemoteMessages(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'greeting':
        return greeting;
      case 'apples':
        return apples;
      case 'home':
        return home;
      default:
        return key;
    }
  }
}

class HomeRemoteMessages implements i69n.I69nMessageBundle {
  final RemoteMessages _parent;
  const HomeRemoteMessages(this._parent);
  Map<String, String> get _messages => _parent._messages;
  String get subtitle =>
      i69n.tr(_messages, _baked, 'home.subtitle', const {}, _languageCode);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'subtitle':
        return subtitle;
      default:
        return key;
    }
  }
}
