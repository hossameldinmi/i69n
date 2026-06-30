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
  const RemoteMessages();
  String get title =>
      i69n.tr(_localeName, _languageCode, 'title', const {}, _baked);
  String greeting(String name) =>
      i69n.tr(_localeName, _languageCode, 'greeting', {'name': name}, _baked);
  String apples(int count) =>
      i69n.tr(_localeName, _languageCode, 'apples', {'count': count}, _baked);
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
  String get subtitle =>
      i69n.tr(_localeName, _languageCode, 'home.subtitle', const {}, _baked);
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
