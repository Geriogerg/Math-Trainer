import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'composition_root.dart';
import 'core/domain/persistence/theme_mode_store.dart';
import 'presentation/screens/auth_gate.dart';
import 'presentation/theme/app_theme.dart';

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
  }

  Future<void> _loadThemeMode() async {
    // Purement auxiliaire : un échec ici laisse simplement le thème système
    // en place, même logique que `PlayTab._loadStartupState`.
    try {
      final stored = await widget.environment.themeModeStore.load();
      if (!mounted || stored == null) return;
      setState(() => _themeMode = _toThemeMode(stored));
    } on Exception catch (_) {
      // Reste sur le thème système déjà affiché.
    }
  }

  void _toggleTheme() {
    final isDark = switch (_themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      // Pas encore de choix explicite : se base sur la luminosité système
      // effective plutôt que de figer arbitrairement clair ou sombre.
      ThemeMode.system =>
        PlatformDispatcher.instance.platformBrightness == Brightness.dark,
    };
    final next = isDark ? ThemeModePreference.light : ThemeModePreference.dark;
    setState(() => _themeMode = _toThemeMode(next));
    widget.environment.themeModeStore.save(next);
  }

  ThemeMode _toThemeMode(ThemeModePreference preference) =>
      preference == ThemeModePreference.dark ? ThemeMode.dark : ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Math Trainer',
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
