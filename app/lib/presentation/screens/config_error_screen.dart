import 'package:material_ui/material_ui.dart';

import '../kit/kit.dart';
import '../theme/app_theme.dart';

/// Shown instead of the app when the build is badly prepared
/// (`MissingBackendConfigException`, `WebStorageUnavailableException`,
/// `composition_root.dart`) — a build error meant for the developer, never
/// a state a player can fix, hence the technical message — or when the
/// start failed for any other reason ([ConfigErrorApp.startFailed]), with
/// Reload.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({
    super.key,
    required this.title,
    required this.paragraphs,
    this.onReload,
  });

  /// The start's catch-all (Phase 6b commit 5, review M18): whatever
  /// failed, the player sees it and can reload; the detail is for a bug
  /// report.
  ConfigErrorApp.startFailed(
    Object error, {
    Key? key,
    void Function()? onReload,
  }) : this(
         key: key,
         title: 'The game could not start',
         paragraphs: [
           'Reload the page. If this happens again, try a little later.',
           'Detail: $error',
         ],
         onReload: onReload,
       );

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

  /// A Reload button; `null`: none (a build error, or no page to reload).
  final void Function()? onReload;

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
                  if (onReload case final reload?) ...[
                    const SizedBox(height: 24),
                    AppButton.primary(label: 'Reload', onPressed: reload),
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
