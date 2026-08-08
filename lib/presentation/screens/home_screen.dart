import 'package:flutter/material.dart';

import '../../core/domain/generation/arithmetic_generator.dart';
import '../../core/domain/generation/local_exercise_source.dart';
import '../../core/domain/models/operation_type.dart';
import '../../core/domain/models/session_config.dart';
import '../../core/state/session_controller.dart';
import '../../core/state/session_state.dart';
import 'result_screen.dart';
import 'session_screen.dart';

const _exercisesPerSession = 10;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SessionController _controller = _createController();

  SessionController _createController() {
    final seed = DateTime.now().millisecondsSinceEpoch;
    return SessionController(
      config: SessionConfig(
        seed: seed,
        operationTypes: OperationType.values,
        exerciseCount: _exercisesPerSession,
      ),
      exerciseSource: LocalExerciseSource(
        generator: ArithmeticExerciseGenerator(operationTypes: OperationType.values),
        seed: seed,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return switch (_controller.state.status) {
              SessionStatus.notStarted => _StartView(onStart: _controller.start),
              SessionStatus.inProgress => SessionScreen(controller: _controller),
              SessionStatus.finished => ResultScreen(controller: _controller),
            };
          },
        ),
      ),
    );
  }
}

class _StartView extends StatelessWidget {
  const _StartView({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Math Trainer', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          FilledButton(onPressed: onStart, child: const Text('Commencer')),
        ],
      ),
    );
  }
}
