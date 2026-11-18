import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Affichée à la place de l'app quand le build est mal préparé
/// (`MissingBackendConfigException`, `WebStorageUnavailableException`,
/// `composition_root.dart`) — une erreur de build destinée au développeur,
/// jamais un état qu'un joueur peut corriger, d'où le message technique.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({
    super.key,
    required this.title,
    required this.paragraphs,
  });

  ConfigErrorApp.missingBackendConfig(List<String> missingKeys, {Key? key})
    : this(
        key: key,
        title: 'Configuration manquante',
        paragraphs: [
          'Ce build a été lancé sans la configuration Supabase '
              '(${missingKeys.join(', ')}).',
          'Relancer avec :\n'
              '--dart-define-from-file=dart_defines.json\n\n'
              'Modèle : dart_defines.example.json',
        ],
      );

  ConfigErrorApp.webStorageUnavailable(Object cause, {Key? key})
    : this(
        key: key,
        title: 'Stockage web indisponible',
        paragraphs: [
          'La base locale n\'a pas pu s\'ouvrir dans le navigateur : '
              'web/sqlite3.wasm ou web/sqflite_sw.js manquent probablement.',
          'Les générer une fois, depuis le dossier du projet :\n'
              'dart run sqflite_common_ffi_web:setup',
          'Détail : $cause',
        ],
      );

  final String title;
  final List<String> paragraphs;

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
                  Text(title, style: theme.textTheme.titleMedium),
                  for (final paragraph in paragraphs) ...[
                    const SizedBox(height: 16),
                    Text(paragraph, style: theme.textTheme.bodyMedium),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
