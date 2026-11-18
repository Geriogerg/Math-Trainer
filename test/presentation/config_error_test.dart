import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/presentation/screens/config_error_screen.dart';

void main() {
  // `flutter test` ne passe aucun `--dart-define` : exactement la situation
  // d'un build lancé sans `dart_defines.json`.
  test(
    'buildAppEnvironment refuse de démarrer sans configuration Supabase',
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

  testWidgets('ConfigErrorApp nomme les clés manquantes et le correctif', (
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

  testWidgets('stockage web indisponible : nomme la commande de setup', (
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
