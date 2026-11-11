# is_model_vocabulary

The words a call to a language model is described in: the model it names, a
tool's name, how hard it is asked to work, and why it stopped. No provider's
JSON, and no `dart:io`.

```dart
import 'package:is_model_vocabulary/is_model_vocabulary.dart';

void main() {
  final effort = Effort.parse('xhigh');
  print(effort?.rank); // 3: its place among the levels this code knows
  print(StopReason.parse('tool_use').continuesLoop); // true
}
```

## What it has

- **`ModelId`** and **`ToolName`**: a model and a tool as the provider names
  them.
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
