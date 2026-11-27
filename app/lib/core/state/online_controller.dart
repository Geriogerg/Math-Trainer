import 'package:flutter/foundation.dart';

import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_rating.dart';
import 'package:math_core/duel/duel_run_queue.dart';
import 'package:math_core/duel/online_overview.dart';
import 'package:math_core/friends/friends.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';

/// The Online tab's state (Phase 7 commit 6): the overview the server
/// holds, and the ratings to show — the server's, or the starting rating
/// from the player's own levels before their first duel of a mode
/// (provisional either way until 10 rated duels). Each [load] also sends
/// the runs still waiting on the device and wakes the server (`/health`),
/// so the first duel does not wait for it as long.
class OnlineController extends ChangeNotifier {
  OnlineController({
    required this.repository,
    required this.levels,
    this.client,
    this.queue,
    this.friends,
    this.invites,
  });

  final OnlineRepository repository;

  /// The player's levels on this device (for the starting ratings).
  final Future<Map<ExerciseType, Level>> Function() levels;
  final DuelClient? client;
  final DuelRunQueue? queue;

  /// An invite link's code becomes a friend request once the player is
  /// linked (commit 7) — and once they said yes (Phase 6a, review m7: a
  /// link alone no longer sends a request).
  final FriendsRepository? friends;
  final PendingInviteStore? invites;

  FriendRequestOutcome? _inviteOutcome;
  String? _pendingInvite;

  /// An invite link's code waiting for the player's yes, once: the tab
  /// asks.
  String? takePendingInvite() {
    final code = _pendingInvite;
    _pendingInvite = null;
    return code;
  }

  /// The player's answer to [code]'s invite: sent as a friend request, or
  /// dropped. Either way the link is forgotten.
  Future<void> answerInvite(String code, {required bool send}) async {
    final friends = this.friends;
    final invites = this.invites;
    if (friends == null || invites == null) return;
    try {
      if (send) _inviteOutcome = await friends.request(code);
      await invites.save(null);
    } on Exception catch (_) {
      // Kept: asked again at the next load.
    }
    _notify();
  }

  List<DuelMode> _unfinishedSent = const [];

  /// The modes of the duels left unfinished on this device that a flush
  /// has now sent, once (Phase 6b commit 5, review M15: sent silently at
  /// the next start): the shell says so.
  List<DuelMode> takeUnfinishedSent() {
    final sent = _unfinishedSent;
    _unfinishedSent = const [];
    return sent;
  }

  /// What the invite link's request did, once: the tab says so.
  FriendRequestOutcome? takeInviteOutcome() {
    final outcome = _inviteOutcome;
    _inviteOutcome = null;
    return outcome;
  }

  OnlineOverview? _overview;
  OnlineOverview? get overview => _overview;

  Map<ExerciseType, Level> _levels = const {};

  bool _loading = false;
  bool get loading => _loading;

  bool _failed = false;
  bool get failed => _failed;

  bool _disposed = false;
  int _request = 0;

  /// Something waits for the player: the tab's badge.
  bool get needsAttention => _overview?.needsAttention ?? false;

  /// The rating shown for [mode] and whether it is provisional.
  ({double rating, bool provisional}) rating(DuelMode mode) {
    final held = _overview?.ratings[mode];
    return held == null
        ? (rating: startingDuelRating(mode, _levels), provisional: true)
        : (
            rating: held.rating,
            provisional: isProvisionalRating(held.ratedDuels),
          );
  }

  Future<void> load() async {
    final request = ++_request;
    _loading = true;
    _failed = false;
    _notify();
    // Background chores: never block the tab.
    queue
        ?.flush()
        .then((sent) {
          if (sent.isEmpty) return;
          _unfinishedSent = [..._unfinishedSent, for (final r in sent) r.mode];
          _notify();
        })
        .catchError((Object _) {})
        .ignore();
    client?.support().ignore();
    try {
      final overview = await repository.overview();
      final levels = await this.levels();
      if (request != _request) return;
      _overview = overview;
      _levels = levels;
      if (overview.linked) await _sendInvite();
    } on Exception catch (_) {
      if (request != _request) return;
      _failed = true;
    }
    _loading = false;
    _notify();
  }

  Future<void> _sendInvite() async {
    final friends = this.friends;
    final invites = this.invites;
    if (friends == null || invites == null) return;
    try {
      final code = await invites.load();
      if (code == null) return;
      _pendingInvite = code;
    } on Exception catch (_) {
      // Kept: tried again at the next load.
    }
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
