import 'package:flutter/foundation.dart';

/// Tells Home and Profile that the local levels changed outside a game —
/// the server's adopted right after sign-in (Phase 6b commit 5, review
/// M14: a linked player on a new device saw an empty account until their
/// first game). They read the levels again.
class LevelsRefresh extends ChangeNotifier {
  void changed() => notifyListeners();
}
