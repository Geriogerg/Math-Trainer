import 'dart:math';

/// A whole number in [min, max], both included. Throws on an empty range
/// (rule 13): a tier's ranges are built so that never happens.
int drawBetween(Random random, int min, int max) {
  if (max < min) {
    throw ArgumentError.value((min, max), 'range', 'is empty.');
  }
  return min + random.nextInt(max - min + 1);
}

/// One of [values], uniformly. Never drawn from a `Set` (rule 2).
T drawOne<T>(Random random, List<T> values) {
  if (values.isEmpty) throw ArgumentError.value(values, 'values', 'is empty.');
  return values[random.nextInt(values.length)];
}

/// Heads or tails: which of a tier's two forms a question takes.
bool drawCoin(Random random) => random.nextInt(2) == 0;
