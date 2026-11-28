# Changelog

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
