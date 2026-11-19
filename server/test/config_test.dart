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
