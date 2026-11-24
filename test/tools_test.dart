import 'dart:convert';

import 'package:checked_json/checked_json.dart';
import 'package:is_model_vocabulary/is_model_vocabulary.dart';
import 'package:test/test.dart';

void main() {
  group('ToolName', () {
    test('takes 1 to 64 of a-zA-Z0-9_-', () {
      for (final raw in ['a', 'fetch_page', 'Read-2', 'x' * 64]) {
        expect(ToolName.parse(raw)?.value, raw, reason: raw);
      }
    });

    test('refuses anything else', () {
      for (final raw in [
        '',
        'x' * 65,
        'web.fetch',
        'mcp__server__tool:x',
        'has space',
        'naïve',
      ]) {
        expect(ToolName.parse(raw), isNull, reason: raw);
      }
    });

    test('of builds a name written in code, and names a bad one', () {
      expect(
        ToolName.of('list_case_folder'),
        ToolName.parse('list_case_folder'),
      );
      expect(
        () => ToolName.of('list.case'),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.invalidValue, 'invalidValue', 'list.case')
              .having((e) => e.message, 'message', contains('a-zA-Z0-9_-')),
        ),
      );
    });

    test('is equal by its text', () {
      expect(ToolName.parse('a'), ToolName.parse('a'));
      expect(ToolName.parse('a'), isNot(ToolName.parse('b')));
    });
  });

  group('OfferedTool', () {
    final tool = OfferedTool(
      name: ToolName.parse('fetch_page')!,
      description: 'Fetch a page.',
      inputSchema: JsonObject.of({
        'type': 'object',
        'properties': {
          'url': {'type': 'string'},
        },
      }),
    );

    test('writes camelCase keys, the schema as it is', () {
      expect(
        jsonEncode(tool.toJson()),
        '{"name":"fetch_page","description":"Fetch a page.",'
        '"inputSchema":{"type":"object","properties":{"url":{"type":"string"}}}}',
      );
    });

    test('round-trips through its JSON text', () {
      final back = OfferedTool.fromJson(
        JsonObject.decode(jsonEncode(tool.toJson())),
      );
      expect(back.name, tool.name);
      expect(back.description, tool.description);
      expect(jsonEncode(back.toJson()), jsonEncode(tool.toJson()));
    });

    test('refuses a key it does not expect, naming it', () {
      expect(
        () => OfferedTool.fromJson(
          JsonObject.of({...tool.toJson().asUncheckedMap(), 'strict': true}),
        ),
        throwsA(
          isA<JsonFieldException>().having((e) => e.field, 'field', 'strict'),
        ),
      );
    });

    test('refuses a name that breaks the rule', () {
      expect(
        () => OfferedTool.fromJson(
          JsonObject.of({
            ...tool.toJson().asUncheckedMap(),
            'name': 'web.fetch',
          }),
        ),
        throwsA(
          isA<JsonFieldException>().having((e) => e.field, 'field', 'name'),
        ),
      );
    });
  });

  test('Effort is a value, not any string', () {
    expect(Effort.parse('xhigh'), Effort.xhigh);
    expect(Effort.parse('xhigh').hashCode, Effort.xhigh.hashCode);
    expect(Effort.parse('Loud'), isNull);
  });
}
