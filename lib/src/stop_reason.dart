/// Why the model stopped.
///
/// A closed set with an explicit unknown member: a caller switches on this,
/// and a reason a provider ships later must make the compiler name every
/// switch rather than fall through a default into "assume we're done".
/// Falling through is the dangerous direction: it ends a conversation the
/// provider expected to continue.
enum StopReason {
  /// The model finished its turn.
  endTurn('end_turn'),

  /// It wants tools run, and is waiting for their results. The only value
  /// after which the conversation goes on by itself.
  toolUse('tool_use'),

  /// Output limit hit mid-thought. The turn is genuinely incomplete; resuming
  /// is a decision for the caller, not something to paper over.
  maxTokens('max_tokens'),

  stopSequence('stop_sequence'),

  /// A long-running server-side turn that may be resumed.
  pauseTurn('pause_turn'),

  /// The one value a provider gives details of why for.
  refusal('refusal'),

  contextWindowExceeded('model_context_window_exceeded'),

  /// A value this code has never seen. Not an error and not [endTurn]: the
  /// caller decides.
  unknown('');

  const StopReason(this.wire);
  final String wire;

  static StopReason parse(String? raw) {
    if (raw == null) return StopReason.unknown;
    for (final r in StopReason.values) {
      if (r.wire == raw && r != StopReason.unknown) return r;
    }
    return StopReason.unknown;
  }

  /// Whether the conversation goes on by itself: another request, carrying
  /// the tools' results. Exhaustive on purpose: adding a member above forces
  /// a decision here rather than inheriting one.
  bool get continuesLoop => switch (this) {
    StopReason.toolUse => true,
    StopReason.endTurn ||
    StopReason.maxTokens ||
    StopReason.stopSequence ||
    StopReason.pauseTurn ||
    StopReason.refusal ||
    StopReason.contextWindowExceeded ||
    StopReason.unknown => false,
  };
}
