import 'package:flutter/foundation.dart';

import 'package:math_core/friends/friends.dart';

/// The Friends page (plan v3.7, Phase 7 commit 7): the player's code, the
/// requests waiting for them, their friends with the head-to-head.
class FriendsController extends ChangeNotifier {
  FriendsController(this.repository);

  final FriendsRepository repository;

  String? _code;
  String? get code => _code;

  List<FriendRequest> _incoming = const [];
  List<FriendRequest> get incoming => _incoming;

  List<Friend>? _friends;

  /// `null` until loaded.
  List<Friend>? get friends => _friends;

  bool _failed = false;
  bool get failed => _failed;

  bool _disposed = false;

  Future<void> load() async {
    _failed = false;
    _notify();
    try {
      final results = await Future.wait([
        repository.myCode(),
        repository.incoming(),
        repository.friends(),
      ]);
      _code = results[0] as String;
      _incoming = results[1] as List<FriendRequest>;
      _friends = results[2] as List<Friend>;
    } on Exception catch (_) {
      _failed = true;
    }
    _notify();
  }

  /// A new code (the old links stop working); `false` if it failed.
  Future<bool> newCode() async {
    try {
      _code = await repository.newCode();
    } on Exception catch (_) {
      return false;
    }
    _notify();
    return true;
  }

  /// A request by code; the list reloads (a mutual request makes friends).
  Future<FriendRequestOutcome> add(String code) async {
    final FriendRequestOutcome outcome;
    try {
      outcome = await repository.request(code);
    } on Exception catch (_) {
      return FriendRequestOutcome.other;
    }
    await load();
    return outcome;
  }

  /// Accepts or declines [request]; `false` if it failed (Phase 6b commit
  /// 5, review M18: it failed silently) — the request is shown again by the
  /// reload, nothing was lost, and the screen says it did not go through.
  Future<bool> respond(FriendRequest request, {required bool accept}) async {
    var done = true;
    try {
      await repository.respond(request.fromId, accept: accept);
    } on Exception catch (_) {
      done = false;
    }
    await load();
    return done;
  }

  /// Removes [friend]; `false` if it failed (the friend stays).
  Future<bool> remove(Friend friend) async {
    var done = true;
    try {
      await repository.remove(friend.id);
    } on Exception catch (_) {
      done = false;
    }
    await load();
    return done;
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
