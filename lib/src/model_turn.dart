import 'dart:convert';

import 'package:checked_json/checked_json.dart';

import 'names.dart';
import 'offered_tool.dart';
import 'only_keys.dart';
import 'tool_call.dart';

/// What the model hears about one call. The caller decides which, since
/// only it knows what success means for each kind of action; the one fixed
/// rule is that [ToolRefused] means nothing ran.
sealed class ToolResult {
  const ToolResult();

  JsonObject toJson() => switch (this) {
    ToolRan(:final text) => .of({'kind': 'ran', 'text': text}),
    ToolFailed(:final text) => .of({'kind': 'failed', 'text': text}),
    ToolRefused(:final why) => .of({'kind': 'refused', 'why': why}),
  };

  factory ToolResult.fromJson(Object? json) {
    final kind = JsonObject.parse(json)?.stringOrNull('kind');
    // wire-ok: this is the wire; fromJson pairs with toJson above
    return switch (kind) {
      'ran' => ToolRan(
        objectOnly(json, 'a tool result', const {
          'kind',
          'text',
        }).string('text'),
      ),
      'failed' => ToolFailed(
        objectOnly(json, 'a tool result', const {
          'kind',
          'text',
        }).string('text'),
      ),
      'refused' => ToolRefused(
        objectOnly(json, 'a tool result', const {'kind', 'why'}).string('why'),
      ),
      _ => throw JsonFieldException('kind', '"ran", "failed" or "refused"'),
    };
  }
}

/// The tool ran and answered [text].
final class ToolRan extends ToolResult {
  const ToolRan(this.text);

  final String text;
}

/// The tool ran, or may have partly run, and failed; [text] says what
/// already happened.
final class ToolFailed extends ToolResult {
  const ToolFailed(this.text);

  final String text;
}

/// Nothing ran, for [why].
final class ToolRefused extends ToolResult {
  const ToolRefused(this.why);

  final String why;
}

/// One turn of a conversation with the model.
sealed class ModelTurn {
  const ModelTurn();

  JsonObject toJson() => switch (this) {
    UserSaid(:final text) => .of({'kind': 'user', 'text': text}),
    AgentSaid(:final text) => .of({'kind': 'agent', 'text': text}),
    AgentCalledTools(:final text, :final calls, :final continuation) => .of({
      'kind': 'agentCalledTools',
      'text': text,
      'calls': [for (final c in calls) c.toJson()],
      'continuation': ?continuation?.text,
    }),
    ToolAnswered(:final callId, :final result) => .of({
      'kind': 'toolAnswered',
      'callId': callId.value,
      'result': result.toJson(),
    }),
    NamedToolsDefined(:final names) => .of({
      'kind': 'namedToolsDefined',
      'names': [for (final n in names) n.value],
    }),
  };

  factory ModelTurn.fromJson(Object? json) {
    final kind = JsonObject.parse(json)?.stringOrNull('kind');
    // wire-ok: this is the wire; fromJson pairs with toJson above
    switch (kind) {
      case 'user':
        return UserSaid(
          objectOnly(json, 'a turn', const {'kind', 'text'}).string('text'),
        );
      case 'agent':
        return AgentSaid(
          objectOnly(json, 'a turn', const {'kind', 'text'}).string('text'),
        );
      case 'agentCalledTools':
        final j = objectOnly(json, 'a turn', const {
          'kind',
          'text',
          'calls',
          'continuation',
        });
        return AgentCalledTools(
          text: j.string('text'),
          calls: callsFromJson(j),
          continuation: continuationFromJson(j),
        );
      case 'toolAnswered':
        final j = objectOnly(json, 'a turn', const {
          'kind',
          'callId',
          'result',
        });
        return ToolAnswered(
          callId:
              ToolCallId.parse(j.string('callId')) ??
              (throw JsonFieldException('callId', 'a tool call id')),
          result: ToolResult.fromJson(j.object('result')),
        );
      case 'namedToolsDefined':
        final j = objectOnly(json, 'a turn', const {'kind', 'names'});
        final names = [
          for (final n in j.strings('names'))
            ToolName.parse(n) ??
                (throw JsonFieldException('names', 'tool names')),
        ];
        return switch (_namesProblem(names)) {
          null => NamedToolsDefined(names),
          final problem => throw JsonFieldException('names', problem),
        };
      default:
        throw JsonFieldException(
          'kind',
          '"user", "agent", "agentCalledTools", "toolAnswered" or '
              '"namedToolsDefined"',
        );
    }
  }
}

/// The person said [text].
final class UserSaid extends ModelTurn {
  const UserSaid(this.text);

  final String text;
}

/// The model said [text], and called no tools.
final class AgentSaid extends ModelTurn {
  const AgentSaid(this.text);

  final String text;
}

/// The model said [text], possibly empty, and called [calls], never none.
final class AgentCalledTools extends ModelTurn {
  AgentCalledTools({
    required this.text,
    required List<ToolCall> calls,
    this.continuation,
  }) : calls = nonEmptyCalls(calls);

  final String text;
  final List<ToolCall> calls;
  final ProviderContinuation? continuation;
}

/// The answer to the call named [callId].
final class ToolAnswered extends ModelTurn {
  const ToolAnswered({required this.callId, required this.result});

  final ToolCallId callId;
  final ToolResult result;
}

