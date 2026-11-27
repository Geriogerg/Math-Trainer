import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/game_setup.dart';

import '../home_strings.dart';

/// [HomeStrings] en français (Phase 6d).
class FrenchHomeStrings implements HomeStrings {
  const FrenchHomeStrings();

  @override
  final play = 'Jouer';

  @override
  final mainLevelCaption = 'Ton niveau\u202f: la moyenne de + − × ÷.';

  @override
  final signInHint =
      'Tu as déjà joué, ici ou ailleurs\u202f? Connecte-toi pour retrouver tes '
      'niveaux.';

  @override
  String family(ExerciseFamily family) => switch (family) {
    ExerciseFamily.basics => 'Bases',
    ExerciseFamily.advanced => 'Avancé',
  };

  @override
  String familyCaption(ExerciseFamily family) => switch (family) {
    ExerciseFamily.basics =>
      'Touche les opérations pour jouer. Chacune a un niveau, de 0 à 100.',
    ExerciseFamily.advanced => 'Chacune a son niveau, comme les bases.',
  };

  @override
  String playFamily(ExerciseFamily family) =>
      'Jouer\u202f: ${this.family(family)}';

  @override
  final practice = 'S’exercer';

  @override
  final weakSpots = 'Points faibles';

  @override
  final weakSpotsCaption = 'Ce que tu as raté, reposé.';

  @override
  String weakSpotsDue(int n) => n == 0 ? 'Rien à revoir' : '$n à revoir';

  @override
  final challenges = 'Défis';

  @override
  final getTheCount = 'Le compte est bon';

  @override
  final getTheCountCaption = 'Atteins une cible avec les nombres donnés.';

  @override
  final chainOperations = 'Calcul en chaîne';

  @override
  final chainCaption = 'Un total qui court, gardé en tête.';

  @override
  final tables = 'Tables';

  @override
  final tablesCaption =
      'Les tables de multiplication, à ton rythme. Jamais classé.';

  @override
  final tips = 'Astuces';

  @override
  final tipsCaption = 'Des raccourcis pour chaque opération et chaque niveau.';

  @override
  final firstRunTitle = 'Comment marchent les niveaux';

  @override
  final firstRunLevels =
      'Chaque opération a un niveau, de 0 à 100. Une partie en Progression le '
      'fait bouger\u202f: les bonnes réponses le montent, surtout les rapides\u202f; '
      'les erreurs, les temps écoulés et l’abandon le baissent.';

  @override
  final firstRunPractice =
      'Les parties d’entraînement et les exercices ne bougent jamais tes niveaux.';

  @override
  final couldNotStart = 'Impossible de commencer';

  @override
  final questions = 'Questions';

  @override
  String questionsCaption(int perOperation, int operations) => operations == 1
      ? '$perOperation questions.'
      : '$perOperation par opération\u202f: ${perOperation * operations} '
            'questions en tout.';

  @override
  final mode = 'Mode';

  @override
  String modeLabel(GameMode mode) => switch (mode) {
    GameMode.training => 'Entraînement',
    GameMode.levelling => 'Progression',
  };

  @override
  String modeCaption(GameMode mode) => switch (mode) {
    GameMode.levelling =>
      'Fait bouger tes niveaux. Abandonner compte les questions restantes comme ratées.',
    GameMode.training => 'Une difficulté fixe. Tes niveaux ne bougent jamais.',
  };

  @override
  String difficulty(TrainingDifficulty difficulty) => switch (difficulty) {
    TrainingDifficulty.easy => 'Facile',
    TrainingDifficulty.medium => 'Moyen',
    TrainingDifficulty.hard => 'Difficile',
  };

  @override
  final difficultyCaption =
      'Facile\u202f: niveau 10 · Moyen\u202f: 40 · Difficile\u202f: 70.';

  @override
  final seconds = 'Secondes';

  @override
  final operations = 'Opérations';

  @override
  final chainRules = const [
    'Un nombre, puis une opération par écran. Garde le résultat en tête\u202f; '
        'tape-le à la fin.',
    'Exercice\u202f: ça ne bouge jamais tes niveaux.',
  ];

  @override
  final countRules = const [
    'Atteins la cible avec les nombres donnés et + − × ÷, chaque nombre une '
        'fois au plus.',
    'Plus tu es près, mieux c’est\u202f; l’atteindre finit la manche.',
    'Exercice\u202f: ça ne bouge jamais tes niveaux.',
  ];

  @override
  final from = 'De';

  @override
  final to = 'À';

  @override
  final multipliers = 'Multiplicateurs';

  @override
  String stepDown(String label) => '$label −1';

  @override
  String stepUp(String label) => '$label +1';

  @override
  String stepValue(String label, int value) => '$label $value';
}
