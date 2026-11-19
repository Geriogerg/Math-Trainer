import 'package:material_ui/material_ui.dart';

import '../../composition_root.dart';
import '../../core/domain/account/account.dart';
import '../../core/domain/account/player_profile.dart';
import '../../core/domain/leveling/level.dart';
import '../../core/domain/persistence/level_cache_entry.dart';
import '../../core/domain/models/exercise_type.dart';
import '../../core/domain/persistence/persisted_session.dart';
import '../exercise_type_labels.dart';
import '../../core/domain/leveling/overall_level.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';

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
  });

  /// Frozen once per load — `_LevelCurve` positions its points relative to
  /// this value rather than calling `DateTime.now()` in its own `build()`:
  /// two separate calls would drift a few milliseconds apart, enough to
  /// shift the curve by a sub-pixel and make golden tests non-reproducible.
  final DateTime now;

  final Account account;
  final Map<ExerciseType, LevelCacheEntry> levels;
  final Map<ExerciseType, double> avgElapsedMs;

  /// `sessionsSince(playerId, now - 30 days)`, sorted old → recent.
  final List<PersistedSession> windowSessions;

  /// `recentSessions(playerId, limit: 10)`, sorted recent → old.
  final List<PersistedSession> recentSessions;
}

/// Formerly "Progress" (step 5). Renamed Profile in step 6, slice 2: it
/// now carries the identity (player name, email, sign-out) on top of the
/// existing statistics — an explicit owner decision revising the "profile
/// as a corner icon, no 5th tab" rule of `doc/design.md`.
///
/// Five blocks, from general to detailed: identity, overall level and its
/// recent change, 30-day level curve, breakdown per operation (level +
/// average time), recent sessions. Never an accuracy rate nor a score as a
/// measure of progress (`doc/decisions.md`) — what progresses is the level.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.environment,
    this.isActive = true,
  });

  final AppEnvironment environment;

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

  @override
  void initState() {
    super.initState();
    _load();
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
    final now = DateTime.now().toUtc();
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
        ]).then(
          (results) => _ProfileData(
            now: now,
            account: results[0] as Account,
            levels: results[1] as Map<ExerciseType, LevelCacheEntry>,
            avgElapsedMs: results[2] as Map<ExerciseType, double>,
            windowSessions: results[3] as List<PersistedSession>,
            recentSessions: results[4] as List<PersistedSession>,
          ),
        );
    _loadProfile();
  }

  void _loadProfile() {
    // `ignore()`: the `FutureBuilder` reading `_profile` only exists once
    // `_data` has resolved. If the name fails before that, the error has no
    // listener yet and surfaces as an unhandled asynchronous error. Marked
    // handled here, it is still delivered to the `FutureBuilder` when it
    // subscribes.
    _profile = widget.environment.profileRepository.currentProfile()..ignore();
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
    } catch (_) {
      // The old name stays shown; without this message, the player would
      // think the new name was saved (network down, `profiles` table missing).
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Name not saved — check your connection and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<_ProfileData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            message: 'Could not load the profile.',
            actionLabel: 'Retry',
            onAction: () => setState(_load),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final globalLevel = data.levels.isEmpty
            ? null
            : overallLevel(data.levels);
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
            Text('Profile', style: theme.textTheme.titleMedium),
            const SizedBox(height: 24),
            FutureBuilder<PlayerProfile>(
              future: _profile,
              builder: (context, profileSnapshot) {
                final profile = profileSnapshot.data;
                return _IdentityBlock(
                  account: data.account,
                  profile: profile,
                  profileFailed: profileSnapshot.hasError,
                  onEditName: profile == null
                      ? null
                      : () => _editDisplayName(profile),
                  onRetryProfile: () => setState(_loadProfile),
                  onSignOut: widget.environment.accountRepository.signOut,
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Overall level: ${globalLevel == null ? '—' : globalLevel.round()}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              windowStart == null || windowEnd == null
                  ? '30-day change: —'
                  : '30-day change: ${_formatDelta(windowEnd - windowStart)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text('Last 30 days', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            _LevelCurve(sessions: data.windowSessions, now: data.now),
            const SizedBox(height: 24),
            Text('By operation', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            for (final type in ExerciseType.values)
              _OperationRow(
                label: exerciseTypeLabel(type),
                level: data.levels[type]?.level,
                averageElapsedMs: data.avgElapsedMs[type],
              ),
            const SizedBox(height: 24),
            Text('Recent sessions', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            if (data.recentSessions.isEmpty)
              Text('No session played yet.', style: theme.textTheme.bodyMedium)
            else
              for (var i = 0; i < data.recentSessions.length; i++)
                _RecentSessionRow(
                  session: data.recentSessions[i],
                  previous: i + 1 < data.recentSessions.length
                      ? data.recentSessions[i + 1]
                      : null,
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Player name'),
      // 30: same bound as the `check` constraint in `supabase/profiles.sql`,
      // otherwise a longer name would be refused by the database with no
      // visible feedback.
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 30,
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({
    required this.account,
    required this.profile,
    required this.profileFailed,
    required this.onEditName,
    required this.onRetryProfile,
    required this.onSignOut,
  });

  final Account account;

  /// `null` while the name is loading or has failed.
  final PlayerProfile? profile;
  final bool profileFailed;

  /// `null` (button disabled) until the profile is loaded.
  final VoidCallback? onEditName;
  final VoidCallback onRetryProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = this.profile;
    final String nameLine;
    if (profileFailed) {
      nameLine = 'Player name unavailable';
    } else if (profile == null) {
      nameLine = '…';
    } else {
      nameLine = profile.displayName ?? 'Choose a player name';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(nameLine, style: theme.textTheme.titleMedium)),
            if (profileFailed)
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reload player name',
                onPressed: onRetryProfile,
              )
            else
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit player name',
                onPressed: onEditName,
              ),
          ],
        ),
        Text(
          account.email ?? 'Guest — progress saved on this device only',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.extension<AppPalette>()!.textMuted,
          ),
        ),
        // Never for a guest: signing out would lose the account for good
        // (plan, section 6.3). Account actions for guests: commit 5.
        if (!account.isAnonymous) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: onSignOut, child: const Text('Sign out')),
        ],
      ],
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({
    required this.label,
    required this.level,
    required this.averageElapsedMs,
  });

  final String label;
  final Level? level;
  final double? averageElapsedMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = this.level;
    final averageElapsedMs = this.averageElapsedMs;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    // Continuous: the bar shows the hundredths the
                    // whole-number label leaves out.
                    value: level == null ? 0 : level.value / 100,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.outline,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                level == null
                    ? 'Not played'
                    : averageElapsedMs == null
                    ? 'Level ${level.whole}'
                    : 'Level ${level.whole} · ${averageElapsedMs.round()} ms',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentSessionRow extends StatelessWidget {
  const _RecentSessionRow({required this.session, required this.previous});

  final PersistedSession session;
  final PersistedSession? previous;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Nothing else changes the level cache between two sessions: the gap
    // between the two "after" overall levels is exactly the effect of this
    // session.
    final after = session.overallLevelAfter;
    final previousAfter = previous?.overallLevelAfter;
    final variation = after == null || previousAfter == null
        ? '—'
        : _formatDelta(after - previousAfter);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _shortDate(session.createdAt),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              'Score ${session.totalScore}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              variation,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// A plain trace (no axis, no legend) linking one point per session of the
/// window — X proportional to the date, Y the overall level right after
/// that session (`PersistedSession.overallLevelAfter`: the same scale from
/// one session to the next, whatever types were played, and the last game
/// appears). Sessions without that value (older than schema v3) are
/// skipped. `doc/design.md` asks for a level curve, nothing more precise.
/// A home-made `CustomPainter` rather than a charting dependency: a simple
/// trace does not justify one (same logic as `doc/decisions.md` for
/// `uuid`/`sqflite`).
class _LevelCurve extends StatelessWidget {
  const _LevelCurve({required this.sessions, required this.now});

  final List<PersistedSession> sessions;

  /// Frozen by the caller (`_ProfileData.now`), never recomputed here — see
  /// the comment on `_ProfileData.now`.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final windowStart = now.subtract(_windowDuration);
    final spanMs = now.difference(windowStart).inMilliseconds;

    final points = <Offset>[];
    for (final session in sessions) {
      final level = session.overallLevelAfter;
      if (level == null) continue;
      final xFrac = spanMs == 0
          ? 1.0
          : (session.createdAt.difference(windowStart).inMilliseconds / spanMs)
                .clamp(0.0, 1.0);
      points.add(Offset(xFrac, level));
    }

    if (points.length < 2) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Not enough data for the last 30 days.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final levels = points.map((p) => p.dy);
    final minLevel = levels.reduce((a, b) => a < b ? a : b);
    final maxLevel = levels.reduce((a, b) => a > b ? a : b);
    final normalized = points
        .map(
          (p) => Offset(
            p.dx,
            maxLevel == minLevel
                ? 0.5
                : (p.dy - minLevel) / (maxLevel - minLevel),
          ),
        )
        .toList();

    return SizedBox(
      height: 120,
      width: double.infinity,
      child: CustomPaint(
        painter: _LevelCurvePainter(
          points: normalized,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _LevelCurvePainter extends CustomPainter {
  _LevelCurvePainter({required this.points, required this.color});

  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final mapped = Offset(p.dx * size.width, (1 - p.dy) * size.height);
      if (i == 0) {
        path.moveTo(mapped.dx, mapped.dy);
      } else {
        path.lineTo(mapped.dx, mapped.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LevelCurvePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
