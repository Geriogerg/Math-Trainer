import 'package:math_trainer/core/domain/account/player_profile.dart';
import 'package:math_trainer/core/domain/account/profile_repository.dart';

/// Pour les tests qui ne s'intéressent pas au profil — même raisonnement que
/// `FakeAccountRepository` : `AppEnvironment.profileRepository` est requis,
/// pas de défaut concret.
class FakeProfileRepository implements ProfileRepository {
  String? displayName = 'Joueur Test';

  /// Simule un Supabase injoignable (hors ligne) pour `currentProfile()`.
  bool shouldFail = false;

  @override
  Future<PlayerProfile> currentProfile() async {
    if (shouldFail) throw Exception('réseau indisponible (simulé)');
    return PlayerProfile(
      accountId: 'fake-account-id',
      displayName: displayName,
    );
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    this.displayName = displayName;
  }
}
