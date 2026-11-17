import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/domain/account/account_repository.dart';
import 'core/domain/account/profile_repository.dart';
import 'core/domain/generation/composite_exercise_generator.dart';
import 'core/domain/generation/debt_aware_type_selection_strategy.dart';
import 'core/domain/generation/local_exercise_source.dart';
import 'core/domain/generation/session_length.dart';
import 'core/domain/leveling/leveling_rules.dart';
import 'core/domain/models/exercise_type.dart';
import 'core/domain/models/session_config.dart';
import 'core/domain/persistence/in_memory_session_repository.dart';
import 'core/domain/persistence/local_player_id_provider.dart';
import 'core/domain/persistence/session_repository.dart';
import 'core/domain/persistence/theme_mode_store.dart';
import 'core/domain/persistence/type_selection_store.dart';
import 'core/state/session_controller.dart';
import 'infrastructure/backend/supabase_account_repository.dart';
import 'infrastructure/backend/supabase_profile_repository.dart';
import 'infrastructure/persistence/database.dart';
import 'infrastructure/persistence/shared_preferences_player_id_provider.dart';
import 'infrastructure/persistence/shared_preferences_theme_mode_store.dart';
import 'infrastructure/persistence/shared_preferences_type_selection_store.dart';
import 'infrastructure/persistence/sqflite_session_repository.dart';

/// Cible de durée (~90 s à ~4 s/question, grossier — voir `doc/decisions.md`)
/// déguisée en plafond de questions : `sessionLengthFor` ne dépasse jamais
/// cette valeur, quel que soit le nombre de types actifs.
const _sessionLengthCap = 24;

final _levelingRules = LevelingRules();

/// Dépendances concrètes résolues une fois au démarrage de l'app (voir
/// `main.dart`), avant `runApp()` — jamais dans un widget UI. C'est le seul
/// fichier qui choisit *quelles* implémentations concrètes utiliser
/// (génération, persistance) ; `home_screen.dart` ne fait qu'observer le
/// `SessionController` qui en résulte.
class AppEnvironment {
  const AppEnvironment({
    required this.repository,
    required this.playerId,
    required this.accountRepository,
    required this.profileRepository,
    this.typeSelectionStore = const SharedPreferencesTypeSelectionStore(),
    this.themeModeStore = const SharedPreferencesThemeModeStore(),
  });

  final SessionRepository repository;
  final String playerId;

  /// Requis, pas de défaut concret : contrairement à `typeSelectionStore`/
  /// `themeModeStore` (lecture locale auxiliaire, échec silencieux
  /// acceptable), le compte est la fonctionnalité même de l'onglet En ligne
  /// — un défaut masquerait un oubli de câblage plutôt que de simplifier les
  /// tests. Les tests qui ne s'intéressent pas au compte passent
  /// `FakeAccountRepository` (`test/fake_account_repository.dart`).
  final AccountRepository accountRepository;

  /// Même raisonnement que `accountRepository` : requis, pas de défaut
  /// silencieux — c'est la fonctionnalité centrale de l'onglet Profil.
  final ProfileRepository profileRepository;

  /// Optionnel, défaut concret plutôt que requis : un champ requis casserait
  /// la construction dans les tests qui ne s'intéressent jamais à `PlayTab`
  /// (`ProgressScreen`, `ResultScreen`...), même raisonnement que
  /// `SessionResult.scorer` (étape 5, commit D).
  final TypeSelectionStore typeSelectionStore;

  /// Même raisonnement que `typeSelectionStore` : optionnel pour ne pas
  /// casser la construction dans les tests qui ne s'intéressent pas à la
  /// bascule de thème.
  final ThemeModeStore themeModeStore;
}

/// URL et clé publique lues à la compilation (`--dart-define`), jamais en
/// dur dans le code source (`doc/online.md`) — la clé publique est conçue
/// pour être embarquée côté client (RLS protège les données, pas le secret
/// de cette clé), mais l'URL/clé restent spécifiques à chaque projet Supabase.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

