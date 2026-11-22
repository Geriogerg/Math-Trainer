import '../models/exercise_type.dart';
import 'level.dart';

/// Under rules v2, the time under which a correct answer earns full
/// credit (`doc/levels.md`, sections 3 and 5): set by the operation and the
/// tier of the level the game was played at.
///
/// Until commit 3 of the Levels phase gives each tier its own, the shared
/// `t_rapide` of rules v1 (2 s) for every operation and level.
int fluentTimeMs(ExerciseType type, Level level) => 2000;
