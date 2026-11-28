# is_model_vocabulary

The words a call to a language model is described in: the tools it is
offered and the calls it proposes, the turns of the conversation, what it
replies and spends, how hard it is asked to work, and why it stopped. No
provider's JSON, and no `dart:io`. It depends only on `checked_json` and
`is_outcome_vocabulary`.

The model only ever *proposes* a call. A driver returns the proposal, and
the caller runs the action (after the airlock decides) and sends the result
back as a turn. No driver runs a tool.

```dart
import 'package:is_model_vocabulary/is_model_vocabulary.dart';

void main() {
  final effort = Effort.parse('xhigh');
  print(effort?.rank); // 3: its place among the levels this code knows
  print(StopReason.parse('tool_use').continuesLoop); // true
}
```

## What it has

- **`ToolName`**: the name a tool is offered under, 1 to 64 of `a-zA-Z0-9_-`,
  the rule both the Messages API and the Responses API impose. Made with
  `ToolName.of` for a name written in code, or `ToolName.parse`, which
  returns null for a name that breaks it.
- **`OfferedTool`**: a tool as the model is shown it, its `name`,
  `description` and `inputSchema`.
- **`ToolCall`**: one call the model proposed, with its `ToolCallId` (the
  provider's id, echoed back, so parsed loosely), a `CalledToolName` and
  its `ToolInput`. The name is `WellFormedName` or `IllFormedName`, never
  refused: a model can call a tool it wasn't offered, and the caller
  answers that like any other unknown name. The input is the JSON text the
  driver encoded once, passed on byte for byte.
- **`ModelTurn`**: `UserSaid`, `AgentSaid`, `AgentCalledTools` (at least
  one call, with an optional `ProviderContinuation`), `ToolAnswered`,
  whose `ToolResult` is `ToolRan`, `ToolFailed` or `ToolRefused`, or
  `NamedToolsDefined`. `ToolRefused` means nothing ran.
- **`ModelRequest`**: the `tools` the model is shown in full, the
  `namedTools` it knows only by name, and the `turns` so far, encoded to
  the `request` text the airlock hashes. Equal requests encode to equal
  bytes, so a replay matches. A named tool still carries its whole
  definition; a `NamedToolsDefined` turn says where some become defined.
  How a driver carries that out is its own business: Anthropic's can send
  them all up front with `defer_loading` and add them with `tool_addition`,
  while another can list the names in a prompt. Being defined grants
  nothing.
- **`ModelReply`**: `FinishedReply`, `CutOffReply`, or `ProposedToolCalls`
  (the model stopped to have tools run), each with its `ModelUsage`.
- **`ProviderContinuation`**: provider items a call must be followed by,
  such as encrypted reasoning, echoed back unchanged. It is the one part of
  a request nobody but the provider can read: the airlock's hash keeps it
  intact, but an audit of what was sent can't read what it says.

- **`ModelSignInName`** and **`ModelName`**: which of the person's model
  sign-ins a call goes out under (never the secret, which the driver holds)
  and which model it calls, each made only by `parse`. **`ModelAndSignIn`**
  pairs them.
- **`AsksTheModel`**: what a model driver implements. It takes a sign-in,
  a model, and the system prompt and request the airlock approved, verbatim,
  and returns an `Outcome<ModelReply>`, reporting each piece of the reply as
  it streams as a **`ReplyArriving`**, never recorded. **`ModelCall`** is
  those four as the JSON sent to it.

Every `fromJson` is strict: a key it doesn't expect is refused and named.
- **`Effort`**: how hard a model is asked to work. Open, because providers
  add levels; `Effort.known` holds the ones this code knows, lowest first.
- **`ModelEfforts`**: the levels one model takes, and the one it works at
  when a request names none.
- **`StopReason`**: why the model stopped, a closed set with an explicit
  `unknown`, so a reason a provider adds later makes every switch say what
  to do with it.

What a provider's JSON calls each of these, and how a request carries an
effort level, is the provider's client's to say, not this package's.

## License

Apache-2.0.
