import 'package:flutter/material.dart';

import '../../composition_root.dart';
import '../../core/domain/models/exercise_type.dart';
import '../../core/state/session_controller.dart';
import '../../core/state/session_state.dart';
import '../exercise_type_labels.dart';
import 'progress_screen.dart';
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
  bool _isStarting = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() => _isStarting = true);
    final controller = await buildSessionController(widget.environment, _selectedTypes);
    if (!mounted) return;
    controller.start();
    setState(() {
      _controller = controller;
      _isStarting = false;
    });
  }

  void _backToSelection() {
    _controller?.dispose();
    setState(() => _controller = null);
  }

  void _openProgress() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ProgressScreen(environment: widget.environment)));
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
                onStart: _selectedTypes.isEmpty || _isStarting ? null : _startSession,
                isStarting: _isStarting,
                onOpenProgress: _openProgress,
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
    required this.isStarting,
    required this.onOpenProgress,
  });

  final Set<ExerciseType> selectedTypes;
  final ValueChanged<Set<ExerciseType>> onChanged;
  final VoidCallback? onStart;
  final bool isStarting;
  final VoidCallback onOpenProgress;

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
                    label: Text(exerciseTypeLabel(type)),
                    selected: selectedTypes.contains(type),
                    onSelected: (selected) => _toggle(type, selected),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onStart,
              child: isStarting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Commencer'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onOpenProgress, child: const Text('Voir ma progression')),
          ],
        ),
      ),
    );
  }
}
