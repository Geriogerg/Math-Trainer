import 'package:material_ui/material_ui.dart';
import '../strings/strings.dart';

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
         title: strings.account.startFailedTitle,
         paragraphs: [
           strings.account.startFailedDetail,
           strings.account.detail(error),
         ],
         onReload: onReload,
       );

  ConfigErrorApp.missingBackendConfig(List<String> missingKeys, {Key? key})
    : this(
        key: key,
        title: strings.account.missingConfigTitle,
        paragraphs: [
          strings.account.missingConfig(missingKeys),
          strings.account.missingConfigFix,
        ],
      );

  ConfigErrorApp.webStorageUnavailable(Object cause, {Key? key})
    : this(
        key: key,
        title: strings.account.webStorageTitle,
        paragraphs: [
          strings.account.webStorageDetail,
          strings.account.webStorageFix,
          strings.account.detail(cause),
        ],
      );

  final String title;
  final List<String> paragraphs;

  /// A Reload button; `null`: none (a build error, or no page to reload).
  final void Function()? onReload;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: strings.account.appName,
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
                    AppButton.primary(
                      label: strings.common.reload,
                      onPressed: reload,
                    ),
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
