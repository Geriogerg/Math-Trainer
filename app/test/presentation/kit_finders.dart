import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/presentation/kit/kit.dart';

/// The `LevelBadge` showing [level] (Phase 5 commit 2), built or not on
/// screen — a semantics-label finder misses badges scrolled out of view.
Finder findLevelBadge(int level) => find.byWidgetPredicate(
  (widget) => widget is LevelBadge && widget.level == level,
  description: 'LevelBadge($level)',
);
