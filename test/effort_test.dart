/// Effort: every level in [Effort.known], including one added later, must
/// read back from its own spelling.
library;

import 'package:is_model_vocabulary/is_model_vocabulary.dart';
import 'package:test/test.dart';

void main() {
  test('every known level reads back from its own spelling', () {
    for (final e in Effort.known) {
      expect(Effort.parse(e.wire), e);
    }
  });
}