/// Build lancé sans `--dart-define-from-file=dart_defines.json` (voir
/// `dart_defines.example.json`). Sans ce contrôle, l'app démarrait quand même
/// sur la porte de connexion, avec un client Supabase sans adresse : chaque
/// tentative échouait sur une erreur d'URI incompréhensible, et la connexion
/// étant obligatoire, l'app entière devenait inutilisable sans explication.
class MissingBackendConfigException implements Exception {
  const MissingBackendConfigException(this.missingKeys);

  final List<String> missingKeys;

  @override
  String toString() =>
      'MissingBackendConfigException: ${missingKeys.join(', ')} absent(s)';
}

Future<AppEnvironment> buildAppEnvironment() async {
  final missingKeys = [
    if (_supabaseUrl.isEmpty) 'SUPABASE_URL',
    if (_supabasePublishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
  ];
  if (missingKeys.isNotEmpty) {
    throw MissingBackendConfigException(missingKeys);
  }

  final LocalPlayerIdProvider playerIdProvider =
      SharedPreferencesPlayerIdProvider();
  final playerId = await playerIdProvider.currentPlayerId();

  final SessionRepository repository;
  if (kIsWeb) {
    // sqflite n'a pas d'implémentation web ; le web n'est utilisé que pour
    // itérer (CLAUDE.md), donc un repository en mémoire suffit ici.
    repository = InMemorySessionRepository();
  } else {
    final databasePath = p.join(await getDatabasesPath(), 'math_trainer.db');
    repository = SqfliteSessionRepository(
      await openMathTrainerDatabase(databasePath),
    );
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );

  return AppEnvironment(
    repository: repository,
    playerId: playerId,
    accountRepository: SupabaseAccountRepository(Supabase.instance.client),
    profileRepository: SupabaseProfileRepository(Supabase.instance.client),
  );
}

/// Assemble un `SessionController` prêt à jouer : source d'exercices locale
/// (mélange de [enabledTypes], choisis par l'utilisateur sur `HomeScreen`)
/// + seed du moment + dépendances de [environment]. Asynchrone : lit le
/// cache de niveaux du joueur (règle 4, repositories toujours asynchrones)
/// pour figer les niveaux de cette session — niveau 1 pour toute opération
/// jamais jouée (aucune compétence estimée = on part du bas).
///
/// Le nombre de questions n'est plus fixe : `sessionLengthFor` vise assez de
/// questions pour que chaque type actif atteigne `n_min` (donc que son
/// cache de niveau puisse bouger), plafonné à `_sessionLengthCap`. Au-delà
/// du plafond, `DebtAwareTypeSelectionStrategy` priorise les types les
/// moins joués (`sessionsPlayed`, déjà lu ci-dessus pour les niveaux) —
/// aucun nouvel appel au repository (voir `doc/decisions.md`).
Future<SessionController> buildSessionController(
  AppEnvironment environment,
  Set<ExerciseType> enabledTypes,
) async {
  final priorLevels = await environment.repository.currentLevels(
    environment.playerId,
  );
  final levels = {
    for (final type in enabledTypes) type: priorLevels[type]?.level ?? 1,
  };

  final exerciseCount = sessionLengthFor(
    activeTypeCount: enabledTypes.length,
    nMin: _levelingRules.nMin,
    cap: _sessionLengthCap,
  );
  final strategy = DebtAwareTypeSelectionStrategy(
    exerciseCount: exerciseCount,
    nMin: _levelingRules.nMin,
    sessionsPlayedByType: {
      for (final entry in priorLevels.entries)
        entry.key: entry.value.sessionsPlayed,
    },
  );

  final seed = DateTime.now().millisecondsSinceEpoch;
  return SessionController(
    config: SessionConfig(
      seed: seed,
      enabledTypes: enabledTypes,
      exerciseCount: exerciseCount,
      levels: levels,
    ),
    exerciseSource: LocalExerciseSource(
      generator: CompositeExerciseGenerator(
        enabledTypes: enabledTypes,
        levels: levels,
        strategy: strategy,
      ),
      seed: seed,
    ),
    repository: environment.repository,
    playerId: environment.playerId,
  );
}
