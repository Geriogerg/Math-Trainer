import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Écran générique pour un onglet dont la barre de navigation existe déjà
/// mais dont la fonctionnalité est hors périmètre de l'étape en cours
/// (`doc/decisions.md` : « chrome posé, contenu en attente »).
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        '$label — bientôt disponible',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.extension<AppPalette>()?.textMuted,
        ),
      ),
    );
  }
}
