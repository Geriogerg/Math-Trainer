import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/persistence/persisted_answer.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:math_trainer/core/domain/persistence/session_repository.dart';
import 'package:math_trainer/presentation/screens/progress_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';

/// Échoue tant que [shouldFail] est vrai, réussit ensuite — simule un
/// réseau/disque qui se rétablit, pour tester le bouton « Réessayer ».
class _FlakySessionRepository implements SessionRepository {
  bool shouldFail = true;

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(
    String playerId,
  ) async {
    if (shouldFail) throw Exception('échec simulé');
    return {
      ExerciseType.addition: LevelCacheEntry(
        level: 7,
        sessionsPlayed: 1,
        updatedAt: DateTime.utc(2026, 8, 8),
      ),
    };
  }

  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) => throw UnimplementedError();

  @override
  Future<List<PersistedSession>> recentSessions({int limit = 20}) async {
    if (shouldFail) throw Exception('échec simulé');
    return [];
  }

  @override
  Future<List<PersistedAnswer>> answersForSession(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<Map<ExerciseType, double>> averageElapsedMsByType(
    String playerId,
  ) async {
    if (shouldFail) throw Exception('échec simulé');
    return {};
  }

  @override
  Future<List<PersistedSession>> sessionsSince(
    String playerId,
    DateTime since,
  ) async {
    if (shouldFail) throw Exception('échec simulé');
    return [];
  }
}

void main() {
  // Écran désormais plus long (4 blocs, commit E) : une fenêtre de test trop
  // courte laisserait les dernières lignes de la ventilation par opération
  // hors du viewport initial, donc absentes de `find.text()` sans scroll.
  Future<void> setTallSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets(
    'affiche les 7 types, un niveau connu et "Non joué" pour les autres',
    (WidgetTester tester) async {
      await setTallSurface(tester);
      final repository = InMemorySessionRepository();
      await repository.recordSession(
        session: PersistedSession(
          id: 'session-1',
          playerId: 'test-player',
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 8,
          totalScore: 80,
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
        accountRepository: FakeAccountRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: ProgressScreen(environment: environment)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Niveau 42'), findsOneWidget);
      expect(find.text('Non joué'), findsNWidgets(6));
      for (final type in ExerciseType.values) {
        expect(find.text(_labelFor(type)), findsOneWidget);
      }
    },
  );

  testWidgets(
    'redevenir actif après une session recharge les niveaux (IndexedStack ne '
    'reconstruit pas le widget)',
    (WidgetTester tester) async {
      await setTallSurface(tester);
      final repository = InMemorySessionRepository();
      final environment = AppEnvironment(
        repository: repository,
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
      );

      Future<void> pump(bool isActive) => tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: ProgressScreen(environment: environment, isActive: isActive),
          ),
        ),
      );

      await pump(false);
      await tester.pumpAndSettle();
      expect(find.text('Non joué'), findsNWidgets(7));

      await repository.recordSession(
        session: PersistedSession(
          id: 'session-1',
          playerId: 'test-player',
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 8,
          totalScore: 80,
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

      // Toujours inactif : pas de rechargement, la vue reste celle d'avant la session.
      await pump(false);
      await tester.pumpAndSettle();
      expect(find.text('Non joué'), findsNWidgets(7));

      // Transition inactif → actif : didUpdateWidget doit relancer le chargement.
      await pump(true);
      await tester.pumpAndSettle();

      expect(find.text('Niveau 42'), findsOneWidget);
      expect(find.text('Non joué'), findsNWidgets(6));
    },
  );

  testWidgets(
    'un repository qui échoue affiche un message et un bouton Réessayer',
    (WidgetTester tester) async {
      await setTallSurface(tester);
      final repository = _FlakySessionRepository();
      final environment = AppEnvironment(
        repository: repository,
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: ProgressScreen(environment: environment)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Impossible de charger la progression.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Réessayer'), findsOneWidget);
    },
  );

  testWidgets(
    'Réessayer relance la lecture et affiche la progression si elle réussit',
    (WidgetTester tester) async {
      await setTallSurface(tester);
      final repository = _FlakySessionRepository();
      final environment = AppEnvironment(
        repository: repository,
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: ProgressScreen(environment: environment)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Impossible de charger la progression.'),
        findsOneWidget,
      );

      repository.shouldFail = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Impossible de charger la progression.'), findsNothing);
      expect(find.text('Niveau 7'), findsOneWidget);
    },
  );

  testWidgets(
    'niveau global, variation, courbe et sessions récentes reflètent l\'historique (commit E)',
    (WidgetTester tester) async {
      await setTallSurface(tester);
      final repository = InMemorySessionRepository();
      // Relatif à « maintenant » réel, pas une date figée : le widget filtre
      // sur `DateTime.now()`, une date en dur dériverait hors de la fenêtre
      // de 30 jours au fil du temps.
      final now = DateTime.now().toUtc();

      Future<void> recordAt(
        String id,
        DateTime createdAt,
        int level,
        int score, {
        List<PersistedAnswer> answers = const [],
      }) => repository.recordSession(
        session: PersistedSession(
          id: id,
          playerId: 'test-player',
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 4,
          totalScore: score,
          levels: {ExerciseType.addition: level},
          createdAt: createdAt,
        ),
        answers: answers,
        levelUpdates: {
          ExerciseType.addition: LevelCacheEntry(
            level: level,
            sessionsPlayed: 1,
            updatedAt: createdAt,
          ),
        },
      );

      await recordAt(
        'session-a',
        now.subtract(const Duration(days: 20)),
        30,
        50,
      );
      await recordAt(
        'session-b',
        now.subtract(const Duration(days: 10)),
        40,
        60,
      );
      await recordAt(
        'session-c',
        now.subtract(const Duration(days: 1)),
        50,
        70,
        answers: [
          PersistedAnswer(
            id: 'answer-1',
            sessionId: 'session-c',
            exerciseType: 'arithmetic',
            operationType: 'addition',
            operands: const {'operandA': 1, 'operandB': 1},
            submittedValue: 2,
            isCorrect: true,
            elapsedMs: 1000,
            createdAt: now,
          ),
          PersistedAnswer(
            id: 'answer-2',
            sessionId: 'session-c',
            exerciseType: 'arithmetic',
            operationType: 'addition',
            operands: const {'operandA': 1, 'operandB': 1},
            submittedValue: 2,
            isCorrect: true,
            elapsedMs: 2000,
            createdAt: now,
          ),
        ],
      );
      final environment = AppEnvironment(
        repository: repository,
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: ProgressScreen(environment: environment)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Progression'), findsOneWidget);
      // (50 + 6 × 1 plancher pour les 6 types non joués) / 7 = 8.
      expect(find.textContaining('Niveau global : 8'), findsOneWidget);
      // Session la plus récente de la fenêtre (session-c, niveau 50) vs la plus
      // ancienne (session-a, niveau 30) : +20 — même valeur qu'avant la
      // correction ici, un seul type ayant jamais été touché dans ce test.
      expect(find.textContaining('Variation (30 j) : +20'), findsOneWidget);
      // 3 sessions dans les 30 jours : la courbe a assez de points, pas de repli.
      expect(
        find.text('Pas assez de données sur les 30 derniers jours.'),
        findsNothing,
      );
      expect(find.textContaining('Niveau 50 · 1500 ms'), findsOneWidget);
      expect(find.textContaining('Score 70'), findsOneWidget);
      expect(find.textContaining('Score 60'), findsOneWidget);
      expect(find.textContaining('Score 50'), findsOneWidget);
    },
  );
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
