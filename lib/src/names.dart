/// The name a tool is offered to the model under: 1 to 64 of `a-z`, `A-Z`,
/// `0-9`, `_` and `-`, the rule both the Messages API and the Responses API
/// impose. Only for names we make; a name the model sends back may be
/// anything.
final class ToolName {
  const ToolName._(this.value);

  /// [raw] as a tool name, or null when it breaks the rule.
  static ToolName? parse(String raw) =>
      _rule.hasMatch(raw) ? ToolName._(raw) : null;

  static final _rule = RegExp(r'^[a-zA-Z0-9_-]{1,64}$');

  final String value;

  @override
  bool operator ==(Object other) => other is ToolName && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
