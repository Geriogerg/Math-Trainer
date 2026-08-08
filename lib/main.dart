import 'package:flutter/material.dart';

import 'app.dart';
import 'composition_root.dart';

Future<void> main() async {
  // Requis car on fait du travail asynchrone (ouverture de la base, lecture
  // des préférences) avant `runApp()`.
  WidgetsFlutterBinding.ensureInitialized();
  final environment = await buildAppEnvironment();
  runApp(MathTrainerApp(environment: environment));
}
