import 'dart:convert';

import 'package:checked_json/checked_json.dart';
import 'package:is_model_vocabulary/is_model_vocabulary.dart';
import 'package:test/test.dart';

ToolCall call(String id, String name, String input) => ToolCall(
  id: ToolCallId.parse(id)!,
  name: CalledToolName.fromSent(name),
  input: ToolInput.parse(input)!,
);

void main() {
  group('ToolCallId', () {
    test('takes any id the provider mints, loosely', () {
      for (final raw in ['toolu_01A', 'call_abc', 'fc.x/y:z', 'x' * 1024]) {
        expect(ToolCallId.parse(raw)?.value, raw, reason: raw);
      }
    });

    test('refuses empty, too long, or a control character', () {
      for (final raw in ['', 'x' * 1025, 'a\nb', 'a\x00b', 'a\x7fb']) {
        expect(ToolCallId.parse(raw), isNull, reason: raw);
      }
    });
  });

  group('CalledToolName', () {
    test('a well-formed name carries its ToolName', () {
      final name = CalledToolName.fromSent('fetch_page');
      expect((name as WellFormedName).name, ToolName.of('fetch_page'));
      expect(name.asSent, 'fetch_page');
    });

    test('an ill-formed name is kept exactly, never refused', () {
      final name = CalledToolName.fromSent('functions.fetch page');
      expect(name, isA<IllFormedName>());
      expect(name.asSent, 'functions.fetch page');
    });
  });

  group('ToolInput', () {
    test('keeps the exact text, which decoding and encoding would change', () {
      final input = ToolInput.parse('{"n": 1e3, "s":"\\u00e9"}')!;
      expect(input.text, '{"n": 1e3, "s":"\\u00e9"}');
      expect(input.object.raw('n'), 1000);
    });

    test('takes only a JSON object', () {
      for (final raw in ['[1]', '"s"', '1', 'null', '{', '']) {
        expect(ToolInput.parse(raw), isNull, reason: raw);
      }
    });

    test('refuses a key named twice and an integer past 2^53 - 1', () {
      for (final raw in [
        '{"path":"a","path":"b"}',
        '{"o":{"k":1,"\\u006b":2}}',
        '{"n":9007199254740993}',
      ]) {
        expect(ToolInput.parse(raw), isNull, reason: raw);
      }
    });
  });

  test('ProviderContinuation takes only JSON', () {
    expect(ProviderContinuation.parse('[{"type":"reasoning"}]'), isNotNull);
    expect(ProviderContinuation.parse('not json'), isNull);
    expect(ProviderContinuation.parse('[{"id":"a","id":"b"}]'), isNull);
  });

  group('ModelRequest', () {
    final request = ModelRequest(
      tools: [
        OfferedTool(
          name: ToolName.of('fetch_page'),
          description: 'Fetch a page.',
          inputSchema: JsonObject.of({'type': 'object'}),
        ),
      ],
      turns: [
        const UserSaid('look it up'),
        AgentCalledTools(
          text: 'Let me look.',
          calls: [
            call('toolu_01A', 'fetch_page', '{"url":"https://example.com"}'),
            call('toolu_01B', 'web.fetch', '{}'),
          ],
          continuation: ProviderContinuation.parse('[{"id":"rs_1"}]'),
        ),
        ToolAnswered(
          callId: ToolCallId.parse('toolu_01A')!,
          result: const ToolRan('<html>'),
        ),
        ToolAnswered(
          callId: ToolCallId.parse('toolu_01B')!,
          result: const ToolFailed('no tool named web.fetch'),
        ),
        const AgentSaid('Done.'),
      ],
    );

    test('is the JSON the design names', () {
      expect(jsonDecode(request.encode()), {
        'tools': [
          {
            'name': 'fetch_page',
            'description': 'Fetch a page.',
            'inputSchema': {'type': 'object'},
          },
        ],
        'turns': [
          {'kind': 'user', 'text': 'look it up'},
          {
            'kind': 'agentCalledTools',
            'text': 'Let me look.',
            'calls': [
              {
                'id': 'toolu_01A',
                'name': 'fetch_page',
                'input': '{"url":"https://example.com"}',
              },
              {'id': 'toolu_01B', 'name': 'web.fetch', 'input': '{}'},
            ],
            'continuation': '[{"id":"rs_1"}]',
          },
          {
            'kind': 'toolAnswered',
            'callId': 'toolu_01A',
            'result': {'kind': 'ran', 'text': '<html>'},
          },
          {
            'kind': 'toolAnswered',
            'callId': 'toolu_01B',
            'result': {'kind': 'failed', 'text': 'no tool named web.fetch'},
          },
          {'kind': 'agent', 'text': 'Done.'},
        ],
      });
    });

    test('reads back to the same bytes, so a replay matches', () {
      final text = request.encode();
      expect(ModelRequest.decode(text).encode(), text);
    });

    test('each result kind reads back', () {
      for (final result in const [
        ToolRan('a'),
        ToolFailed('b'),
        ToolRefused('c'),
      ]) {
        final back = ToolResult.fromJson(
          jsonDecode(jsonEncode(result.toJson())),
        );
        expect(jsonEncode(back.toJson()), jsonEncode(result.toJson()));
      }
    });

    test('refuses a key it does not expect, at any depth', () {
      for (final bad in [
        '{"tools":[],"turns":[],"model":"x"}',
        '{"tools":[],"turns":[{"kind":"user","text":"a","role":"user"}]}',
        '{"tools":[],"turns":[{"kind":"toolAnswered","callId":"t",'
            '"result":{"kind":"ran","text":"a","isError":false}}]}',
      ]) {
        expect(
          () => ModelRequest.decode(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    test('refuses a key named twice', () {
      expect(
        () => ModelRequest.decode('{"tools":[],"turns":[],"turns":[]}'),
        throwsFormatException,
      );
    });

    test('refuses the old array of {role, content}', () {
      expect(
        () => ModelRequest.decode('[{"role":"user","content":"hi"}]'),
        throwsFormatException,
      );
    });

    group('named tools', () {
      OfferedTool tool(String name) => OfferedTool(
        name: ToolName.of(name),
        description: 'The $name tool.',
        inputSchema: JsonObject.of({'type': 'object'}),
      );

      final named = ModelRequest(
        tools: [tool('load_tools')],
        namedTools: [tool('read_comments'), tool('read_equations')],
        turns: [
          const UserSaid('what do the reviewers say?'),
          NamedToolsDefined([ToolName.of('read_comments')]),
        ],
      );

      test('are the JSON the design names', () {
        final j = jsonDecode(named.encode());
        expect((j as Map)['namedTools'], [
          tool('read_comments').toJson(),
          tool('read_equations').toJson(),
        ]);
        expect((j['turns'] as List).last, {
          'kind': 'namedToolsDefined',
          'names': ['read_comments'],
        });
      });

      test('read back to the same bytes', () {
        final text = named.encode();
        expect(ModelRequest.decode(text).encode(), text);
      });

      test('leave a request with none as it was', () {
        expect(request.encode(), isNot(contains('namedTools')));
        expect(
          () => ModelRequest.decode('{"tools":[],"namedTools":[],"turns":[]}'),
          throwsFormatException,
        );
      });

      test('refuse a name offered twice, defined or named', () {
        expect(
          () => ModelRequest(
            tools: [tool('a')],
            namedTools: [tool('a')],
            turns: [],
          ),
          throwsArgumentError,
        );
        expect(
          () => ModelRequest(tools: [tool('a'), tool('a')], turns: []),
          throwsArgumentError,
        );
      });

      test('refuse defining a tool not known only by name', () {
        for (final turns in [
          [
            NamedToolsDefined([ToolName.of('load_tools')]),
          ],
          [
            NamedToolsDefined([ToolName.of('nowhere')]),
          ],
          [
            NamedToolsDefined([ToolName.of('read_comments')]),
            NamedToolsDefined([ToolName.of('read_comments')]),
          ],
        ]) {
          expect(
            () => ModelRequest(
              tools: [tool('load_tools')],
              namedTools: [tool('read_comments')],
              turns: turns,
            ),
            throwsArgumentError,
          );
        }
        expect(
          () => ModelRequest.decode(
            '{"tools":[],"turns":[{"kind":"namedToolsDefined",'
            '"names":["x"]}]}',
          ),
          throwsFormatException,
        );
      });

      test('refuse defining none', () {
        expect(() => NamedToolsDefined([]), throwsArgumentError);
        expect(
          () => ModelTurn.fromJson({
            'kind': 'namedToolsDefined',
            'names': <String>[],
          }),
          throwsFormatException,
        );
      });
    });

    test('refuses a turn that calls no tools', () {
      expect(
        () => ModelRequest.decode(
          '{"tools":[],"turns":[{"kind":"agentCalledTools","text":"","calls":[]}]}',
        ),
        throwsFormatException,
      );
      expect(() => AgentCalledTools(text: '', calls: []), throwsArgumentError);
    });
  });

  group('ModelReply', () {
    const usage = ModelUsage(input: 1, cacheRead: 2, output: 3);

    test('the replies that existed before keep their exact JSON', () {
      expect(jsonEncode(const FinishedReply(text: 'hi').toJson()), '"hi"');
      expect(
        jsonEncode(const FinishedReply(text: 'hi', usage: usage).toJson()),
        '{"text":"hi","usage":{"input":1,"cacheRead":2,"output":3,'
        '"cacheCreation":null,"contextWindow":null}}',
      );
      expect(
        jsonEncode(const CutOffReply(text: 'h').toJson()),
        '{"text":"h","incomplete":true}',
      );
    });

    test('each kind reads back', () {
      final proposed = ProposedToolCalls(
        text: '',
        calls: [call('toolu_1', 'Read', '{"path":"a"}')],
        continuation: ProviderContinuation.parse('[]'),
        usage: usage,
      );
      for (final reply in [
        const FinishedReply(text: 'hi'),
        const FinishedReply(text: 'hi', usage: usage),
        const CutOffReply(text: 'h', usage: usage),
        proposed,
      ]) {
        final json = jsonEncode(reply.toJson());
        final back = ModelReply.fromJson(jsonDecode(json));
        expect(back.runtimeType, reply.runtimeType);
        expect(jsonEncode(back.toJson()), json);
      }
    });

    test('proposed calls have no top-level text an older reader could '
        'mistake for a finished reply', () {
      final json =
          ProposedToolCalls(
                text: 'x',
                calls: [call('toolu_1', 'Read', '{}')],
              ).toJson()
              as Map<
                String,
                Object?
              >; // cast-ok: a ProposedToolCalls is an object
      expect(json.keys, ['proposedToolCalls']);
    });

    test('refuses a key it does not expect', () {
      expect(
        () => ModelReply.fromJson({'text': 'hi', 'stop': 'end_turn'}),
        throwsFormatException,
      );
      expect(
        () => ModelReply.fromJson({
          'proposedToolCalls': {
            'text': '',
            'calls': [
              {'id': 't', 'name': 'a', 'input': '{}'},
            ],
          },
          'text': 'hi',
        }),
        throwsFormatException,
      );
    });
  });
}
