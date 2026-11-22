import 'package:flutter/foundation.dart';
import 'package:math_core/leaderboard/leaderboard.dart';

enum LeaderboardView { aroundMe, top }

/// The Leaderboard tab's state: which board, which view, and what the
/// server answered. Both views of a board load together, so switching view
/// is instant.
class LeaderboardController extends ChangeNotifier {
  LeaderboardController(this.repository);

  final LeaderboardRepository repository;

  LeaderboardBoard _board = const LeaderboardBoard.main();
  LeaderboardBoard get board => _board;

  LeaderboardView _view = LeaderboardView.aroundMe;
  LeaderboardView get view => _view;

  bool _loading = false;
  bool get loading => _loading;

  bool _failed = false;
  bool get failed => _failed;

  Standing? _standing;
  Standing? get standing => _standing;

  List<LeaderboardEntry>? _top;
  List<LeaderboardEntry>? get top => _top;

  int _request = 0;
  bool _disposed = false;

  /// (Re)loads the current board; a later call supersedes an earlier one
  /// still in flight (its answer is dropped).
  Future<void> load() async {
    final request = ++_request;
    _loading = true;
    _failed = false;
    _notify();
    try {
      final results = await Future.wait([
        repository.aroundMe(_board),
        repository.top(_board),
      ]);
      if (request != _request) return;
      _standing = results[0] as Standing;
      _top = results[1] as List<LeaderboardEntry>;
    } on Exception catch (_) {
      if (request != _request) return;
      _failed = true;
    }
    _loading = false;
    _notify();
  }

  /// Reports [entry]'s name; `true` once the server has it.
  Future<bool> report(LeaderboardEntry entry) async {
    final id = entry.playerId;
    if (id == null || entry.isMe) return false;
    try {
      await repository.reportName(id);
      return true;
    } on Exception catch (_) {
      return false;
    }
  }

  void selectBoard(LeaderboardBoard board) {
    if (board == _board) return;
    _board = board;
    _standing = null;
    _top = null;
    load().ignore();
  }

  void selectView(LeaderboardView view) {
    if (view == _view) return;
    _view = view;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
