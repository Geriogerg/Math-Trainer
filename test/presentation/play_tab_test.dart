import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:math_trainer/core/domain/persistence/type_selection_store.dart';
import 'package:math_trainer/presentation/screens/play_tab.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

/// Store en mémoire — pas d'infrastructure de test partagée pour une seule
/// classe de quelques lignes (convention du projet).
class _FakeTypeSelectionStore implements TypeSelectionStore {
  Set<ExerciseType>? stored;

  @override
  Future<Set<ExerciseType>?> load() async => stored;

  @override
  Future<void> save(Set<ExerciseType> types) async => stored = types;
}

void main() {
  Future<void> pumpPlayTab(WidgetTester tester, AppEnvironment environment) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildLightTheme(), home: Scaffold(body: PlayTab(environment: environment))),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('une sélection déjà enregistrée remplace le défaut au démarrage', (tester) async {
    final store = _FakeTypeSelectionStore()
      ..stored = {ExerciseType.multiplication, ExerciseType.division};
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      typeSelectionStore: store,
    );

    await pumpPlayTab(tester, environment);

    FilterChip chipFor(String label) =>
        tester.widget<FilterChip>(find.ancestor(of: find.text(label), matching: find.byType(FilterChip)));

    expect(chipFor('Multiplication').selected, isTrue);
    expect(chipFor('Division').selected, isTrue);
    expect(chipFor('Addition').selected, isFalse);
    expect(chipFor('Soustraction').selected, isFalse);
  });

  testWidgets('sans historique, une sélection préenregistrée absente laisse le défaut', (
    tester,
  ) async {
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      typeSelectionStore: _FakeTypeSelectionStore(),
    );

    await pumpPlayTab(tester, environment);

    FilterChip chipFor(String label) =>
        tester.widget<FilterChip>(find.ancestor(of: find.text(label), matching: find.byType(FilterChip)));

    expect(chipFor('Addition').selected, isTrue);
    expect(chipFor('Soustraction').selected, isTrue);
  });

  testWidgets('changer une puce persiste la nouvelle sélection dans le store', (tester) async {
    final store = _FakeTypeSelectionStore();
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      typeSelectionStore: store,
    );

    await pumpPlayTab(tester, environment);
    await tester.tap(find.text('Multiplication'));
    await tester.pumpAndSettle();

    expect(store.stored, {ExerciseType.addition, ExerciseType.subtraction, ExerciseType.multiplication});

    // Une deuxième instance pointant sur le même store retrouve le changement.
    final secondEnvironment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      typeSelectionStore: store,
    );
    await pumpPlayTab(tester, secondEnvironment);

    final chip = tester.widget<FilterChip>(
      find.ancestor(of: find.text('Multiplication'), matching: find.byType(FilterChip)),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('sans historique : phrase d\'accueil, pas de niveau global', (tester) async {
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      typeSelectionStore: _FakeTypeSelectionStore(),
    );

    await pumpPlayTab(tester, environment);

    expect(find.text('La difficulté s\'ajuste à vos réponses.'), findsOneWidget);
    expect(find.textContaining('Niveau global'), findsNothing);
  });

  testWidgets('avec historique : niveau global affiché, pas la phrase d\'accueil', (tester) async {
    final repository = InMemorySessionRepository();
    await repository.recordSession(
      session: PersistedSession(
        id: 'session-1',
        playerId: 'test-player',
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: 4,
        totalScore: 40,
        levels: const {ExerciseType.addition: 1},
        createdAt: DateTime.utc(2026, 8, 8),
      ),
      answers: const [],
      levelUpdates: {
        ExerciseType.addition: LevelCacheEntry(
          level: 42,
          sessionsPlayed: 1,
          updatedAt: DateTime.utc(2026, 8, 8),
        ),
      },
    );
    final environment = AppEnvironment(
      repository: repository,
      playerId: 'test-player',
      typeSelectionStore: _FakeTypeSelectionStore(),
    );

    await pumpPlayTab(tester, environment);

    // (42 + 6 × 1 plancher pour les 6 types non joués) / 7 ≈ 6,86 → 7.
    expect(find.text('Niveau global : 7'), findsOneWidget);
    expect(find.text('La difficulté s\'ajuste à vos réponses.'), findsNothing);
  });
}
