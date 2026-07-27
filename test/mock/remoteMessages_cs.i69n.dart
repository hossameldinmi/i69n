// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'remoteMessages.i69n.dart';

String get _languageCode => 'cs';
String get _localeName => 'cs';

const Map<String, String> _baked = {
  'apples':
      "\${_plural(count, one: '\$count jablko', few: '\$count jablka', other: '\$count jablek')}",
  'home.subtitle': "Domov",
};

class RemoteMessages_cs extends RemoteMessages {
  RemoteMessages_cs();
  String apples(int count) => i69n.tr(
      i69nRemoteMessages, _baked, 'apples', {'count': count}, _languageCode);
  HomeRemoteMessages_cs get home => HomeRemoteMessages_cs(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'apples':
        return apples;
      case 'home':
        return home;
      default:
        return super[key];
    }
  }
}

class HomeRemoteMessages_cs extends HomeRemoteMessages {
  final RemoteMessages_cs _parent;
  const HomeRemoteMessages_cs(this._parent) : super(_parent);
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
        return super[key];
    }
  }
}
