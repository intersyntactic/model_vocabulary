import 'package:checked_json/checked_json.dart';

/// Throws a [JsonFieldException] naming the first key of [j] not in [keys]:
/// every decoder here is strict.
void onlyKeys(JsonObject j, Set<String> keys) {
  for (final key in j.keys) {
    if (!keys.contains(key)) throw JsonFieldException(key, 'no such key');
  }
}
