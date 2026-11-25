import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// The short privacy notice (plan v2.3, Phase 3a commit 4): what is stored,
/// why, and how to delete it — real people give data even in a beta. The
/// full legal pages come with the public launch (Phase 6). Plain text, no
/// link out: it must read the same offline.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const sections = <(String, List<String>)>[
    (
      'What is stored',
      [
        'Every game you play: each question, your answer, how long it took, '
            'whether it was right, and your level at the time.',
        'Your account: a random id; if you save your progress, your email '
            'and the player name you choose.',
        'During the beta: the invitation code you came in with, and any '
            'feedback you send (with the app version).',
        'Name reports you make, so a reported name can be reviewed.',
        'Online duels: each run you play (answers and times), its result '
            'and your duel ratings.',
        'Friends: your friend code, the requests you send and receive, and '
            'your friends.',
      ],
    ),
    (
      'Where',
      [
        'On this device, in the browser’s storage, so the game works '
            'offline.',
        'On the game’s servers (Supabase for accounts and data, Render '
            'for checking games), once you are online.',
      ],
    ),
    (
      'Why',
      [
        'To compute your levels and rank you on the leaderboard, and to '
            'check that every ranked game was really played.',
        'To tune the game: beta games show how fast players really are, so '
            'the levels can be set from real data.',
        'No ads, no third-party analytics, nothing sold or shared.',
      ],
    ),
    (
      'Who sees what',
      [
        'Other players see your player name and level on the leaderboard, '
            'only if you saved your progress. Never your email or your games.',
        'Players who race your duel runs see your player name, your duel '
            'rating and how fast you answered — never what you typed. Your '
            'friends see your name and the duels you played together.',
        'The game’s author can read the stored data to run the beta.',
      ],
    ),
    (
      'Deleting it',
      [
        'Profile → “Delete my data” (or “Delete my '
            'account”) removes your account and everything stored about '
            'you, on this device and on the servers, at once.',
        'A guest account unused for 30 days is deleted automatically.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: SafeArea(
        child: ListView(
          padding: theme.extension<AppMetrics>()!.rootPadding,
          children: [
            for (final (title, points) in sections) ...[
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final point in points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(point, style: theme.textTheme.bodyMedium),
                ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
