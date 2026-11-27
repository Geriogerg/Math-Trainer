import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'composition_root.dart';
import 'infrastructure/web/page_reload.dart';
import 'presentation/screens/config_error_screen.dart';
import 'presentation/screens/specimen_screen.dart';
import 'core/errors/error_reporter.dart';

/// Whether the accessibility tree is built for everyone (plan v4.1: kept,
/// measured on a low-end phone profile in Phase 6c).
const semanticsAlways = bool.fromEnvironment(
  'SEMANTICS_ALWAYS',
  defaultValue: true,
);

Future<void> main() async {
  // Required because asynchronous work happens (opening the database,
  // reading preferences) before `runApp()`.
  WidgetsFlutterBinding.ensureInitialized();
  // What goes wrong is reported to our own server (Phase 6c commit 5).
  final errors = createErrorReporter();
  installErrorReporting(errors);
  // The accessibility tree from the start (Phase 6b commit 6, review M17):
  // on the web Flutter builds it only once a screen reader finds and
  // presses a hidden "Enable accessibility" button, which several miss.
  // Never disposed: on for the app's lifetime. `SEMANTICS_ALWAYS=false`
  // leaves it to that button — the build measured against this one
  // (Phase 6c commit 0, `tool/perf/semantics_cost.mjs`).
  if (semanticsAlways) SemanticsBinding.instance.ensureSemantics();
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
  } catch (e, stack) {
    // Anything else (Phase 6b commit 5, review M18): the page used to stay
    // on "Almost there…" for ever. Now a screen says so, with Reload.
    errors.report(ErrorKind.start, e, stack);
    runApp(ConfigErrorApp.startFailed(e, onReload: reloadPage));
    return;
  }
  runApp(MathTrainerApp(environment: environment));
}
