/// The words a call to a language model is described in: the tools it is
/// offered and the calls it proposes, the turns of the conversation, what it
/// replies and spends, how hard it is asked to work, and why it stopped.
///
/// Only the words: how a provider spells them in its own JSON belongs to that
/// provider's client.
library;

export 'src/effort.dart';
export 'src/model_call.dart';
export 'src/model_names.dart' show ModelAndSignIn, ModelName, ModelSignInName;
export 'src/model_reply.dart';
export 'src/model_turn.dart';
export 'src/names.dart';
export 'src/offered_tool.dart';
export 'src/stop_reason.dart';
export 'src/tool_call.dart'
    show
        CalledToolName,
        IllFormedName,
        ProviderContinuation,
        ToolCall,
        ToolCallId,
        ToolInput,
        WellFormedName;
