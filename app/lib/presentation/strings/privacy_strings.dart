/// The in-app privacy notice (plan v2.3, Phase 3a commit 4; moved here
/// with every other word in Phase 6b commit 7): what is stored, why,
/// and how to delete it. Plain text: it must read the same offline.
const privacyTitle = 'Privacy';

const privacySections = <(String, List<String>)>[
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
      'Fair play: marks the server puts on a game or duel whose timing '
          'looks impossible, and, if the game’s author puts your '
          'account under review, that decision and its reason.',
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
      'To compute your levels and rank you on the boards (Ranks), and to '
          'check that every ranked game was really played.',
      'To tune the game: beta games show how fast players really are, so '
          'the levels can be set from real data.',
      'No ads, no third-party analytics, nothing sold or shared.',
    ],
  ),
  (
    'Who sees what',
    [
      'Other players see your player name and level on Ranks, '
          'only if you saved your progress. Never your email or your games. '
          'A name another player reports is hidden until it is reviewed.',
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
      'Duels you played stay in your opponents’ history as “Deleted '
          'player”: the result and how fast each answer came, never your '
          'name or what you typed.',
      'A guest account unused for 30 days is deleted automatically.',
    ],
  ),
];
