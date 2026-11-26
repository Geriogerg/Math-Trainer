import 'package:math_core/account/player_profile.dart';
import 'package:math_core/account/profile_repository.dart';

/// For tests that do not care about the profile — same reasoning as
/// `FakeAccountRepository`: `AppEnvironment.profileRepository` is required,
/// with no concrete default.
class FakeProfileRepository implements ProfileRepository {
  String? displayName = 'Joueur Test';

  /// The owner hid or suspended the account (Phase 6a).
  bool underReview = false;

  /// Simulates an unreachable Supabase (offline) for `currentProfile()`.
  bool shouldFail = false;

  @override
  Future<PlayerProfile> currentProfile() async {
    if (shouldFail) throw Exception('network unavailable (simulated)');
    return PlayerProfile(
      accountId: 'fake-account-id',
      displayName: displayName,
      underReview: underReview,
    );
  }

  /// Simulates a refused save (network, missing table).
  bool updateShouldFail = false;

  @override
  Future<void> updateDisplayName(String displayName) async {
    if (updateShouldFail) throw Exception('save refused (simulated)');
    this.displayName = displayName;
  }
}
