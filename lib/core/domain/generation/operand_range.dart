class OperandRange {
  const OperandRange({required this.min, required this.max}) : assert(min <= max);

  final int min;
  final int max;
}
