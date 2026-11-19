import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'composition_root.dart';
import 'presentation/screens/config_error_screen.dart';

Future<void> main() async {
  // Required because asynchronous work happens (opening the database,
  // reading preferences) before `runApp()`.
  WidgetsFlutterBinding.ensureInitialized();
  final AppEnvironment environment;
  try {
    environment = await buildAppEnvironment();
  } on MissingBackendConfigException catch (e) {
    runApp(ConfigErrorApp.missingBackendConfig(e.missingKeys));
    return;
  } on WebStorageUnavailableException catch (e) {
    runApp(ConfigErrorApp.webStorageUnavailable(e.cause));
    return;
  }
  runApp(MathTrainerApp(environment: environment));
}
