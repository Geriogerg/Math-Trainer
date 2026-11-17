import 'package:flutter/material.dart';

import '../../composition_root.dart';
import '../../core/domain/account/account.dart';
import '../../core/domain/account/player_profile.dart';
import '../../core/domain/persistence/level_cache_entry.dart';
import '../../core/domain/models/exercise_type.dart';
import '../../core/domain/persistence/persisted_session.dart';
import '../exercise_type_labels.dart';
import '../level_summary.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';

const _windowDuration = Duration(days: 30);
const _recentSessionsLimit = 10;

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

class _ProfileData {
  const _ProfileData({
    required this.now,
    required this.account,
    required this.levels,
    required this.avgElapsedMs,
    required this.windowSessions,
    required this.recentSessions,
  });

  /// Figé une seule fois par chargement — `_LevelCurve` positionne ses
  /// points par rapport à cette valeur plutôt que d'appeler `DateTime.now()`
  /// dans son propre `build()` : deux appels séparés dériveraient de
  /// quelques millisecondes l'un de l'autre, assez pour décaler la courbe
  /// d'un sous-pixel et rendre les tests de golden non reproductibles.
  final DateTime now;

  final Account account;
  final Map<ExerciseType, LevelCacheEntry> levels;
  final Map<ExerciseType, double> avgElapsedMs;

  /// `sessionsSince(playerId, now - 30 jours)`, triées ancien → récent.
  final List<PersistedSession> windowSessions;

  /// `recentSessions(limit: 10)`, triées récent → ancien.
  final List<PersistedSession> recentSessions;
}

