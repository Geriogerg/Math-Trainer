import '../models/exercise_type.dart';

/// The three duel modes (plan v3.7, Phase 7), each with its own rating and
/// board. Chain operations stays solo.
///
/// [name] is a stored discriminant (duel runs, duels, ratings, the server's
/// `/health`): **renaming a value breaks history**, like `ExerciseType`.
enum DuelMode {
  /// 8 questions, 2 each of + − × ÷. More correct answers wins; equal →
  /// less total time.
  basics,

  /// 8 questions, 2 each of x², √, %, ∫. Same winner rule as [basics].
  advanced,

  /// Get the count: 3 rounds of 30 s, the same numbers and targets for both.
  /// Smaller total distance to the targets wins; equal → less total time.
  count;

  /// The operations a question mode draws, two of each, in `.index` order;
  /// empty for [count].
  List<ExerciseType> get types => switch (this) {
    basics => ExerciseFamily.basics.types,
    // x², √, %, ∫ — the four advanced operations.
    advanced => ExerciseFamily.advanced.types,
    count => const [],
  };

  /// Whether its runs are question runs (Basics, Advanced) rather than
  /// Get the count rounds.
  bool get isQuiz => this != count;

  /// The modes a server built from this code plays: its `/health` lists
  /// their names (`duelModes`); the app offers a duel only in a mode listed.
  static const acceptedByServer = values;

  /// Throws [FormatException] for a name no mode has (stored data is
  /// never guessed).
  static DuelMode parse(Object? name) {
    for (final mode in values) {
      if (mode.name == name) return mode;
    }
    throw FormatException('unknown duel mode $name');
  }
}

/// The rules of a duel — what its content is drawn from and how its winner
/// is decided — stored with every duel, so a stored duel replays under its
/// own rules when later duels move on. Separate from `RulesVersion` (games):
/// a duel also stores the game rules its questions are drawn under.
///
/// [number] is the stored value: never renumber one.
enum DuelRulesVersion {
  /// Phase 7 (plan v3.7): tiers by 150 rating points, two of each operation,
  /// Get the count targets by shortest-solution length, 3 rounds of 30 s.
  v1(1);

  const DuelRulesVersion(this.number);

  final int number;

  /// What new duels are played under.
  static const current = v1;

  /// What a server built from this code replays; its `/health` lists them
  /// (`duelRules`), and the app holds a run back until the server knows its
  /// rules, as it does for sessions.
  static const replayed = [v1];

  /// Throws [FormatException] for a number no version has.
  static DuelRulesVersion of(Object? number) {
    for (final version in values) {
      if (version.number == number) return version;
    }
    throw FormatException('unknown duel rules version $number');
  }
}
