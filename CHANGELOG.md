# Changelog

## 0.5.0

- **Breaking:** `ModelTurn` has a fifth case, `NamedToolsDefined`, so an
  exhaustive switch over it needs a new arm.
- `ModelRequest.namedTools`: tools the model is told only the names of,
  each with its full definition, so a driver that hides a tool rather than
  leaving it out (Anthropic's `defer_loading`) has what it must send. A
  `NamedToolsDefined` turn marks where some of them become defined, in the
  conversation rather than by changing the lists, so a driver can add them
  without editing what it already sent. Neither grants anything.
- `ModelRequest` refuses a name offered twice, and a `NamedToolsDefined`
  naming a tool not still known only by name, listing one twice, or coming
  anywhere but right after the person spoke or a tool answered with every
  call answered. A request with no named tools encodes to the same bytes as
  before.
- A 0.4 reader refuses `namedTools` and the new turn, so anything that reads
  a request moves to 0.5 before any loop writes a named tool.
- From `is_effects`: `ModelSignInName`, `ModelName`, `ModelAndSignIn`, the
  `AsksTheModel` interface (no longer marking itself `CarriesOutActions`),
  and the envelope sent to it, now a `ModelCall` class. Each reads and
  writes JSON the way this package does: `ModelAndSignIn` and `ModelCall`
  have `toJson` and a strict `fromJson`, and the two names are written as
  their strings and read with `parse`. Unlike `is_effects`'
  `decodeModelCall`, `ModelCall.fromJson` refuses a key it doesn't expect, so if `ModelCall` ever gains a field, the drivers must be deployed before the airlock sends it.
- Depends on `is_action_outcome_vocabulary` ^0.1.0, for the `Outcome` and
  `Report` that `AsksTheModel` speaks in.

## 0.4.0

- **Breaking:** on `checked_json` ^0.4.0. Every `JsonObject` this package
  hands out or takes, such as `OfferedTool.inputSchema`, `ToolInput.object`
  and each `toJson`, can't be changed at any depth, and two of them are
  equal when their fields are equal. A dependent has to move to
  `checked_json` ^0.4.0 as well.

## 0.3.0

- **Breaking:** on `checked_json` ^0.3.0. `ToolInput.parse`,
  `ProviderContinuation.parse` and `ModelRequest.decode` refuse text that
  names a key twice in one object, or has an integer past 2^53 - 1, where
  they used to keep the last value without a word.

## 0.2.0

- The tools vocabulary of
  https://github.com/intersyntactic/effects/issues/30: `ToolCallId`,
  `CalledToolName` (`WellFormedName`, `IllFormedName`), `ToolInput`,
  `ProviderContinuation`, `ToolCall`, `ToolResult` (`ToolRan`,
  `ToolFailed`, `ToolRefused`), `ModelTurn` (`UserSaid`, `AgentSaid`,
  `AgentCalledTools`, `ToolAnswered`) and `ModelRequest`, the `request`
  text a model call carries.
- `ModelReply` and `ModelUsage` move here from `is_effects`, which
  re-exports them, and `ModelReply` gains `ProposedToolCalls`. The replies
  that existed keep their exact JSON. `ProposedToolCalls` nests under
  `proposedToolCalls` with no `text` beside it, so a reader built before it
  existed refuses it instead of reading it as a finished reply.

## 0.1.0

- `ToolName`, a name a tool is offered under, made only by `parse`.
- `OfferedTool`: a tool as the model is shown it, with `toJson` and a strict
  `fromJson`.
- `Effort`, `ModelEfforts` and `StopReason`.
