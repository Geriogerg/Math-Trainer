/// Number of questions in a session: enough for every active type to reach
/// `n_min` (so its level cache can be updated), capped to keep the session
/// at an acceptable length. The cap is a duration target disguised as a
/// question count — see `doc/decisions.md`.
int sessionLengthFor({
  required int activeTypeCount,
  required int nMin,
  required int cap,
}) {
  if (activeTypeCount <= 0) {
    throw ArgumentError.value(
      activeTypeCount,
      'activeTypeCount',
      'must be positive.',
    );
  }
  final uncapped = nMin * activeTypeCount;
  return uncapped < cap ? uncapped : cap;
}
