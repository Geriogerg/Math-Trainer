import 'package:flutter/material.dart';

import '../../composition_root.dart';
import '../../core/domain/persistence/level_cache_entry.dart';
import '../../core/domain/models/exercise_type.dart';
import '../../core/domain/persistence/persisted_session.dart';
import '../exercise_type_labels.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';

const _windowDuration = Duration(days: 30);
const _recentSessionsLimit = 10;

/// Moyenne des niveaux d'une session/du cache courant, types non joués
/// exclus — sert de « niveau global » partout sur cet écran (niveau global,
/// courbe, variations). `null` si aucun type communiqué n'a de niveau.
double? _averageLevel(Iterable<int> levels) {
  final values = levels.toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

/// `+3`/`−3`/`0` — vrai signe moins U+2212 (`doc/design.md`), jamais `-`.
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

class _ProgressData {
  const _ProgressData({
    required this.levels,
    required this.avgElapsedMs,
    required this.windowSessions,
    required this.recentSessions,
  });

  final Map<ExerciseType, LevelCacheEntry> levels;
  final Map<ExerciseType, double> avgElapsedMs;

  /// `sessionsSince(playerId, now - 30 jours)`, triées ancien → récent.
  final List<PersistedSession> windowSessions;

  /// `recentSessions(limit: 10)`, triées récent → ancien.
  final List<PersistedSession> recentSessions;
}

/// Quatre blocs, du général au détail (`doc/design.md`) : niveau global et
/// variation récente, courbe de niveau sur 30 jours, ventilation par
/// opération (niveau + temps moyen), sessions récentes. Jamais un taux de
/// réussite ni un score comme mesure de progrès (`doc/decisions.md`) — ce
/// qui progresse, c'est le niveau.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.environment});

  final AppEnvironment environment;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late Future<_ProgressData> _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repository = widget.environment.repository;
    final playerId = widget.environment.playerId;
    final since = DateTime.now().toUtc().subtract(_windowDuration);
    _data = Future.wait([
      repository.currentLevels(playerId),
      repository.averageElapsedMsByType(playerId),
      repository.sessionsSince(playerId, since),
      repository.recentSessions(limit: _recentSessionsLimit),
    ]).then(
      (results) => _ProgressData(
        levels: results[0] as Map<ExerciseType, LevelCacheEntry>,
        avgElapsedMs: results[1] as Map<ExerciseType, double>,
        windowSessions: results[2] as List<PersistedSession>,
        recentSessions: results[3] as List<PersistedSession>,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<_ProgressData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            message: 'Impossible de charger la progression.',
            actionLabel: 'Réessayer',
            onAction: () => setState(_load),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final globalLevel = _averageLevel(data.levels.values.map((e) => e.level));
        final windowStart = _averageLevel(
          (data.windowSessions.isEmpty ? const <int>[] : data.windowSessions.first.levels.values),
        );

        return ListView(
          padding: theme.extension<AppMetrics>()!.rootPadding,
          children: [
            Text('Progression', style: theme.textTheme.titleMedium),
            const SizedBox(height: 24),
            Text(
              'Niveau global : ${globalLevel == null ? '—' : globalLevel.round()}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              windowStart == null || globalLevel == null
                  ? 'Variation (30 j) : —'
                  : 'Variation (30 j) : ${_formatDelta(globalLevel - windowStart)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text('Évolution (30 jours)', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            _LevelCurve(sessions: data.windowSessions),
            const SizedBox(height: 24),
            Text('Par opération', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            for (final type in ExerciseType.values)
              _OperationRow(
                label: exerciseTypeLabel(type),
                level: data.levels[type]?.level,
                averageElapsedMs: data.avgElapsedMs[type],
              ),
            const SizedBox(height: 24),
            Text('Sessions récentes', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            if (data.recentSessions.isEmpty)
              Text('Aucune session encore jouée.', style: theme.textTheme.bodyMedium)
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

class _OperationRow extends StatelessWidget {
  const _OperationRow({required this.label, required this.level, required this.averageElapsedMs});

  final String label;
  final int? level;
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
                    value: level == null ? 0 : level / 100,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.outline,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                level == null
                    ? 'Non joué'
                    : averageElapsedMs == null
                    ? 'Niveau $level'
                    : 'Niveau $level · ${averageElapsedMs.round()} ms',
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
    final currentAvg = _averageLevel(session.levels.values);
    final previousAvg = previous == null ? null : _averageLevel(previous!.levels.values);
    final variation = currentAvg == null || previousAvg == null
        ? '—'
        : _formatDelta(currentAvg - previousAvg);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(_shortDate(session.createdAt), style: theme.textTheme.bodyMedium)),
          Expanded(
            child: Text(
              'Score ${session.totalScore}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(variation, textAlign: TextAlign.end, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Trace simple (pas d'axe, pas de légende) reliant un point par session de
/// la fenêtre — X proportionnel à la date, Y la moyenne des niveaux figés de
/// cette session (`doc/design.md` : courbe d'évolution, rien de plus précis
/// n'est demandé). `CustomPainter` maison plutôt qu'une dépendance de
/// graphiques : un simple tracé ne le justifie pas (même logique que
/// `doc/decisions.md` pour `uuid`/`sqflite`).
class _LevelCurve extends StatelessWidget {
  const _LevelCurve({required this.sessions});

  final List<PersistedSession> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now().toUtc();
    final windowStart = now.subtract(_windowDuration);
    final spanMs = now.difference(windowStart).inMilliseconds;

    final points = <Offset>[];
    for (final session in sessions) {
      final avg = _averageLevel(session.levels.values);
      if (avg == null) continue;
      final xFrac = spanMs == 0
          ? 1.0
          : (session.createdAt.difference(windowStart).inMilliseconds / spanMs).clamp(0.0, 1.0);
      points.add(Offset(xFrac, avg));
    }

    if (points.length < 2) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Pas assez de données sur les 30 derniers jours.',
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
            maxLevel == minLevel ? 0.5 : (p.dy - minLevel) / (maxLevel - minLevel),
          ),
        )
        .toList();

    return SizedBox(
      height: 120,
      width: double.infinity,
      child: CustomPaint(
        painter: _LevelCurvePainter(points: normalized, color: theme.colorScheme.primary),
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
