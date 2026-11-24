import 'package:checked_json/checked_json.dart';

/// How hard a model is asked to work on a request: how much it reasons, and
/// how much it spends doing it.
///
/// Open: providers add levels (OpenAI's `ultra`, above `max`), so a level is
/// its wire spelling, with the ones this code knows as constants. Which
/// levels a given model takes differs, and a level it rejects fails the
/// request; nothing here is a promise that any model takes a level.
///
/// A request with no effort at all is the provider's own default; that is not
/// a level, so it is a null where this is wanted, never a value.
final class Effort {
  const Effort._(this.wire);

  final String wire;

  static const low = Effort._('low');
  static const medium = Effort._('medium');
  static const high = Effort._('high');
  static const xhigh = Effort._('xhigh');
  static const max = Effort._('max');
  static const ultra = Effort._('ultra');

  /// The levels this code knows, lowest first.
  static const known = [low, medium, high, xhigh, max, ultra];

  /// [wire] as a level: any lowercase word, the way every provider spells
  /// them. Anything else is null, not a level.
  static Effort? parse(Object? wire) =>
      wire is String && _word.hasMatch(wire) ? Effort._(wire) : null;

  static final _word = RegExp(r'^[a-z]+$');

  /// Where this level sorts among [known], lowest first; one this code does
  /// not know sorts after them all.
  int get rank {
    final i = known.indexOf(this);
    return i < 0 ? known.length : i;
  }

  @override
  bool operator ==(Object other) => other is Effort && other.wire == wire;

  @override
  int get hashCode => wire.hashCode;

  @override
  String toString() => wire;
}

/// What one model takes: its [levels], lowest first, and [byDefault], the
/// level it works at when a request names none (null when that is not known).
final class ModelEfforts {
  const ModelEfforts(this.levels, {this.byDefault});
  final List<Effort> levels;
  final Effort? byDefault;

  /// A model that takes no effort.
  static const none = ModelEfforts([]);

  JsonObject toJson() => .of({
    'levels': [for (final e in levels) e.wire],
    'default': ?byDefault?.wire,
  });

  factory ModelEfforts.fromJson(JsonObject j) {
    return ModelEfforts(
      [
        for (final w in j.strings('levels'))
          Effort.parse(w) ??
              (throw JsonFieldException('levels', 'effort levels')),
      ],
      byDefault: switch (j.raw('default')) {
        null => null,
        final w =>
          Effort.parse(w) ?? (throw JsonFieldException('default', 'a level')),
      },
    );
  }
}
