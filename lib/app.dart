import 'package:flutter/material.dart';

import 'composition_root.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/theme/app_theme.dart';

class MathTrainerApp extends StatelessWidget {
  const MathTrainerApp({super.key, required this.environment});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Math Trainer',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      // Le mode clair est obligatoire, pas une variante de confort
      // (`docs/design.md`) : c'est le système qui choisit, pas un bouton
      // dans l'app.
      themeMode: ThemeMode.system,
      home: HomeScreen(environment: environment),
    );
  }
}
