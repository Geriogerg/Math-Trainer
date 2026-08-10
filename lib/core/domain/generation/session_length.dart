/// Nombre de questions d'une session : assez pour que chaque type actif
/// atteigne `n_min` (donc que son cache de niveau puisse être mis à jour),
/// plafonné pour rester une durée de session acceptable. Le plafond est une
/// cible de durée déguisée en compte de questions — voir `doc/decisions.md`.
int sessionLengthFor({required int activeTypeCount, required int nMin, required int cap}) {
  if (activeTypeCount <= 0) {
    throw ArgumentError.value(activeTypeCount, 'activeTypeCount', 'doit être positif.');
  }
  final uncapped = nMin * activeTypeCount;
  return uncapped < cap ? uncapped : cap;
}
