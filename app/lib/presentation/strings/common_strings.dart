/// Words every screen uses: buttons and short states.
abstract interface class CommonStrings {
  String get back;
  String get start;
  String get cancel;
  String get ok;
  String get close;
  String get retry;
  String get reload;
  String get signIn;
  String get gotIt;
  String get quit;
  String get player;
  String get unreachable;
  String get tryAgain;
}

/// CommonStrings in English.
class EnglishCommonStrings implements CommonStrings {
  const EnglishCommonStrings();

  @override
  final back = 'Back';

  @override
  final start = 'Start';

  @override
  final cancel = 'Cancel';

  @override
  final ok = 'OK';

  @override
  final close = 'Close';

  @override
  final retry = 'Retry';

  @override
  final reload = 'Reload';

  @override
  final signIn = 'Sign in';

  @override
  final gotIt = 'Got it';

  @override
  final quit = 'Quit';

  @override
  final player = 'Player';

  @override
  final unreachable = 'Could not reach the server.';

  @override
  final tryAgain = 'Could not reach the server — try again.';
}
