import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../kit/kit.dart';
import '../strings/strings.dart';

import '../../composition_root.dart';
import '../../core/effects/effect_settings.dart';
import 'package:math_core/weak_spots/worst_facts.dart';
import 'package:math_core/weak_spots/facts.dart';
import 'package:math_core/account/account.dart';
import 'package:math_core/account/player_profile.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/persisted_session.dart';
import '../../core/state/account_deletion_controller.dart';
import 'package:math_core/account/display_name.dart';
import 'package:math_core/feedback/feedback.dart';

import 'package:math_trainer/presentation/strings/account_messages.dart';
import 'package:math_trainer/presentation/strings/exercise_type_labels.dart';
import 'package:math_trainer/presentation/strings/upload_refusal_text.dart';
import 'package:math_core/challenges/challenge_stats.dart';
import 'package:math_core/challenges/tables.dart';
import 'package:math_core/leveling/main_level.dart';
import '../../core/state/account_form_controller.dart';
import '../../core/state/feedback_controller.dart';
import '../../core/state/levels_refresh.dart';
import '../../core/state/session_controller.dart';
import '../exercise_prompt.dart';
import '../theme/app_theme.dart';
import 'session_flow_screen.dart';
import 'empty_state.dart';
import 'feedback_screen.dart';
import 'save_progress_screen.dart';
import 'sign_in_screen.dart';
import 'legal_screen.dart';
import '../../core/state/language.dart';
import 'package:math_core/account/account_repository.dart';

part 'profile_sections.dart';

const _windowDuration = Duration(days: 30);
const _recentSessionsLimit = 10;

/// `+3`/`−3`/`0` — true minus sign U+2212 (`doc/design.md`), never `-`.
String _formatDelta(double delta) {
  final rounded = delta.round();
  if (rounded > 0) return '+$rounded';
  if (rounded < 0) return '−${-rounded}';
  return '0';
}

String _shortDate(DateTime utc) {
  final local = utc.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month';
}

class _ProfileData {
  const _ProfileData({
    required this.now,
    required this.account,
    required this.levels,
    required this.avgElapsedMs,
    required this.windowSessions,
    required this.recentSessions,
    this.pendingUploads = 0,
  });

  /// Frozen once per load — `_LevelCurve` positions its points relative to
  /// this value rather than calling `DateTime.now()` in its own `build()`:
  /// two separate calls would drift a few milliseconds apart, enough to
  /// shift the curve by a sub-pixel and make golden tests non-reproducible.
  final DateTime now;

  final Account account;
  final Map<ExerciseType, LevelCacheEntry> levels;
  final Map<ExerciseType, double> avgElapsedMs;

  /// `sessionsSince(playerId, now - 30 days)`, sorted old → recent, those
  /// of the current rules only: a level from before the Levels phase's reset
  /// is on another scale (`doc/levels.md`, section 4).
  final List<PersistedSession> windowSessions;

  /// `recentSessions(playerId, limit: 10)`, sorted recent → old.
  final List<PersistedSession> recentSessions;

  /// Games stored here and not yet sent (review m17: pending uploads were
  /// invisible).
  final int pendingUploads;
}

