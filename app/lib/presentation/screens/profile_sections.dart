// Profile's sections — identity, operations, recent games, the curve,
// challenges, Tables, weak spots, settings: split out of profile_screen.dart
// at Phase 6b's close (review m12: files that carry too much).
part of 'profile_screen.dart';

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({
    required this.account,
    required this.profile,
    required this.profileFailed,
    required this.onEditName,
    required this.onRetryProfile,
    required this.onSignOut,
    required this.onSaveProgress,
    required this.onSignInExisting,
  });

  final Account account;

  /// `null` while the name is loading or has failed.
  final PlayerProfile? profile;
  final bool profileFailed;

  /// `null` (button disabled) until the profile is loaded.
  final VoidCallback? onEditName;
  final VoidCallback onRetryProfile;
  final VoidCallback onSignOut;
  final VoidCallback onSaveProgress;
  final VoidCallback onSignInExisting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = this.profile;
    final String nameLine;
    if (profileFailed) {
      nameLine = strings.profile.playerNameUnavailable;
    } else if (profile == null) {
      nameLine = '…';
    } else {
      nameLine = profile.displayName ?? strings.profile.choosePlayerName;
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
                tooltip: strings.profile.reloadPlayerName,
                onPressed: onRetryProfile,
              )
            else
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: strings.profile.editPlayerName,
                onPressed: onEditName,
              ),
          ],
        ),
        Text(
          account.email ?? strings.profile.guestLine,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.extension<AppPalette>()!.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        // A guest: save the progress, or sign in to an existing account —
        // never a sign-out, which would lose the account for good (plan,
        // section 6.3). Deletion: "Delete my data" (commit 7).
        if (account.isAnonymous)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppButton.primary(
                onPressed: onSaveProgress,
                label: strings.profile.saveYourProgress,
              ),
              AppButton.secondary(
                onPressed: onSignInExisting,
                label: strings.profile.haveAccount,
              ),
            ],
          )
        else
          AppButton.secondary(
            onPressed: onSignOut,
            label: strings.profile.signOut,
          ),
      ],
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({
    required this.type,
    required this.label,
    required this.level,
    required this.averageElapsedMs,
  });

  final ExerciseType type;
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
          Row(
            children: [
              OperatorIcon(type),
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.bodyLarge),
            ],
          ),
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
                    backgroundColor: theme.colorScheme.outlineVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (level == null)
                Text(
                  strings.profile.notPlayed,
                  style: theme.textTheme.bodyMedium,
                )
              else ...[
                if (averageElapsedMs != null) ...[
                  Text(
                    strings.game.secondsValue(averageElapsedMs),
                    style: theme.textTheme.bodyMedium?.digits,
                  ),
                  const SizedBox(width: 8),
                ],
                LevelBadge(level: level.whole),
              ],
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
    // Across the Levels phase's reset the two are on different scales
    // (v1 against v2 and later; v2, v3 and v4 share one).
    final previous = this.previous;
    final previousAfter =
        previous != null &&
            previous.rulesVersion.retired == session.rulesVersion.retired
        ? previous.overallLevelAfter
        : null;
    final variation = after == null || previousAfter == null
        ? '—'
        : _formatDelta(after - previousAfter);

    final row = Row(
      children: [
        Expanded(
          child: Text(
            _shortDate(session.createdAt),
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: Text(
            // A placement's score means nothing; say what it was.
            session.kind.isPlacement
                ? strings.profile.placement
                : strings.profile.score(session.totalScore),
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
    );
    final refused = session.uploadRefused;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: refused == null
          ? row
          // The game stays in the history (and the curve); only the board
          // ignores it — said in words, under the row (Phase 3a commit 2).
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                row,
                const SizedBox(height: 2),
                Text(
                  uploadRefusalText(refused),
                  style: theme.textTheme.bodySmall,
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
            strings.profile.notEnoughData,
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

/// The game's effects, switched per device (Phase 5): sound and vibration,
/// both on by default. A device that cannot vibrate (Safari on iPhone)
/// shows the switch disabled, and says why.
/// The two challenges' records: games, solved, best time (labels only).
class _ChallengesBlock extends StatelessWidget {
  const _ChallengesBlock({required this.stats});

  final Map<Challenge, ChallengeStats> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.profile.challenges, style: theme.textTheme.titleMedium),
        for (final challenge in Challenge.values) ...[
          const SizedBox(height: 12),
          Text(
            strings.profile.challenge(challenge),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final s = stats[challenge] ?? ChallengeStats.none;
              final best = s.bestTimeMs;
              return Row(
                children: [
                  Expanded(
                    child: StatTile(
                      value: '${s.games}',
                      label: strings.profile.games,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatTile(
                      value: '${s.solved}',
                      label: strings.profile.solved,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatTile(
                      value: best == null
                          ? '—'
                          : strings.game.secondsValue(best),
                      label: strings.profile.best,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Tables mode's stats (`doc/levels.md` section 7), on the device: rounds,
/// right answers as a raw count (never a rate presented as progress), and
/// the three slowest facts.
class _TablesBlock extends StatelessWidget {
  const _TablesBlock({required this.stats});

  final TablesStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slowest = stats.slowest(3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.profile.tables, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: StatTile(
                value: '${stats.games}',
                label: strings.profile.games,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                value: '${stats.right} / ${stats.answers}',
                label: strings.profile.right,
              ),
            ),
          ],
        ),
        if (slowest.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(strings.profile.slowest, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 4),
          for (final fact in slowest)
            Text(
              '${fact.table} × ${fact.multiplier}   '
              '${strings.game.secondsValue(fact.averageMs)}',
              style: theme.textTheme.bodyLarge?.digits,
            ),
        ],
      ],
    );
  }
}

/// Phase 4: the five slowest or most-missed facts, with a Practice button.
class _WeakSpotsBlock extends StatelessWidget {
  const _WeakSpotsBlock({required this.records, required this.onPractise});

  final List<WeakFact> records;
  final ValueChanged<List<WeakFact>> onPractise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.profile.weakSpots, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (records.isEmpty)
          Text(strings.profile.noneYet, style: theme.textTheme.bodyMedium)
        else ...[
          for (final r in records)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ExercisePrompt(
                        exercise: exercisesOf(r.fact).first,
                        style: style?.digits,
                      ),
                    ),
                  ),
                  Text(
                    r.misses > 0
                        ? strings.profile.missedOf(r.misses, r.answers)
                        : strings.game.secondsValue(r.meanCorrectMs!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          AppButton.secondary(
            key: const ValueKey('practise-weak-spots'),
            label: strings.profile.practice,
            onPressed: () => onPractise(records),
          ),
        ],
      ],
    );
  }
}

/// Labels only (Redesign phase): the switch says what it is.
class _SettingsBlock extends StatelessWidget {
  const _SettingsBlock({
    required this.settings,
    required this.onToggleTheme,
    required this.languageStore,
    required this.accounts,
  });

  final EffectSettings? settings;
  final VoidCallback? onToggleTheme;
  final LanguageStore? languageStore;

  /// The account keeps the language of its emails (Phase 6d).
  final AccountRepository accounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = this.settings;
    final onToggleTheme = this.onToggleTheme;
    final rows = <Widget>[
      Text(strings.profile.settings, style: theme.textTheme.titleMedium),
      // The interface's language (Phase 6d): the browser's until chosen.
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Semantics(
          label: strings.profile.language,
          child: SegmentedChoice<AppLanguage>(
            values: AppLanguage.values,
            selected: appLanguage.value,
            label: languageName,
            onChanged: (language) {
              useLanguage(language);
              languageStore?.save(language).ignore();
              accounts.rememberLanguage(language.code).ignore();
            },
          ),
        ),
      ),
      if (onToggleTheme != null)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            strings.profile.darkMode,
            style: theme.textTheme.bodyLarge,
          ),
          value: theme.brightness == Brightness.dark,
          onChanged: (_) => onToggleTheme(),
        ),
    ];
    if (settings == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      );
    }
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rows,
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              strings.profile.sound,
              style: theme.textTheme.bodyLarge,
            ),
            value: settings.sound,
            onChanged: settings.setSound,
          ),
          // Disabled where the browser cannot vibrate.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              strings.profile.vibration,
              style: theme.textTheme.bodyLarge,
            ),
            value: settings.haptics,
            onChanged: settings.hapticsSupported ? settings.setHaptics : null,
          ),
        ],
      ),
    );
  }
}
