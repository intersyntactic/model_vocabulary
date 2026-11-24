import 'package:checked_json/checked_json.dart';

import 'names.dart';
import 'only_keys.dart';

/// A tool as the model is shown it: its [name], what it is for, and the
/// JSON Schema its input must match.
final class OfferedTool {
  const OfferedTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final ToolName name;
  final String description;
  final JsonObject inputSchema;

  JsonObject toJson() => .of({
    'name': name.value,
    'description': description,
    'inputSchema': inputSchema.asUncheckedMap(),
  });

  /// [j] as an offered tool; a key it doesn't expect, or a name that breaks
  /// [ToolName]'s rule, is a [JsonFieldException] naming the field.
  factory OfferedTool.fromJson(JsonObject j) {
    onlyKeys(j, const {'name', 'description', 'inputSchema'});
    return OfferedTool(
      name:
          ToolName.parse(j.string('name')) ??
          (throw JsonFieldException('name', 'a tool name')),
      description: j.string('description'),
      inputSchema: j.object('inputSchema'),
    );
  }
}
