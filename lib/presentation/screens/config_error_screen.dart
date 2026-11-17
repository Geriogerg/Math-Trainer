import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Affichée à la place de l'app quand le build n'embarque pas la
/// configuration Supabase (`MissingBackendConfigException`,
/// `composition_root.dart`) — une erreur de build destinée au développeur,
/// jamais un état qu'un joueur peut corriger, d'où le message technique.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.missingKeys});

  final List<String> missingKeys;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Math Trainer',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: Scaffold(
        body: SafeArea(
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              return ListView(
                padding: theme.extension<AppMetrics>()!.rootPadding,
                children: [
                  Text(
                    'Configuration manquante',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ce build a été lancé sans la configuration Supabase '
                    '(${missingKeys.join(', ')}).',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Relancer avec :\n'
                    '--dart-define-from-file=dart_defines.json\n\n'
                    'Modèle : dart_defines.example.json',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
