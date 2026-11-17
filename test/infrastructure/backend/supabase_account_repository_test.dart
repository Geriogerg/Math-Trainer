import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/core/domain/account/account.dart';
import 'package:math_trainer/infrastructure/backend/supabase_account_repository.dart';

import 'supabase_test_client.dart';

const _account = Account(id: testUserId, email: testEmail);

void main() {
  late SupabaseTestClient supabase;
  late SupabaseAccountRepository repository;

  setUp(() {
    supabase = SupabaseTestClient();
    repository = SupabaseAccountRepository(supabase.client);
  });

  tearDown(() => supabase.client.dispose());

  test('authState émet null au démarrage sans session', () async {
    supabase.emitInitialSessionWithoutUser();
    expect(await repository.authState.first, isNull);
  });

  // Garde-fou de bibliothèque : `ProfileScreen` lit le compte par
  // `authState.first`. Ça ne tient que parce que `onAuthStateChange` rejoue
  // le dernier événement seulement (pas tout l'historique, malgré le nom
  // `ReplaySubject`). Si une mise à jour de Supabase changeait ce point,
  // `.first` renverrait `initialSession` (aucun compte) après toute
  // connexion faite pendant le lancement en cours.
  test(
    'authState.first donne le compte courant après une connexion faite pendant ce lancement',
    () async {
      supabase.emitInitialSessionWithoutUser();
      await supabase.signIn();

      expect(await repository.authState.first, _account);
    },
  );

  test(
    'un nouvel abonné ne rejoue pas l\'état déconnecté de l\'historique',
    () async {
      supabase.emitInitialSessionWithoutUser();
      await supabase.signIn();

      final emitted = <Account?>[];
      final subscription = repository.authState.listen(emitted.add);
      await pumpEventQueue();
      await subscription.cancel();

      expect(emitted, [_account]);
    },
  );

  test('authState suit la connexion puis la déconnexion', () async {
    supabase.emitInitialSessionWithoutUser();
    final emitted = <Account?>[];
    final subscription = repository.authState.listen(emitted.add);
    await pumpEventQueue();

    await supabase.signIn();
    await pumpEventQueue();
    await repository.signOut();
    await pumpEventQueue();
    await subscription.cancel();

    expect(emitted, [null, _account, null]);
  });
}