/// From this turn on, the model is shown the full definitions of [names],
/// never none, which until now it knew only by name. It grants nothing: what
/// a tool may do is still the airlock's to decide.
final class NamedToolsDefined extends ModelTurn {
  NamedToolsDefined(List<ToolName> names)
    : names = switch (_namesProblem(names)) {
        null => List.unmodifiable(names),
        final problem => throw ArgumentError.value(names, 'names', problem),
      };

  final List<ToolName> names;
}

/// What is wrong with [names] as the tools one [NamedToolsDefined] defines,
/// or null when nothing is: there is at least one, and none twice.
String? _namesProblem(List<ToolName> names) {
  if (names.isEmpty) return 'not empty';
  final seen = <ToolName>{};
  for (final n in names) {
    if (!seen.add(n)) return '$n listed once';
  }
  return null;
}

/// What is wrong with offering [tools] in full and [namedTools] by name only
/// across [turns], or null when nothing is: each name is offered once, and a
/// [NamedToolsDefined] defines only a tool still known by name alone, right
/// after the person spoke or a tool answered, with no call left unanswered.
String? _disclosureProblem(
  List<OfferedTool> tools,
  List<OfferedTool> namedTools,
  List<ModelTurn> turns,
) {
  final seen = <ToolName>{};
  for (final t in [...tools, ...namedTools]) {
    if (!seen.add(t.name)) return '${t.name} is offered twice';
  }
  final stillNamed = {for (final t in namedTools) t.name};
  final unanswered = <ToolCallId>{};
  ModelTurn? previous;
  for (final turn in turns) {
    switch (turn) {
      case AgentCalledTools(:final calls):
        unanswered.addAll([for (final c in calls) c.id]);
      case ToolAnswered(:final callId):
        unanswered.remove(callId);
      case NamedToolsDefined(:final names):
        // A provider takes a tool change only where a user message could go.
        if (previous is! UserSaid && previous is! ToolAnswered) {
          return 'tools are defined only after the person or a tool answer';
        }
        if (unanswered.isNotEmpty) {
          return 'tools are defined only once every call is answered';
        }
        for (final n in names) {
          if (!stillNamed.remove(n)) {
            return '$n is not a tool known only by name';
          }
        }
      case UserSaid() || AgentSaid():
        break;
    }
    previous = turn;
  }
  return null;
}

/// What a model call's `request` text holds: the [tools] the model is shown
/// in full, the [namedTools] it is told only the names of and may ask to
/// have defined, and the [turns] so far. Tools ride inside it so the
/// airlock's hash of `request` covers what leaves the machine.
///
/// A named tool carries its whole definition all the same: a driver may
/// have to send it up front and only mark it hidden. Which named tools are
/// defined by a given turn is what the [NamedToolsDefined] turns before it
/// say, so the lists here never change within one conversation.
///
/// A turn may still call a tool known only by name: turns record what the
/// model sent, mistakes included, and the loop answers such a call as it
/// would an unknown name.
final class ModelRequest {
  /// The request; a name offered twice, or a [NamedToolsDefined] naming a
  /// tool not still known only by name, is an [ArgumentError].
  factory ModelRequest({
    required List<OfferedTool> tools,
    List<OfferedTool> namedTools = const [],
    required List<ModelTurn> turns,
  }) => switch (_disclosureProblem(tools, namedTools, turns)) {
    null => ModelRequest._(tools, namedTools, turns),
    final problem => throw ArgumentError(problem),
  };

  ModelRequest._(
    List<OfferedTool> tools,
    List<OfferedTool> namedTools,
    List<ModelTurn> turns,
  ) : tools = List.unmodifiable(tools),
      namedTools = List.unmodifiable(namedTools),
      turns = List.unmodifiable(turns);

  final List<OfferedTool> tools;
  final List<OfferedTool> namedTools;
  final List<ModelTurn> turns;

  /// The `request` text. Equal requests encode to equal bytes, since a
  /// replay is matched byte for byte. With no [namedTools], the key is left
  /// out, so a request with none encodes as one did before they existed.
  String encode() => jsonEncode({
    'tools': [for (final t in tools) t.toJson()],
    if (namedTools.isNotEmpty)
      'namedTools': [for (final t in namedTools) t.toJson()],
    'turns': [for (final t in turns) t.toJson()],
  });

  /// [text] read back; a [FormatException] names what is wrong.
  factory ModelRequest.decode(String text) {
    final j = objectOnly(
      decodeJsonRefusingDuplicateKeysAndUnsafeIntegers(text),
      'a model request',
      const {'tools', 'namedTools', 'turns'},
    );
    final tools = [for (final t in j.objects('tools')) OfferedTool.fromJson(t)];
    final namedTools = [
      for (final t in j.objectsOrNull('namedTools') ?? const <JsonObject>[])
        OfferedTool.fromJson(t),
    ];
    if (j.has('namedTools') && namedTools.isEmpty) {
      throw JsonFieldException('namedTools', 'left out when there are none');
    }
    final turns = [for (final t in j.list('turns')) ModelTurn.fromJson(t)];
    return switch (_disclosureProblem(tools, namedTools, turns)) {
      null => ModelRequest._(tools, namedTools, turns),
      final problem => throw FormatException(problem),
    };
  }
}
