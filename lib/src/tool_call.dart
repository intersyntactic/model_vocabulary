import 'package:checked_json/checked_json.dart';

import 'names.dart';
import 'only_keys.dart';

/// The id a provider mints for one call (Claude's `toolu_…`, the Responses
/// API's `call_…`), echoed back with its result and compared byte for byte.
///
/// Loose on purpose: we never mint these, only echo them, so a rule
/// stricter than the provider's could only refuse a real reply. Any text
/// of 1 to 1,024 characters with no control characters.
final class ToolCallId {
  const ToolCallId._(this.value);

  /// [raw] as a call id, or null when it is empty, too long, or carries a
  /// control character.
  static ToolCallId? parse(String raw) =>
      raw.isNotEmpty && raw.length <= 1024 && !raw.contains(_control)
      ? ToolCallId._(raw)
      : null;

  static final _control = RegExp(r'[\x00-\x1f\x7f]');

  final String value;

  @override
  bool operator ==(Object other) => other is ToolCallId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// The name a model called a tool by, which may not be one it was offered,
/// nor even one that could be offered. Whether a [WellFormedName] was
/// offered is the caller's to look up; either way an unknown name is
/// answered, never a reason to refuse the whole reply.
sealed class CalledToolName {
  const CalledToolName();

  /// [asSent], the model's exact text, as one of the two.
  factory CalledToolName.fromSent(String asSent) =>
      switch (ToolName.parse(asSent)) {
        final name? => WellFormedName._(name),
        null => IllFormedName._(asSent),
      };

  /// The model's exact text, replayed unchanged.
  String get asSent;
}

/// A name that keeps [ToolName]'s rule, so it may be one that was offered.
final class WellFormedName extends CalledToolName {
  const WellFormedName._(this.name);

  final ToolName name;

  @override
  String get asSent => name.value;
}

/// A name no tool could be offered under, such as `web.fetch`.
final class IllFormedName extends CalledToolName {
  const IllFormedName._(this.asSent);

  @override
  final String asSent;
}

/// The input the model sent with a call, kept as the JSON text the driver
/// encoded it to once, and never encoded again: every hop after the driver
/// passes these exact bytes, which is what the airlock approved and what a
/// replay has to repeat.
final class ToolInput {
  const ToolInput._(this.text);

  /// [text] as a call's input, or null unless it is a JSON object.
  static ToolInput? parse(String text) {
    try {
      JsonObject.decode(text);
      return ToolInput._(text);
    } on FormatException {
      return null;
    }
  }

  final String text;

  /// The input, decoded.
  JsonObject get object => JsonObject.decode(text);

  @override
  bool operator ==(Object other) => other is ToolInput && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// Provider items a call must be followed by, such as the Responses API's
/// encrypted `reasoning` items, kept as their exact JSON text and echoed
/// back unchanged.
///
/// The only part of a request no one but the provider can read: the
/// airlock's hash covers its integrity, but an operator auditing what was
/// sent cannot read what it says.
final class ProviderContinuation {
  const ProviderContinuation._(this.text);

  /// [text] as a continuation, or null unless it is JSON.
  static ProviderContinuation? parse(String text) {
    try {
      decodeJsonRefusingDuplicateKeysAndUnsafeIntegers(text);
      return ProviderContinuation._(text);
    } on FormatException {
      return null;
    }
  }

  final String text;

  @override
  bool operator ==(Object other) =>
      other is ProviderContinuation && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// One call the model proposed: nothing has run.
final class ToolCall {
  const ToolCall({required this.id, required this.name, required this.input});

  final ToolCallId id;
  final CalledToolName name;
  final ToolInput input;

  JsonObject toJson() =>
      .of({'id': id.value, 'name': name.asSent, 'input': input.text});

  factory ToolCall.fromJson(Object? json) {
    final j = objectOnly(json, 'a tool call', const {'id', 'name', 'input'});
    return ToolCall(
      id:
          ToolCallId.parse(j.string('id')) ??
          (throw JsonFieldException('id', 'a tool call id')),
      name: CalledToolName.fromSent(j.string('name')),
      input:
          ToolInput.parse(j.string('input')) ??
          (throw JsonFieldException('input', 'a JSON object as text')),
    );
  }
}

/// [calls] as a list that can't be empty or changed: a turn or reply that
/// proposes tools proposes at least one.
List<ToolCall> nonEmptyCalls(List<ToolCall> calls) => calls.isEmpty
    ? throw ArgumentError.value(calls, 'calls', 'no calls')
    : List.unmodifiable(calls);

/// [j]'s `calls`, refused when there are none.
List<ToolCall> callsFromJson(JsonObject j) {
  final calls = [for (final c in j.list('calls')) ToolCall.fromJson(c)];
  return calls.isEmpty ? throw JsonFieldException('calls', 'not empty') : calls;
}

/// [j]'s optional `continuation`.
ProviderContinuation? continuationFromJson(JsonObject j) =>
    switch (j.stringOrNull('continuation')) {
      null => null,
      final text =>
        ProviderContinuation.parse(text) ??
            (throw JsonFieldException('continuation', 'JSON as text')),
    };
