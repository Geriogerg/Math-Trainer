import 'package:flutter/material.dart';

import '../../core/state/session_controller.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final _answerController = TextEditingController();

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _submit() {
    final value = num.tryParse(_answerController.text);
    if (value == null) return;
    widget.controller.submitAnswer(value);
    _answerController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final exercise = state.currentExercise;
    if (exercise == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final lastOutcome = state.outcomes.isEmpty ? null : state.outcomes.last;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Score : ${state.score}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 24,
            child: lastOutcome == null
                ? null
                : Text(
                    lastOutcome.isCorrect
                        ? 'Correct !'
                        : 'Faux, la réponse était ${lastOutcome.exercise.correctAnswer}',
                    style: TextStyle(
                      color: lastOutcome.isCorrect ? colorScheme.primary : colorScheme.error,
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Text(exercise.prompt, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 24),
          TextField(
            controller: _answerController,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            textAlign: TextAlign.center,
            autofocus: true,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: const Text('Valider')),
        ],
      ),
    );
  }
}
