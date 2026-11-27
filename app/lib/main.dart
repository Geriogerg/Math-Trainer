import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'composition_root.dart';
import 'infrastructure/web/page_reload.dart';
import 'presentation/screens/config_error_screen.dart';
import 'presentation/screens/specimen_screen.dart';

Future<void> main() async {
  // Required because asynchronous work happens (opening the database,
  // reading preferences) before `runApp()`.
  WidgetsFlutterBinding.ensureInitialized();
  // The accessibility tree from the start (Phase 6b commit 6, review M17):
  // on the web Flutter builds it only once a screen reader finds and
  // presses a hidden "Enable accessibility" button, which several miss.
  // Never disposed: on for the app's lifetime.
  SemanticsBinding.instance.ensureSemantics();
  // The digit-typeface specimen (Phase 5 commit 1): `?specimen` in the
  // address, debug and preview builds only — before any account or
  // database, it needs neither.
  if (specimenAvailable && Uri.base.queryParameters.containsKey('specimen')) {
    runApp(const SpecimenApp());
    return;
  }
  final AppEnvironment environment;
  try {
    environment = await buildAppEnvironment();
  } on MissingBackendConfigException catch (e) {
    runApp(ConfigErrorApp.missingBackendConfig(e.missingKeys));
    return;
  } on WebStorageUnavailableException catch (e) {
    runApp(ConfigErrorApp.webStorageUnavailable(e.cause));
    return;
  } catch (e) {
    // Anything else (Phase 6b commit 5, review M18): the page used to stay
    // on "Almost there…" for ever. Now a screen says so, with Reload.
    runApp(ConfigErrorApp.startFailed(e, onReload: reloadPage));
    return;
  }
  runApp(MathTrainerApp(environment: environment));
}
