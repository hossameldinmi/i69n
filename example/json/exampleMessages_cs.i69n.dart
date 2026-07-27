// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'exampleMessages.i69n.dart';
import '../gender.dart';

String get _languageCode => 'cs';
String get _localeName => 'cs';

String _plural(int count, {String? zero, String? one, String? two, String? few, String? many, String? other}) =>
    i69n.plural(count, _languageCode, zero: zero, one: one, two: two, few: few, many: many, other: other);
String _select(Object? value, Map<String, String> cases) => i69n.select(value, cases);

class ExampleMessages_cs extends ExampleMessages {
  const ExampleMessages_cs();
  GenericExampleMessages_cs get generic => GenericExampleMessages_cs(this);
  InvoiceExampleMessages_cs get invoice => InvoiceExampleMessages_cs(this);
  ApplesExampleMessages_cs get apples => ApplesExampleMessages_cs(this);
  PersonExampleMessages_cs get person => PersonExampleMessages_cs(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'generic':
        return generic;
      case 'invoice':
        return invoice;
      case 'apples':
        return apples;
      case 'person':
        return person;
      default:
        return super[key];
    }
  }
}

class GenericExampleMessages_cs extends GenericExampleMessages {
  final ExampleMessages_cs _parent;
  const GenericExampleMessages_cs(this._parent) : super(_parent);
  String get done => "Hotovo";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'done':
        return done;
      default:
        return super[key];
    }
  }
}

class InvoiceExampleMessages_cs extends InvoiceExampleMessages {
  final ExampleMessages_cs _parent;
  const InvoiceExampleMessages_cs(this._parent) : super(_parent);
  String get create => "Vytvořit fakturu";
  String get delete => "Smazat fakturu";
  String get help => "Tuhle funkci použij na vytváření faktur. Boží!";
  String count(int a) => "Už jsi vytvořil ${_plural(a, one: 'fakturu', few: 'faktury', many: 'faktur')}.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'create':
        return create;
      case 'delete':
        return delete;
      case 'help':
        return help;
      case 'count':
        return count;
      default:
        return super[key];
    }
  }
}

class ApplesExampleMessages_cs extends ApplesExampleMessages {
  final ExampleMessages_cs _parent;
  const ApplesExampleMessages_cs(this._parent) : super(_parent);
  String _apples(int cnt) =>
      "${_plural(cnt, zero: 'fakt málo jablek', one: 'jedno jablko', few: '$cnt jablka', many: '$cnt jablek')}";
  String count(int cnt) => "Snědl jsi ${_apples(cnt)}.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case '_apples':
        return _apples;
      case 'count':
        return count;
      default:
        return super[key];
    }
  }
}

class PersonExampleMessages_cs extends PersonExampleMessages {
  final ExampleMessages_cs _parent;
  const PersonExampleMessages_cs(this._parent) : super(_parent);
  String sees(Gender gender) => "Vidím ${_select(gender, {'male': 'ho', 'female': 'ji', 'other': 'je'})}.";
  String owns(Gender gender, int cnt) => "${_select(gender, {
            'male': 'Jeho',
            'female': 'Její',
            'other': 'Jejich'
          })} ${_plural(cnt, one: 'jablko', few: 'jablka', many: 'jablek')}.";
  String status(bool online) => "${_select(online, {'true': 'Právě online', 'false': 'Naposledy před chvílí'})}";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'sees':
        return sees;
      case 'owns':
        return owns;
      case 'status':
        return status;
      default:
        return super[key];
    }
  }
}
