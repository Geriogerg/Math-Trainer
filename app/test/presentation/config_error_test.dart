import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/presentation/screens/config_error_screen.dart';

void main() {
  // `flutter test` passes no `--dart-define`: exactly the situation of a
  // build started without `dart_defines.json`.
  test(
    'buildAppEnvironment refuses to start without the Supabase configuration',
    () async {
      await expectLater(
        buildAppEnvironment(),
        throwsA(
          isA<MissingBackendConfigException>().having(
            (e) => e.missingKeys,
            'missingKeys',
            ['SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY'],
          ),
        ),
      );
    },
  );

  testWidgets('any other start failure: said, with Reload (Phase 6b commit '
      '5, review M18)', (tester) async {
    var reloads = 0;
    await tester.pumpWidget(
      ConfigErrorApp.startFailed(StateError('boom'), onReload: () => reloads++),
    );
    expect(find.text('The game could not start'), findsOneWidget);
    expect(find.text('Detail: Bad state: boom'), findsOneWidget);
    await tester.tap(find.text('Reload'));
    expect(reloads, 1);
    // No page to reload (not the web): no button.
    await tester.pumpWidget(ConfigErrorApp.startFailed(StateError('boom')));
    expect(find.text('Reload'), findsNothing);
  });

  testWidgets('ConfigErrorApp names the missing keys and the fix', (
    tester,
  ) async {
    await tester.pumpWidget(
      ConfigErrorApp.missingBackendConfig(['SUPABASE_PUBLISHABLE_KEY']),
    );

    expect(find.text('Missing configuration'), findsOneWidget);
    expect(find.textContaining('SUPABASE_PUBLISHABLE_KEY'), findsOneWidget);
    expect(
      find.textContaining('--dart-define-from-file=dart_defines.json'),
      findsOneWidget,
    );
  });

  testWidgets('web storage unavailable: names the setup command', (
    tester,
  ) async {
    await tester.pumpWidget(
      ConfigErrorApp.webStorageUnavailable('worker introuvable'),
    );

    expect(find.text('Web storage unavailable'), findsOneWidget);
    expect(
      find.textContaining('dart run sqflite_common_ffi_web:setup'),
      findsOneWidget,
    );
    expect(find.textContaining('worker introuvable'), findsOneWidget);
  });
}