/// Anciennement « Progression » (étape 5). Renommé Profil à l'étape 6,
/// tranche 2 : porte désormais l'identité (nom de joueur, email,
/// déconnexion) en plus des statistiques déjà existantes — décision
/// explicite de l'utilisateur, qui révise la règle « profil en icône de
/// coin, pas de 5ᵉ onglet » de `doc/design.md`.
///
/// Cinq blocs, du général au détail : identité, niveau global et variation
/// récente, courbe d'évolution du niveau sur 30 jours, ventilation par
/// opération (niveau + temps moyen), sessions récentes. Jamais un taux de
/// réussite ni un score comme mesure de progrès (`doc/decisions.md`) — ce
/// qui progresse, c'est le niveau.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.environment,
    this.isActive = true,
  });

  final AppEnvironment environment;

  /// Vrai quand cet onglet est celui affiché par `AppShell`. `IndexedStack`
  /// garde ce widget monté après sa première visite (`app_shell.dart`), donc
  /// sans ce signal `_load()` ne serait jamais rejouée après une nouvelle
  /// session : `initState` ne se déclenche qu'une fois par cycle de vie.
  final bool isActive;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Tout ce qui est local (compte en session, niveaux, historique) : jamais
  /// de réseau, donc disponible hors ligne.
  late Future<_ProfileData> _data;

  /// Le nom de joueur, seule lecture réseau de l'écran — chargé à part pour
  /// qu'un échec (hors ligne, Supabase indisponible) n'affecte que la ligne
  /// du nom, pas les statistiques locales.
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
          // `AuthGate` garantit un compte connecté avant d'atteindre cet écran,
          // et `authState` émet d'abord l'état courant (`account_repository.dart`)
          // — `.first` le lit sans appel réseau.
          environment.accountRepository.authState.first,
          repository.currentLevels(playerId),
          repository.averageElapsedMsByType(playerId),
          repository.sessionsSince(playerId, since),
          repository.recentSessions(limit: _recentSessionsLimit),
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
    // `ignore()` : le `FutureBuilder` qui lit `_profile` n'existe qu'une fois
    // `_data` résolu. Si le nom échoue avant, l'erreur n'a encore aucun
    // écouteur et remonte comme erreur asynchrone non gérée. Marquée gérée
    // ici, elle reste transmise au `FutureBuilder` quand il s'abonne.
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
      // L'ancien nom reste affiché ; sans ce message, le joueur croirait
      // son nouveau nom enregistré (réseau coupé, table `profiles` absente).
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nom non enregistré — vérifie ta connexion et réessaie.',
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
            message: 'Impossible de charger le profil.',
            actionLabel: 'Réessayer',
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
        // Comparaison entre deux instantanés de session de même échelle
        // (types touchés ce jour-là), pas entre le cache live (7 types,
        // `globalLevel` ci-dessus) et un instantané de session (1-2 types) —
        // ce dernier ferait sauter la variation sans rapport avec un vrai
        // progrès dès qu'un joueur ne couvre pas tous les types.
        final windowStart = averageLevel(
          (data.windowSessions.isEmpty
              ? const <int>[]
              : data.windowSessions.first.levels.values),
        );
        final windowEnd = averageLevel(
          (data.windowSessions.isEmpty
              ? const <int>[]
              : data.windowSessions.last.levels.values),
        );

        return ListView(
          padding: theme.extension<AppMetrics>()!.rootPadding,
          children: [
            Text('Profil', style: theme.textTheme.titleMedium),
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
              'Niveau global : ${globalLevel == null ? '—' : globalLevel.round()}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              windowStart == null || windowEnd == null
                  ? 'Variation (30 j) : —'
                  : 'Variation (30 j) : ${_formatDelta(windowEnd - windowStart)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text('Évolution (30 jours)', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            _LevelCurve(sessions: data.windowSessions, now: data.now),
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
              Text(
                'Aucune session encore jouée.',
                style: theme.textTheme.bodyMedium,
              )
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

/// `TextEditingController` propre au widget (dispose() dans son propre
/// `State`, pas juste après `await showDialog(...)`) : le disposer aussitôt
/// la valeur reçue lève « used after being disposed », le `TextField` restant
/// référencé pendant l'animation de fermeture du dialogue.
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
      title: const Text('Nom de joueur'),
      // 30 : même borne que la contrainte `check` de `supabase/profiles.sql`,
      // sinon un nom plus long serait refusé par la base sans retour visible.
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 30,
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Enregistrer'),
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

  /// `null` tant que le nom est en cours de chargement ou en échec.
  final PlayerProfile? profile;
  final bool profileFailed;

  /// `null` (bouton désactivé) tant que le profil n'est pas chargé.
  final VoidCallback? onEditName;
  final VoidCallback onRetryProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = this.profile;
    final String nameLine;
    if (profileFailed) {
      nameLine = 'Nom de joueur indisponible';
    } else if (profile == null) {
      nameLine = '…';
    } else {
      nameLine = profile.displayName ?? 'Choisir un nom de joueur';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(nameLine, style: theme.textTheme.titleMedium),
            ),
            if (profileFailed)
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Recharger le nom de joueur',
                onPressed: onRetryProfile,
              )
            else
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Modifier le nom de joueur',
                onPressed: onEditName,
              ),
          ],
        ),
        Text(
          account.email,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.extension<AppPalette>()!.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onSignOut, child: const Text('Se déconnecter')),
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
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
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
    final currentAvg = averageLevel(session.levels.values);
    final previousAvg = previous == null
        ? null
        : averageLevel(previous!.levels.values);
    final variation = currentAvg == null || previousAvg == null
        ? '—'
        : _formatDelta(currentAvg - previousAvg);

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

/// Trace simple (pas d'axe, pas de légende) reliant un point par session de
/// la fenêtre — X proportionnel à la date, Y la moyenne des niveaux figés de
/// cette session (`doc/design.md` : courbe d'évolution, rien de plus précis
/// n'est demandé). `CustomPainter` maison plutôt qu'une dépendance de
/// graphiques : un simple tracé ne le justifie pas (même logique que
/// `doc/decisions.md` pour `uuid`/`sqflite`).
class _LevelCurve extends StatelessWidget {
  const _LevelCurve({required this.sessions, required this.now});

  final List<PersistedSession> sessions;

  /// Figé par l'appelant (`_ProfileData.now`), jamais recalculé ici — voir
  /// le commentaire sur `_ProfileData.now`.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final windowStart = now.subtract(_windowDuration);
    final spanMs = now.difference(windowStart).inMilliseconds;

    final points = <Offset>[];
    for (final session in sessions) {
      final avg = averageLevel(session.levels.values);
      if (avg == null) continue;
      final xFrac = spanMs == 0
          ? 1.0
          : (session.createdAt.difference(windowStart).inMilliseconds / spanMs)
                .clamp(0.0, 1.0);
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
