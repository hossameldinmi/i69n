// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'gender.dart';

String get _languageCode => 'en';
String get _localeName => 'en';

const Map<String, String> _baked = {
  'title': "Welcome",
  'greeting': "Hi \$name",
  'apples': "\${_plural(count, one: '\$count apple', other: '\$count apples')}",
  'sees':
      "I see \${_select(gender, male: 'Him', female: 'Her', other: 'Them')}",
  'home.subtitle': "Home",
};

class RemoteMessages implements i69n.I69nMessageBundle {
  RemoteMessages();
  final Map<String, String> i69nRemoteData = {};
  void load(Map data) {
    i69nRemoteData
      ..clear()
      ..addAll(i69n.flattenMessages(data));
  }

  Map<String, String> get i69nRemoteMessages => i69nRemoteData;
  String get title =>
      i69n.tr(i69nRemoteMessages, _baked, 'title', const {}, _languageCode);
  String greeting(String name) => i69n.tr(
      i69nRemoteMessages, _baked, 'greeting', {'name': name}, _languageCode);
  String apples(int count) => i69n.tr(
      i69nRemoteMessages, _baked, 'apples', {'count': count}, _languageCode);
  String sees(Gender gender) => i69n.tr(
      i69nRemoteMessages, _baked, 'sees', {'gender': gender}, _languageCode);
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
      case 'sees':
        return sees;
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
  Map<String, String> get i69nRemoteMessages => _parent.i69nRemoteMessages;
  String get subtitle => i69n.tr(
      i69nRemoteMessages, _baked, 'home.subtitle', const {}, _languageCode);
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
