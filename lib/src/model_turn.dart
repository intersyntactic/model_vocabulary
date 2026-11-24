import 'dart:convert';

import 'package:checked_json/checked_json.dart';

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
      default:
        throw JsonFieldException(
          'kind',
          '"user", "agent", "agentCalledTools" or "toolAnswered"',
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

/// What a model call's `request` text holds: the [tools] offered and the
/// [turns] so far. Tools ride inside it so the airlock's hash of `request`
/// covers what leaves the machine.
final class ModelRequest {
  ModelRequest({
    required List<OfferedTool> tools,
    required List<ModelTurn> turns,
  }) : tools = List.unmodifiable(tools),
       turns = List.unmodifiable(turns);

  final List<OfferedTool> tools;
  final List<ModelTurn> turns;

  /// The `request` text. Equal requests encode to equal bytes, since a
  /// replay is matched byte for byte.
  String encode() => jsonEncode({
    'tools': [for (final t in tools) t.toJson()],
    'turns': [for (final t in turns) t.toJson()],
  });

  /// [text] read back; a [FormatException] names what is wrong.
  factory ModelRequest.decode(String text) {
    final j = objectOnly(jsonDecode(text), 'a model request', const {
      'tools',
      'turns',
    });
    return ModelRequest(
      tools: [for (final t in j.objects('tools')) OfferedTool.fromJson(t)],
      turns: [for (final t in j.list('turns')) ModelTurn.fromJson(t)],
    );
  }
}
