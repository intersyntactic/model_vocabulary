import 'package:checked_json/checked_json.dart';

import 'only_keys.dart';

/// One of the person's model sign-ins, by name, such as `anthropic-api`.
/// Never the secret: the driver holds that, so it reaches neither a tool
/// nor the logbook.
final class ModelSignInName {
  const ModelSignInName._(this.name);

  /// [raw] as a model sign-in's name, or null unless it is lowercase
  /// letters, digits, `-` and `_`, starting with a letter or digit.
  static ModelSignInName? parse(String raw) =>
      _rule.hasMatch(raw) ? ModelSignInName._(raw) : null;

  static final _rule = RegExp(r'^[a-z0-9][a-z0-9_-]*$');

  final String name;

  @override
  bool operator ==(Object other) =>
      other is ModelSignInName && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// A model this machine can call, by id, such as `claude-opus-5-5`.
final class ModelName {
  const ModelName._(this.value);

  /// [raw] as a model's id, or null when it is blank or holds whitespace.
  static ModelName? parse(String raw) =>
      raw.isEmpty || raw.contains(RegExp(r'\s')) ? null : ModelName._(raw);

  final String value;

  @override
  bool operator ==(Object other) => other is ModelName && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// A [model] and the [signIn] it is called under, such as a starting
/// model a trajectory begins with.
final class ModelAndSignIn {
  const ModelAndSignIn({required this.signIn, required this.model});

  final ModelSignInName signIn;
  final ModelName model;

  JsonObject toJson() => .of({'signIn': signIn.name, 'model': model.value});

  /// [json] as a model and sign-in; a key it doesn't expect, or a name that
  /// breaks its rule, is a [FormatException] naming the field.
  factory ModelAndSignIn.fromJson(Object? json) {
    final j = objectOnly(json, 'a model and sign-in', const {
      'signIn',
      'model',
    });
    return ModelAndSignIn(signIn: signInFromJson(j), model: modelFromJson(j));
  }

  @override
  bool operator ==(Object other) =>
      other is ModelAndSignIn && other.signIn == signIn && other.model == model;

  @override
  int get hashCode => Object.hash(signIn, model);

  @override
  String toString() => '$model under $signIn';
}

/// [j]'s `signIn`, refused when it isn't a model sign-in's name.
ModelSignInName signInFromJson(JsonObject j) =>
    ModelSignInName.parse(j.string('signIn')) ??
    (throw JsonFieldException('signIn', 'a model sign-in'));

/// [j]'s `model`, refused when it isn't a model's id.
ModelName modelFromJson(JsonObject j) =>
    ModelName.parse(j.string('model')) ??
    (throw JsonFieldException('model', 'a model id'));
