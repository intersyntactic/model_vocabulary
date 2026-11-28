import 'dart:convert';

import 'package:is_model_vocabulary/is_model_vocabulary.dart';
import 'package:test/test.dart';

void main() {
  final signIn = ModelSignInName.parse('anthropic-api')!;
  final model = ModelName.parse('claude-opus-5-5')!;

  group('ModelSignInName', () {
    test('takes lowercase letters, digits, - and _', () {
      expect(ModelSignInName.parse('anthropic-api')?.name, 'anthropic-api');
      expect(ModelSignInName.parse('seat_2'), isNotNull);
    });

    test('refuses anything else', () {
      for (final raw in ['', 'Not Valid', '-leading', 'a.b', 'ANTHROPIC']) {
        expect(ModelSignInName.parse(raw), isNull, reason: raw);
      }
    });
  });

  group('ModelName', () {
    test('takes any id without whitespace', () {
      expect(ModelName.parse('claude-opus-5-5')?.value, 'claude-opus-5-5');
      expect(ModelName.parse('gpt-5.1'), isNotNull);
    });

    test('refuses blank or whitespace', () {
      for (final raw in ['', 'claude opus', ' x', 'x\n']) {
        expect(ModelName.parse(raw), isNull, reason: raw);
      }
    });
  });

  group('ModelAndSignIn', () {
    final pair = ModelAndSignIn(signIn: signIn, model: model);

    test('is {signIn, model}', () {
      expect(jsonDecode(jsonEncode(pair.toJson())), {
        'signIn': 'anthropic-api',
        'model': 'claude-opus-5-5',
      });
    });

    test('reads back', () {
      expect(
        ModelAndSignIn.fromJson(jsonDecode(jsonEncode(pair.toJson()))),
        pair,
      );
    });

    test('refuses a bad name, a missing field or a key it does not expect', () {
      for (final bad in <Object?>[
        {'signIn': 'Not Valid', 'model': 'claude-opus-5-5'},
        {'signIn': 'anthropic-api', 'model': ''},
        {'signIn': 'anthropic-api'},
        {'signIn': 'anthropic-api', 'model': 'm', 'seat': 'x'},
        'not an object',
      ]) {
        expect(
          () => ModelAndSignIn.fromJson(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });

  group('ReplyArriving', () {
    test('keeps the JSON it had as a kind of Progress', () {
      expect(jsonDecode(jsonEncode(const ReplyArriving('Hel').toJson())), {
        'kind': 'replyArriving',
        'text': 'Hel',
      });
      expect(
        ReplyArriving.fromJson({'kind': 'replyArriving', 'text': 'lo'}).text,
        'lo',
      );
    });

    test('refuses another kind, or a key it does not expect', () {
      for (final bad in <Object?>[
        {'kind': 'printed', 'text': 'a line'},
        {'kind': 'replyArriving', 'text': 'a', 'seq': 1},
        {'kind': 'replyArriving'},
        'not an object',
      ]) {
        expect(
          () => ReplyArriving.fromJson(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });

  group('ModelCall', () {
    const request = '{"tools":[],"turns":[{"kind":"user","text":"hello"}]}';
    final call = ModelCall(
      signIn: signIn,
      model: model,
      systemPrompt: 'be terse',
      request: request,
    );

    test('is {signIn, model, systemPrompt, request}', () {
      expect(jsonDecode(jsonEncode(call.toJson())), {
        'signIn': 'anthropic-api',
        'model': 'claude-opus-5-5',
        'systemPrompt': 'be terse',
        'request': request,
      });
    });

    test('reads back with the request byte for byte', () {
      final back = ModelCall.fromJson(jsonDecode(jsonEncode(call.toJson())));
      expect(back.signIn, signIn);
      expect(back.model, model);
      expect(back.systemPrompt, 'be terse');
      expect(back.request, request);
    });

    test('refuses a missing field, a key it does not expect, or a '
        'non-object', () {
      for (final bad in <Object?>[
        {
          'signIn': 'anthropic-api',
          'model': 'claude-opus-5-5',
          'systemPrompt': 'be terse',
        },
        {
          'signIn': 'anthropic-api',
          'model': 'claude-opus-5-5',
          'systemPrompt': 'be terse',
          'request': 'hello',
          'caller': 'x',
        },
        'not an object',
      ]) {
        expect(
          () => ModelCall.fromJson(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });
}
