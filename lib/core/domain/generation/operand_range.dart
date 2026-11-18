class OperandRange {
  OperandRange({required this.min, required this.max}) {
    if (min > max) {
      throw ArgumentError.value(max, 'max', 'must be greater than or equal to min ($min).');
    }
  }

  final int min;
  final int max;
}
