import 'dart:ui' show PlatformDispatcher;

import 'package:material_ui/material_ui.dart';

import 'composition_root.dart';
import 'package:math_core/persistence/theme_mode_store.dart';
import 'presentation/screens/auth_gate.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/strings/brand.dart';
import 'presentation/strings/strings.dart' show appLanguage, AppLanguage;

class MathTrainerApp extends StatefulWidget {
  const MathTrainerApp({super.key, required this.environment});

  final AppEnvironment environment;

  @override
  State<MathTrainerApp> createState() => _MathTrainerAppState();
}

class _MathTrainerAppState extends State<MathTrainerApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    appLanguage.addListener(_onLanguage);
  }

  @override
  void dispose() {
    appLanguage.removeListener(_onLanguage);
    super.dispose();
  }

  /// Another language (Phase 6d, Profile): every screen reads `strings` as
  /// it builds, without depending on anything that changes — so every
  /// element is rebuilt, keeping all state (the open tab, a game).
  void _onLanguage() {
    setState(() {});
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  Future<void> _loadThemeMode() async {
    // Purely auxiliary: a failure here just leaves the system theme in
    // place, same logic as `PlayTab._loadStartupState`.
    try {
      final stored = await widget.environment.themeModeStore.load();
      if (!mounted || stored == null) return;
      setState(() => _themeMode = _toThemeMode(stored));
    } on Exception catch (_) {
      // Stay on the system theme already shown.
    }
  }

  void _toggleTheme() {
    final isDark = switch (_themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      // No explicit choice yet: start from the effective system brightness
      // rather than arbitrarily fixing light or dark.
      ThemeMode.system =>
        PlatformDispatcher.instance.platformBrightness == Brightness.dark,
    };
    final next = isDark ? ThemeModePreference.light : ThemeModePreference.dark;
    setState(() => _themeMode = _toThemeMode(next));
    // Silent failure on purpose (auxiliary preference); `ignore()` keeps it
    // from surfacing as an unhandled asynchronous error.
    widget.environment.themeModeStore.save(next).ignore();
  }

  ThemeMode _toThemeMode(ThemeModePreference preference) =>
      preference == ThemeModePreference.dark ? ThemeMode.dark : ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Brand.name,
      // Flutter's own words (a back button's tooltip, a text field's
      // menu) in the same language (Phase 6d).
      locale: Locale(appLanguage.value.code),
      supportedLocales: [for (final l in AppLanguage.values) Locale(l.code)],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: _themeMode,
      home: AuthGate(
        environment: widget.environment,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
