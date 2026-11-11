/// The words a call to a language model is described in: the model it names,
/// a tool's name, how hard it is asked to work, and why it stopped.
///
/// Only the words: how a provider spells them in its own JSON belongs to that
/// provider's client.
library;

export 'src/effort.dart';
export 'src/names.dart';
export 'src/stop_reason.dart';
