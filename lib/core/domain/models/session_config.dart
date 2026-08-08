import 'operation_type.dart';

class SessionConfig {
  const SessionConfig({
    required this.seed,
    required this.operationTypes,
    required this.exerciseCount,
  });

  final int seed;
  final List<OperationType> operationTypes;
  final int exerciseCount;
}
