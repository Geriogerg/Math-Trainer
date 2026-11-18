import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/domain/account/account.dart';
import 'package:math_trainer/core/domain/account/account_repository.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/persistence/persisted_answer.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:math_trainer/core/domain/persistence/session_repository.dart';
import 'package:math_trainer/presentation/screens/profile_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

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
  Future<List<PersistedSession>> recentSessions(
    String playerId, {
    int limit = 20,
  }) async {
    if (shouldFail) throw Exception('échec simulé');
    return [];
  }

  @override
  Future<void> transferPlayerData({
    required String fromPlayerId,
    required String toPlayerId,
  }) async {}

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

/// Fausse implémentation locale qui enregistre l'appel à `signOut()` — le
/// `FakeAccountRepository` partagé le lance en `UnimplementedError` (il ne
/// sert qu'à satisfaire le constructeur pour les tests qui ne s'y
/// intéressent pas).
class _RecordingAccountRepository implements AccountRepository {
  bool signOutCalled = false;

  @override
  Stream<Account?> get authState =>
      Stream.value(const Account(id: 'test-account', email: 'player@test.com'));

  @override
  Future<Account?> signUp({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<Account> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

void main() {
  // Écran désormais plus long (bloc identité + 4 blocs de progression) : une
  // fenêtre de test trop courte laisserait les dernières lignes hors du
  // viewport initial, donc absentes de `find.text()` sans scroll.
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
        profileRepository: FakeProfileRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: ProfileScreen(environment: environment)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Level 42'), findsOneWidget);
      expect(find.text('Not played'), findsNWidgets(6));
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
        profileRepository: FakeProfileRepository(),
      );

      Future<void> pump(bool isActive) => tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: ProfileScreen(environment: environment, isActive: isActive),
          ),
        ),
      );

      await pump(false);
      await tester.pumpAndSettle();
      expect(find.text('Not played'), findsNWidgets(7));

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
      expect(find.text('Not played'), findsNWidgets(7));

      // Transition inactif → actif : didUpdateWidget doit relancer le chargement.
      await pump(true);
      await tester.pumpAndSettle();

      expect(find.text('Level 42'), findsOneWidget);
      expect(find.text('Not played'), findsNWidgets(6));
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
        profileRepository: FakeProfileRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: ProfileScreen(environment: environment)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load the profile.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    },
  );

  testWidgets(
    'Réessayer relance la lecture et affiche le profil si elle réussit',
    (WidgetTester tester) async {
      await setTallSurface(tester);
      final repository = _FlakySessionRepository();
      final environment = AppEnvironment(
        repository: repository,
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: ProfileScreen(environment: environment)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not load the profile.'), findsOneWidget);

      repository.shouldFail = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load the profile.'), findsNothing);
      expect(find.text('Level 7'), findsOneWidget);
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
          // Ce qu'enregistre le contrôleur : niveau global (7 types, six au
          // plancher) une fois l'addition passée à [level].
          overallLevelAfter: (level + 6) / 7,
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
        profileRepository: FakeProfileRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: ProfileScreen(environment: environment)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      // (50 + 6 × 1 plancher pour les 6 types non joués) / 7 = 8.
      expect(find.textContaining('Overall level: 8'), findsOneWidget);
      // Niveau global après la première session de la fenêtre (36/7) puis
      // après la dernière (56/7) : 20/7 ≈ +3 — la dernière partie compte.
      expect(find.textContaining('30-day change: +3'), findsOneWidget);
      // Effet de chacune des deux dernières sessions : 10/7 ≈ +1 ; la plus
      // ancienne n'a pas de session précédente à laquelle se comparer.
      expect(find.text('+1'), findsNWidgets(2));
      expect(
        find.text('Not enough data for the last 30 days.'),
        findsNothing,
      );
      expect(find.textContaining('Level 50 · 1500 ms'), findsOneWidget);
      expect(find.textContaining('Score 70'), findsOneWidget);
      expect(find.textContaining('Score 60'), findsOneWidget);
      expect(find.textContaining('Score 50'), findsOneWidget);
    },
  );

  testWidgets('affiche l\'invite quand aucun nom de joueur n\'est enregistré', (
    WidgetTester tester,
  ) async {
    await setTallSurface(tester);
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository()..displayName = null,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: ProfileScreen(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose a player name'), findsOneWidget);
    expect(find.text('player@test.com'), findsOneWidget);
  });

  // Régression : le nom (réseau) et les statistiques (locales) étaient lus
  // dans un même `Future.wait` — hors ligne, tout l'écran tombait sur
  // « Impossible de charger le profil. », statistiques locales comprises.
  testWidgets(
    'nom de joueur injoignable : les statistiques locales restent affichées',
    (WidgetTester tester) async {
      await setTallSurface(tester);
      final profileRepository = FakeProfileRepository()..shouldFail = true;
      final environment = AppEnvironment(
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: profileRepository,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: ProfileScreen(environment: environment)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load the profile.'), findsNothing);
      expect(find.text('By operation'), findsOneWidget);
      expect(find.text('player@test.com'), findsOneWidget);
      expect(find.text('Player name unavailable'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);

      profileRepository
        ..shouldFail = false
        ..displayName = 'Alex';
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(find.text('Alex'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    },
  );

  testWidgets('affiche le nom de joueur déjà enregistré', (
    WidgetTester tester,
  ) async {
    await setTallSurface(tester);
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository()..displayName = 'Alex',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: ProfileScreen(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Choose a player name'), findsNothing);
  });

  testWidgets(
    'modifier le nom de joueur appelle updateDisplayName et rafraîchit l\'affichage',
    (WidgetTester tester) async {
      await setTallSurface(tester);
      final profileRepository = FakeProfileRepository()..displayName = 'Alex';
      final environment = AppEnvironment(
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: profileRepository,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: ProfileScreen(environment: environment)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nouveau nom');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(profileRepository.displayName, 'Nouveau nom');
      expect(find.text('Nouveau nom'), findsOneWidget);
    },
  );

  testWidgets(
    'un nom non enregistré est signalé, l\'ancien nom reste affiché',
    (WidgetTester tester) async {
      await setTallSurface(tester);
      final profileRepository = FakeProfileRepository()
        ..displayName = 'Alex'
        ..updateShouldFail = true;
      final environment = AppEnvironment(
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: profileRepository,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: ProfileScreen(environment: environment)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nouveau nom');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Name not saved'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
    },
  );

  testWidgets('Se déconnecter appelle signOut', (WidgetTester tester) async {
    await setTallSurface(tester);
    final accountRepository = _RecordingAccountRepository();
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: accountRepository,
      profileRepository: FakeProfileRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: ProfileScreen(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(accountRepository.signOutCalled, isTrue);
  });
}

String _labelFor(ExerciseType type) => switch (type) {
  ExerciseType.addition => 'Addition',
  ExerciseType.subtraction => 'Subtraction',
  ExerciseType.multiplication => 'Multiplication',
  ExerciseType.division => 'Division',
  ExerciseType.power => 'Powers',
  ExerciseType.squareRoot => 'Square roots',
  ExerciseType.percentage => 'Percentages',
};
