import 'package:checked_json/checked_json.dart';

import 'only_keys.dart';
import 'tool_call.dart';

/// What one model call spent. [input], [cacheRead] and [output] are what
/// every driver checked so far can report; [cacheCreation] is null for a
/// driver that can't tell it apart from [input] (ChatGPT's plan has no
/// such count). [contextWindow] is the model's own limit, null when the
/// driver can't tell it (ChatGPT's plan doesn't say).
final class ModelUsage {
  const ModelUsage({
    required this.input,
    required this.cacheRead,
    required this.output,
    this.cacheCreation,
    this.contextWindow,
  });

  final int input;
  final int cacheRead;
  final int output;
  final int? cacheCreation;
  final int? contextWindow;

  /// What counts against [contextWindow]: [input] and [cacheRead] (already
  /// in context) plus whatever this call newly wrote into the cache.
  /// Never [output]: a reply's tokens leave with the reply, not the
  /// context.
  int get context => input + cacheRead + (cacheCreation ?? 0);

  JsonObject toJson() => .of({
    'input': input,
    'cacheRead': cacheRead,
    'output': output,
    'cacheCreation': cacheCreation,
    'contextWindow': contextWindow,
  });

  factory ModelUsage.fromJson(Object? json) {
    final j = objectOnly(json, 'model usage', const {
      'input',
      'cacheRead',
      'output',
      'cacheCreation',
      'contextWindow',
    });
    return ModelUsage(
      input: j.integer('input'),
      cacheRead: j.integer('cacheRead'),
      output: j.integer('output'),
      cacheCreation: j.integerOrNull('cacheCreation'),
      contextWindow: j.integerOrNull('contextWindow'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ModelUsage &&
      other.input == input &&
      other.cacheRead == cacheRead &&
      other.output == output &&
      other.cacheCreation == cacheCreation &&
      other.contextWindow == contextWindow;

  @override
  int get hashCode =>
      Object.hash(input, cacheRead, output, cacheCreation, contextWindow);
}

/// What one model call answered, recorded once as its outcome.
///
/// A closed set, so every reader says which it means: a cut-off reply isn't
/// the model's full word, and a proposal of tools isn't its last.
sealed class ModelReply {
  const ModelReply({required this.text, this.usage});

  /// The model's text: whole if [FinishedReply], only as far as the call
  /// got if [CutOffReply], what it said before its calls if
  /// [ProposedToolCalls].
  final String text;

  /// What the call spent, when the driver can report it. Null for a
  /// driver that can't, and for every reply recorded before usage existed.
  final ModelUsage? usage;

  /// The reply's JSON. A finished reply with no usage is a bare string, as
  /// every reply was before usage existed.
  ///
  /// A [ProposedToolCalls] nests under `proposedToolCalls`, with no `text`
  /// beside it: a reader built before it existed reads any object with a
  /// `text` as a finished reply, so it has to fail on this one instead.
  Object? toJson() => switch (this) {
    FinishedReply(:final text, usage: null) => text,
    FinishedReply(:final text, :final usage) ||
    CutOffReply(:final text, :final usage) => {
      'text': text,
      'usage': ?usage?.toJson(),
      if (this is CutOffReply) 'incomplete': true,
    },
    ProposedToolCalls(
      :final text,
      :final calls,
      :final continuation,
      :final usage,
    ) =>
      {
        'proposedToolCalls': {
          'text': text,
          'calls': [for (final c in calls) c.toJson()],
          'continuation': ?continuation?.text,
          'usage': ?usage?.toJson(),
        },
      },
  };

  static ModelReply fromJson(Object? json) {
    if (json case final String text) return FinishedReply(text: text);
    final outer = JsonObject.parse(json);
    if (outer != null && outer.has('proposedToolCalls')) {
      onlyKeys(outer, const {'proposedToolCalls'});
      final j = objectOnly(
        outer.raw('proposedToolCalls'),
        'proposed tool calls',
        const {'text', 'calls', 'continuation', 'usage'},
      );
      return ProposedToolCalls(
        text: j.string('text'),
        calls: callsFromJson(j),
        continuation: continuationFromJson(j),
        usage: _usage(j),
      );
    }
    final j = objectOnly(json, 'a model reply', const {
      'text',
      'usage',
      'incomplete',
    });
    final text = j.string('text');
    final usage = _usage(j);
    return j.booleanOrNull('incomplete') ?? false
        ? CutOffReply(text: text, usage: usage)
        : FinishedReply(text: text, usage: usage);
  }

  static ModelUsage? _usage(JsonObject j) => switch (j.raw('usage')) {
    null => null,
    final usage => ModelUsage.fromJson(usage),
  };
}

/// The model was done: [text] is its whole reply.
final class FinishedReply extends ModelReply {
  const FinishedReply({required super.text, super.usage});
}

/// The call ran and spent tokens, but [text] ends before the model was
/// done.
final class CutOffReply extends ModelReply {
  const CutOffReply({required super.text, super.usage});
}

/// The model stopped to have [calls] run, never none, and waits for their
/// results; nothing has run. [text] is what it said first, possibly empty.
final class ProposedToolCalls extends ModelReply {
  ProposedToolCalls({
    required super.text,
    required List<ToolCall> calls,
    this.continuation,
    super.usage,
  }) : calls = nonEmptyCalls(calls);

  final List<ToolCall> calls;
  final ProviderContinuation? continuation;
}
