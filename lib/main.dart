import 'package:flutter/material.dart';

import 'app.dart';
import 'composition_root.dart';
import 'presentation/screens/config_error_screen.dart';

Future<void> main() async {
  // Requis car on fait du travail asynchrone (ouverture de la base, lecture
  // des préférences) avant `runApp()`.
  WidgetsFlutterBinding.ensureInitialized();
  final AppEnvironment environment;
  try {
    environment = await buildAppEnvironment();
  } on MissingBackendConfigException catch (e) {
    runApp(ConfigErrorApp(missingKeys: e.missingKeys));
    return;
  }
  runApp(MathTrainerApp(environment: environment));
}
