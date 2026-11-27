import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/core/state/auth_link.dart';

/// Phase 6c commits 3 and 4: what an email's link brought, read from the
/// address (Supabase's implicit flow puts it in the fragment).
void main() {
  test('a recovery, a confirmation, a dead link, none', () {
    expect(
      authLinkFrom(
        Uri.parse(
          'https://site.example/#access_token=a.b.c&expires_in=3600'
          '&refresh_token=r&token_type=bearer&type=recovery',
        ),
      ),
      AuthLink.recovery,
    );
    for (final type in ['signup', 'email_change', 'email']) {
      expect(
        authLinkFrom(
          Uri.parse('https://site.example/#access_token=a.b.c&type=$type'),
        ),
        AuthLink.confirmed,
        reason: type,
      );
    }
    expect(
      authLinkFrom(
        Uri.parse(
          'https://site.example/#error=access_denied&error_code=otp_expired'
          '&error_description=Email+link+is+invalid+or+has+expired',
        ),
      ),
      AuthLink.failed,
    );
    expect(authLinkFrom(Uri.parse('https://site.example/')), isNull);
    expect(
      authLinkFrom(Uri.parse('https://site.example/?friend=MATH-7K2P-QX4M')),
      isNull,
    );
    expect(
      authLinkFrom(Uri.parse('https://site.example/#type=recovery')),
      isNull,
      reason: 'no session: nothing to act on',
    );
  });
}
