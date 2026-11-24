/// The words a call to a language model is described in: a tool's name and
/// how it is offered, how hard the model is asked to work, and why it
/// stopped.
///
/// Only the words: how a provider spells them in its own JSON belongs to that
/// provider's client.
library;

export 'src/effort.dart';
export 'src/names.dart';
export 'src/offered_tool.dart';
export 'src/stop_reason.dart';
