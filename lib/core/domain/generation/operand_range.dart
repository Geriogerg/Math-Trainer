class OperandRange {
  OperandRange({required this.min, required this.max}) {
    if (min > max) {
      throw ArgumentError.value(max, 'max', 'doit être supérieur ou égal à min ($min).');
    }
  }

  final int min;
  final int max;
}
