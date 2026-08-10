import 'package:flutter/material.dart';

import '../../composition_root.dart';
import '../../core/domain/leveling/level_cache_entry.dart';
import '../../core/domain/models/exercise_type.dart';
import '../exercise_type_labels.dart';

/// Affiche le niveau actuel par opération (`SessionRepository.
/// currentLevels`), tel qu'il alimentera la prochaine session — jamais un
/// score, qui reste un retour de session sans valeur de classement (voir
/// `doc/decisions.md`).
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.environment});

  final AppEnvironment environment;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late final Future<Map<ExerciseType, LevelCacheEntry>> _levels;

  @override
  void initState() {
    super.initState();
    _levels = widget.environment.repository.currentLevels(widget.environment.playerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progression')),
      body: SafeArea(
        child: FutureBuilder<Map<ExerciseType, LevelCacheEntry>>(
          future: _levels,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final levels = snapshot.data!;
            return ListView(
              children: [
                for (final type in ExerciseType.values)
                  ListTile(
                    title: Text(exerciseTypeLabel(type)),
                    trailing: Text(
                      levels[type] == null ? 'Non joué' : 'Niveau ${levels[type]!.level}',
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
