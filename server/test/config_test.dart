import 'dart:convert';

import 'package:math_trainer_server/server.dart';
import 'package:test/test.dart';

void main() {
  const env = {
    'SUPABASE_URL': 'https://abcd.supabase.co',
    'SUPABASE_SECRET_KEY': 'sb_secret_xyz',
    'ALLOWED_ORIGINS': 'https://geriogerg.github.io, http://localhost:8080',
  };

  test('reads the environment, port 8080 by default', () {
    final config = ServerConfig.fromEnvironment(env);
    expect(config.supabaseUrl.host, 'abcd.supabase.co');
    expect(config.port, 8080);
    expect(config.allowedOrigins, {
      'https://geriogerg.github.io',
      'http://localhost:8080',
    });
    expect(ServerConfig.fromEnvironment({...env, 'PORT': '9000'}).port, 9000);
  });

  // Phase 5.1 commit 5: on unless explicitly off (the public launch).
  test('the beta gate: on by default, off only with BETA_GATE=false', () {
    expect(ServerConfig.fromEnvironment(env).requireBetaCode, isTrue);
    expect(
      ServerConfig.fromEnvironment({
        ...env,
        'BETA_GATE': 'true',
      }).requireBetaCode,
      isTrue,
    );
    expect(
      ServerConfig.fromEnvironment({
        ...env,
        'BETA_GATE': ' False ',
      }).requireBetaCode,
      isFalse,
    );
  });

  test('the deployed commit from Render, short', () {
    expect(ServerConfig.fromEnvironment(env).version, 'dev');
    expect(
      ServerConfig.fromEnvironment({
        ...env,
        'RENDER_GIT_COMMIT': '781e8671234567890abcdef',
      }).version,
      '781e867',
    );
  });

  test('never prints the secret key', () {
    expect(
      ServerConfig.fromEnvironment(env).toString(),
      isNot(contains('sb_secret_xyz')),
    );
  });

  test('refuses a missing variable', () {
    expect(
      () => ServerConfig.fromEnvironment({...env}..remove('SUPABASE_URL')),
      throwsArgumentError,
    );
    expect(
      () => ServerConfig.fromEnvironment({...env, 'SUPABASE_SECRET_KEY': ' '}),
      throwsArgumentError,
    );
  });

  test('refuses the publishable key in place of the secret one', () {
    expect(
      () => ServerConfig.fromEnvironment({
        ...env,
        'SUPABASE_SECRET_KEY': 'sb_publishable_abc',
      }),
      throwsArgumentError,
    );
  });

  // The legacy anon JWT passes Auth, then every RPC is denied and uploads
  // answer 503 forever (staging's symptom, 23 Nov 2026). Refused at start.
  test('refuses a legacy JWT key unless its role is service_role', () {
    String jwt(String payload) => [
      base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}')),
      base64Url.encode(utf8.encode(payload)).replaceAll('=', ''),
      'signature',
    ].join('.');
    expect(
      () => ServerConfig.fromEnvironment({
        ...env,
        'SUPABASE_SECRET_KEY': jwt('{"iss":"supabase","role":"anon"}'),
      }),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          allOf(contains('"anon"'), isNot(contains('signature'))),
        ),
      ),
    );
    expect(
      ServerConfig.fromEnvironment({
        ...env,
        'SUPABASE_SECRET_KEY': jwt('{"iss":"supabase","role":"service_role"}'),
      }).supabaseSecretKey,
      startsWith('ey'),
    );
  });

  test('refuses plain http outside localhost, and a bad port', () {
    expect(
      () => ServerConfig.fromEnvironment({
        ...env,
        'SUPABASE_URL': 'http://abcd.supabase.co',
      }),
      throwsArgumentError,
    );
    expect(
      () => ServerConfig.fromEnvironment({...env, 'PORT': '70000'}),
      throwsArgumentError,
    );
  });
}
