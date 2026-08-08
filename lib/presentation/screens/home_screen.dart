import 'package:flutter/material.dart';

import '../../composition_root.dart';
import '../../core/domain/models/exercise_type.dart';
import '../../core/state/session_controller.dart';
import '../../core/state/session_state.dart';
import 'result_screen.dart';
import 'session_screen.dart';

const _defaultSelectedTypes = {
  ExerciseType.addition,
  ExerciseType.subtraction,
  ExerciseType.multiplication,
  ExerciseType.division,
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.environment});

  final AppEnvironment environment;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SessionController? _controller;
  Set<ExerciseType> _selectedTypes = {..._defaultSelectedTypes};

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _startSession() {
    final controller = buildSessionController(widget.environment, _selectedTypes);
    controller.start();
    setState(() => _controller = controller);
  }

  void _backToSelection() {
    _controller?.dispose();
    setState(() => _controller = null);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      body: SafeArea(
        child: controller == null
            ? _TypeSelectionView(
                selectedTypes: _selectedTypes,
                onChanged: (types) => setState(() => _selectedTypes = types),
                onStart: _selectedTypes.isEmpty ? null : _startSession,
              )
            : ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  return switch (controller.state.status) {
                    // N'arrive jamais en pratique : start() est appelé avant
                    // le premier build (voir _startSession). Géré quand même
                    // pour l'exhaustivité du switch (règle 11).
                    SessionStatus.notStarted => const SizedBox.shrink(),
                    SessionStatus.inProgress => SessionScreen(controller: controller),
                    SessionStatus.finished => ResultScreen(
                      controller: controller,
                      onRestart: _backToSelection,
                    ),
                  };
                },
              ),
      ),
    );
  }
}

class _TypeSelectionView extends StatelessWidget {
  const _TypeSelectionView({
    required this.selectedTypes,
    required this.onChanged,
    required this.onStart,
  });

  final Set<ExerciseType> selectedTypes;
  final ValueChanged<Set<ExerciseType>> onChanged;
  final VoidCallback? onStart;

  void _toggle(ExerciseType type, bool selected) {
    final updated = Set<ExerciseType>.of(selectedTypes);
    if (selected) {
      updated.add(type);
    } else {
      updated.remove(type);
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Math Trainer', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final type in ExerciseType.values)
                  FilterChip(
                    label: Text(_labelFor(type)),
                    selected: selectedTypes.contains(type),
                    onSelected: (selected) => _toggle(type, selected),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onStart, child: const Text('Commencer')),
          ],
        ),
      ),
    );
  }
}

String _labelFor(ExerciseType type) => switch (type) {
  ExerciseType.addition => 'Addition',
  ExerciseType.subtraction => 'Soustraction',
  ExerciseType.multiplication => 'Multiplication',
  ExerciseType.division => 'Division',
  ExerciseType.power => 'Puissances',
  ExerciseType.squareRoot => 'Racines carrées',
  ExerciseType.percentage => 'Pourcentages',
};
