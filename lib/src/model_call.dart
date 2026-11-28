import 'package:checked_json/checked_json.dart';
import 'package:is_action_outcome_vocabulary/is_action_outcome_vocabulary.dart';

import 'model_names.dart';
import 'model_reply.dart';
import 'only_keys.dart';

/// One call to the model, as it is sent to whatever [AsksTheModel]: the
/// [signIn] and [model] the airlock decided on, and the [systemPrompt] and
/// [request] it approved, each the exact bytes, verbatim.
final class ModelCall {
  const ModelCall({
    required this.signIn,
    required this.model,
    required this.systemPrompt,
    required this.request,
  });

  final ModelSignInName signIn;
  final ModelName model;
  final String systemPrompt;
  final String request;

  JsonObject toJson() => .of({
    'signIn': signIn.name,
    'model': model.value,
    'systemPrompt': systemPrompt,
    'request': request,
  });

  /// [json] as a model call; a missing field, a key it doesn't expect, or a
  /// name that breaks its rule is a [FormatException] naming the field. So
  /// a field added here must reach every driver before anything sends it.
  factory ModelCall.fromJson(Object? json) {
    final j = objectOnly(json, 'a model call', const {
      'signIn',
      'model',
      'systemPrompt',
      'request',
    });
    return ModelCall(
      signIn: signInFromJson(j),
      model: modelFromJson(j),
      systemPrompt: j.string('systemPrompt'),
      request: j.string('request'),
    );
  }
}

/// Calls the model. Holds every model sign-in: the model is outside the
/// station, so the loop that proposes a call reaches it only through here,
/// never directly. [systemPrompt] and [request] are each the exact bytes
/// the airlock has approved, verbatim; [report] carries each
/// [ReplyArriving] piece as it streams, never recorded, until the whole
/// [ModelReply] is. A reply cut off or proposing tools is still [Ran]:
/// tokens were spent and a reply came back.
///
/// When [request] itself names a model, that name must be [model], or the
/// driver refuses without calling: the airlock decided on [model], so the
/// logbook must not show one thing decided and another called.
abstract interface class AsksTheModel {
  Future<Outcome<ModelReply>> askTheModel(
    ModelSignInName signIn,
    ModelName model,
    String systemPrompt,
    String request, {
    required Report report,
  });
}