/// Formerly "Progress" (step 5). Renamed Profile in step 6, slice 2: it
/// now carries the identity (player name, email, sign-out) on top of the
/// existing statistics — an explicit owner decision revising the "profile
/// as a corner icon, no 5th tab" rule of `doc/design.md`.
///
/// Five blocks, from general to detailed: identity, main level and its
/// recent change, 30-day level curve, breakdown per operation (level +
/// average time), recent sessions. Never an accuracy rate nor a score as a
/// measure of progress (`doc/decisions.md`) — what progresses is the level.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.environment,
    this.isActive = true,
    this.clock = DateTime.now,
    this.onToggleTheme,
  });

  final AppEnvironment environment;

  /// The day/night switch (on Profile since the Redesign phase: Home's
  /// corner holds the main level). `null`: not shown.
  final VoidCallback? onToggleTheme;

  /// The time the curve and the recent games are placed against. Golden
  /// tests pass a fixed one: with the real clock, dates shown as `dd/mm`
  /// change every day and the image with them.
  final DateTime Function() clock;

  /// True when this tab is the one shown by `AppShell`. `IndexedStack`
  /// keeps this widget mounted after its first visit (`app_shell.dart`), so
  /// without this signal `_load()` would never run again after a new
  /// session: `initState` only fires once per lifecycle.
  final bool isActive;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Everything local (account in session, levels, history): never the
  /// network, so available offline.
  late Future<_ProfileData> _data;

  /// The player name, the screen's only network read — loaded separately so
  /// that a failure (offline, Supabase unavailable) only affects the name
  /// line, not the local statistics.
  late Future<PlayerProfile> _profile;

  /// The challenges' records, on the device (Redesign phase). A failed read
  /// shows zeros, never an error.
  late Future<Map<Challenge, ChallengeStats>> _challengeStats;
  late Future<TablesStats> _tablesStats;

  /// The five worst facts of the history (Phase 4); a failed read shows
  /// none.
  late Future<List<WeakFact>> _worstFacts;

  /// Told when the server's levels replaced the local ones at sign-in
  /// (Phase 6b commit 5).
  LevelsRefresh? _levelsRefresh;

  @override
  void initState() {
    super.initState();
    _load();
    _levelsRefresh = widget.environment.levelsRefresh?..addListener(_reload);
  }

  void _reload() {
    if (mounted) setState(_load);
  }

  @override
  void dispose() {
    _levelsRefresh?.removeListener(_reload);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) setState(_load);
  }

  void _load() {
    final environment = widget.environment;
    final repository = environment.repository;
    final playerId = environment.playerId;
    final now = widget.clock().toUtc();
    final since = now.subtract(_windowDuration);
    _data =
        Future.wait([
          // `AuthGate` guarantees a signed-in account before reaching this
          // screen, and `authState` emits the current state first
          // (`account_repository.dart`) — `.first` reads it with no network call.
          environment.accountRepository.authState.first,
          repository.currentLevels(playerId),
          repository.averageElapsedMsByType(playerId),
          repository.sessionsSince(playerId, since),
          repository.recentSessions(playerId, limit: _recentSessionsLimit),
          // Only with a server to send them to.
          environment.uploadClient == null
              ? Future.value(const <PersistedSession>[])
              : repository.pendingUploads(playerId),
        ]).then(
          (results) => _ProfileData(
            now: now,
            account: results[0] as Account,
            levels: results[1] as Map<ExerciseType, LevelCacheEntry>,
            avgElapsedMs: results[2] as Map<ExerciseType, double>,
            windowSessions: [
              for (final session in results[3] as List<PersistedSession>)
                if (!session.rulesVersion.retired) session,
            ],
            recentSessions: results[4] as List<PersistedSession>,
            pendingUploads: (results[5] as List<PersistedSession>).length,
          ),
        );
    _loadProfile();
    _challengeStats = _loadChallengeStats();
    _tablesStats = _loadTablesStats();
    _worstFacts = _loadWorstFacts();
  }

  Future<List<WeakFact>> _loadWorstFacts() async {
    final environment = widget.environment;
    try {
      return worstFacts(
        await environment.repository.storedGames(environment.playerId),
      );
    } on Exception catch (_) {
      return const [];
    }
  }

  /// A Weak spots game of the block's facts; nothing when none can be
  /// practised at the player's tiers.
  Future<void> _practise(List<WeakFact> records) async {
    final environment = widget.environment;
    final SessionController? controller;
    try {
      controller = await buildFactsPracticeController(environment, [
        for (final r in records) r.fact,
      ]);
    } on Exception catch (_) {
      return;
    }
    if (controller == null || !mounted) {
      controller?.dispose();
      return;
    }
    await playSessionFlow(context, environment, controller);
    if (mounted) setState(_load);
  }

  Future<TablesStats> _loadTablesStats() async {
    try {
      return await widget.environment.tablesStore.loadStats();
    } on Exception catch (_) {
      return TablesStats.none;
    }
  }

  Future<Map<Challenge, ChallengeStats>> _loadChallengeStats() async {
    final store = widget.environment.challengeStatsStore;
    try {
      return {for (final c in Challenge.values) c: await store.load(c)};
    } on Exception catch (_) {
      return {};
    }
  }

  void _loadProfile() {
    // `ignore()`: the `FutureBuilder` reading `_profile` only exists once
    // `_data` has resolved. If the name fails before that, the error has no
    // listener yet and surfaces as an unhandled asynchronous error. Marked
    // handled here, it is still delivered to the `FutureBuilder` when it
    // subscribes.
    _profile = widget.environment.profileRepository.currentProfile()..ignore();
  }

  /// Sign out, asked first (review m17: one tap with no confirmation, and
  /// the app then starts as a new, empty guest).
  Future<void> _confirmSignOut() async {
    final go = await showRules(
      context,
      title: strings.profile.signOutTitle,
      lines: strings.profile.signOutLines,
      confirm: strings.profile.signOut,
    );
    if (go) await widget.environment.accountRepository.signOut();
  }

  Future<void> _editDisplayName(PlayerProfile profile) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) =>
          _DisplayNameDialog(initialValue: profile.displayName ?? ''),
    );
    if (newName == null || newName.isEmpty || !mounted) return;
    try {
      await widget.environment.profileRepository.updateDisplayName(newName);
      if (mounted) setState(_loadProfile);
    } on DisplayNameRefused {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.profile.nameNotAllowed)));
    } on DisplayNameTaken {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.profile.nameTaken)));
    } catch (_) {
      // The old name stays shown; without this message, the player would
      // think the new name was saved (network down, `profiles` table missing).
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.profile.nameNotSaved)));
    }
  }

  /// A guest links an email (same account id: nothing moves). On return,
  /// the screen reloads: the account is no longer anonymous.
  Future<void> _saveProgress(PlayerProfile? profile, bool hasProgress) async {
    final environment = widget.environment;
    final outcome = await Navigator.of(context).push<SaveProgressOutcome>(
      MaterialPageRoute(
        builder: (_) => SaveProgressScreen(
          accountRepository: environment.accountRepository,
          profileRepository: environment.profileRepository,
          initialDisplayName: profile?.displayName ?? '',
          guestHasProgress: hasProgress,
        ),
      ),
    );
    if (outcome == null || !mounted) return;
    setState(_load);
    final message = switch (outcome) {
      SaveProgressOutcome.saved => strings.profile.progressSaved,
      SaveProgressOutcome.savedWithoutName =>
        strings.profile.progressSavedNameNot,
      SaveProgressOutcome.confirmationPending => strings.profile.confirmEmail,
      SaveProgressOutcome.failed => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Confirm, then delete on the server, wipe this device's data, sign out
  /// (`AccountDeletionController`); `AuthGate` then starts a fresh guest.
  Future<void> _sendFeedback(FeedbackRepository repository) async {
    final controller = FeedbackController(
      repository: repository,
      appVersion: appVersion,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FeedbackScreen(controller: controller),
      ),
    );
    controller.dispose();
  }

  Future<void> _deleteData(Account account) async {
    final guest = account.isAnonymous;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.profile.deleteTitle(guest: guest)),
        content: Text(strings.profile.deleteDetail(guest: guest)),
        actions: [
          AppButton.secondary(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            label: strings.common.cancel,
          ),
          AppButton.secondary(
            destructive: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            label: strings.profile.delete,
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final environment = widget.environment;
    final deletion = AccountDeletionController(
      accounts: environment.accountRepository,
      repository: environment.repository,
      playerId: environment.playerId,
    );
    // Captured now: on success `AuthGate` replaces this whole screen.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
    final outcome = await deletion.delete();
    navigator.pop(); // the progress indicator
    deletion.dispose();
    final message = switch (outcome) {
      AccountDeletionOutcome.deleted => strings.profile.deleted(guest: guest),
      AccountDeletionOutcome.deletedButLocalDataKept =>
        strings.profile.deletedLocalKept,
      AccountDeletionOutcome.failed => strings.profile.nothingDeleted(
        describeAccountFailure(
          deletion.failure!,
          detail: deletion.failureDetail,
        ),
      ),
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Sign in to an existing account; `AuthGate` swaps the whole shell on
  /// success, so nothing to reload here.
  void _signInExisting(bool isGuest, bool hasProgress) {
    final environment = widget.environment;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SignInScreen(
          accountRepository: environment.accountRepository,
          profileRepository: environment.profileRepository,
          isGuest: isGuest,
          guestHasProgress: hasProgress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<_ProfileData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            message: strings.profile.couldNotLoad,
            actionLabel: strings.common.retry,
            onAction: () => setState(_load),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        // 0 before any game: everyone starts there (`doc/levels.md`).
        final globalLevel = mainLevel(data.levels);
        // Same points as the curve: the change is the gap between its first
        // and last points, never a separate computation.
        final windowLevels = [
          for (final session in data.windowSessions) ?session.overallLevelAfter,
        ];
        final windowStart = windowLevels.firstOrNull;
        final windowEnd = windowLevels.lastOrNull;

        return ListView(
          padding: theme.extension<AppMetrics>()!.rootPadding,
          children: [
            Text(strings.profile.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 24),
            FutureBuilder<PlayerProfile>(
              future: _profile,
              builder: (context, profileSnapshot) {
                final profile = profileSnapshot.data;
                final identity = _IdentityBlock(
                  account: data.account,
                  profile: profile,
                  profileFailed: profileSnapshot.hasError,
                  onEditName: profile == null
                      ? null
                      : () => _editDisplayName(profile),
                  onRetryProfile: () => setState(_loadProfile),
                  onSignOut: _confirmSignOut,
                  onSaveProgress: () =>
                      _saveProgress(profile, data.recentSessions.isNotEmpty),
                  onSignInExisting: () => _signInExisting(
                    data.account.isAnonymous,
                    data.recentSessions.isNotEmpty,
                  ),
                );
                if (profile == null || !profile.underReview) return identity;
                // The owner hid or suspended the account (plan v3.9): said
                // in words, where the player looks for their account.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    const SizedBox(height: 12),
                    Text(
                      strings.profile.underReview,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.profile.underReviewDetail,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  strings.profile.mainLevel,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(width: 12),
                LevelBadge(level: globalLevel.floor(), large: true),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              strings.profile.change30Days(
                windowStart == null || windowEnd == null
                    ? null
                    : _formatDelta(windowEnd - windowStart),
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text(strings.profile.last30Days, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            _LevelCurve(sessions: data.windowSessions, now: data.now),
            const SizedBox(height: 24),
            Text(
              strings.profile.byOperation,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            for (final type in ExerciseType.values)
              _OperationRow(
                type: type,
                label: exerciseTypeLabel(type),
                level: data.levels[type]?.level,
                averageElapsedMs: data.avgElapsedMs[type],
              ),
            const SizedBox(height: 24),
            Text(
              strings.profile.recentGames,
              style: theme.textTheme.bodyMedium,
            ),
            // Levels follow the account; the history stays on each device
            // (Phase 6b commit 5, review M14: say so).
            if (!data.account.isAnonymous)
              Caption(strings.profile.otherDevices),
            if (data.pendingUploads > 0)
              Caption(strings.profile.notSentYet(data.pendingUploads)),
            const SizedBox(height: 8),
            if (data.recentSessions.isEmpty)
              Text(strings.profile.noGameYet, style: theme.textTheme.bodyMedium)
            else
              for (var i = 0; i < data.recentSessions.length; i++)
                _RecentSessionRow(
                  session: data.recentSessions[i],
                  previous: i + 1 < data.recentSessions.length
                      ? data.recentSessions[i + 1]
                      : null,
                ),
            const SizedBox(height: 24),
            FutureBuilder(
              future: _worstFacts,
              builder: (context, snapshot) => _WeakSpotsBlock(
                records: snapshot.data ?? const [],
                onPractise: _practise,
              ),
            ),
            const SizedBox(height: 24),
            FutureBuilder(
              future: _challengeStats,
              builder: (context, snapshot) =>
                  _ChallengesBlock(stats: snapshot.data ?? const {}),
            ),
            const SizedBox(height: 24),
            FutureBuilder(
              future: _tablesStats,
              builder: (context, snapshot) =>
                  _TablesBlock(stats: snapshot.data ?? TablesStats.none),
            ),
            const SizedBox(height: 24),
            _SettingsBlock(
              settings: widget.environment.effectSettings,
              onToggleTheme: widget.onToggleTheme,
              languageStore: widget.environment.languageStore,
              accounts: widget.environment.accountRepository,
            ),
            const SizedBox(height: 32),
            // The beta's feedback field (Phase 3a commit 5).
            if (widget.environment.feedbackRepository case final feedback?)
              Center(
                child: AppButton.secondary(
                  onPressed: () => _sendFeedback(feedback),
                  label: strings.profile.sendFeedback,
                ),
              ),
            // What is stored and how to delete it (Phase 3a commit 4; the
            // full pages since Phase 6c commit 2), right above the deletion
            // it describes.
            LegalLinks(
              privacyLabel: strings.profile.privacyPolicy,
              noticeLabel: strings.profile.legalNotice,
            ),
            // Last and quiet on purpose: irreversible, never next to the
            // everyday actions. Every player has it, guests included
            // (plan, section 6.3).
            Center(
              child: AppButton.secondary(
                destructive: true,
                onPressed: () => _deleteData(data.account),
                label: strings.profile.deleteButton(
                  guest: data.account.isAnonymous,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The widget's own `TextEditingController` (dispose() in its own `State`,
/// not right after `await showDialog(...)`): disposing it as soon as the
/// value arrives throws "used after being disposed", the `TextField` still
/// being referenced during the dialog's closing animation.
class _DisplayNameDialog extends StatefulWidget {
  const _DisplayNameDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<_DisplayNameDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _error;

  /// Closes with the name only if it passes the name rule (the database
  /// checks the same); otherwise says why, in place.
  void _submit() {
    final name = _controller.text.trim();
    final problem = displayNameProblem(name);
    if (problem != null) {
      setState(() => _error = describeNameProblem(problem));
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(strings.profile.playerName),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: maxDisplayNameLength,
        decoration: InputDecoration(errorText: _error, errorMaxLines: 3),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        AppButton.secondary(
          onPressed: () => Navigator.of(context).pop(),
          label: strings.common.cancel,
        ),
        AppButton.primary(onPressed: _submit, label: strings.profile.save),
      ],
    );
  }
}
