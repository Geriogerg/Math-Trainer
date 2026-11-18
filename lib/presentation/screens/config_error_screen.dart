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
        title: 'Missing configuration',
        paragraphs: [
          'This build was started without the Supabase configuration '
              '(${missingKeys.join(', ')}).',
          'Run it again with:\n'
              '--dart-define-from-file=dart_defines.json\n\n'
              'Template: dart_defines.example.json',
        ],
      );

  ConfigErrorApp.webStorageUnavailable(Object cause, {Key? key})
    : this(
        key: key,
        title: 'Web storage unavailable',
        paragraphs: [
          'The local database could not open in the browser: '
              'web/sqlite3.wasm or web/sqflite_sw.js is probably missing.',
          'Generate them once, from the project folder:\n'
              'dart run sqflite_common_ffi_web:setup',
          'Detail: $cause',
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
