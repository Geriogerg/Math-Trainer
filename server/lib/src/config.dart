/// The server's settings, from environment variables only — never from a
/// file in the repo (rule 17: the secret key never appears in the repo or
/// in logs). Set on the host (`render.yaml` lists them, without values).
class ServerConfig {
  ServerConfig({
    required this.supabaseUrl,
    required this.supabaseSecretKey,
    this.port = 8080,
    this.allowedOrigins = const {},
  }) {
    if (supabaseUrl.scheme != 'https' && supabaseUrl.host != 'localhost') {
      throw ArgumentError.value(
        supabaseUrl,
        'supabaseUrl',
        'must be https (localhost excepted, for tests).',
      );
    }
    if (supabaseSecretKey.isEmpty) {
      throw ArgumentError.value('', 'supabaseSecretKey', 'must not be empty.');
    }
    // The publishable key would make every write fail on row-level
    // security, silently from the player's side: refuse to start instead.
    if (supabaseSecretKey.startsWith('sb_publishable_')) {
      throw ArgumentError(
        'SUPABASE_SECRET_KEY holds a publishable key; the server needs the '
        'secret key (Supabase dashboard → Project Settings → API Keys).',
      );
    }
    if (port <= 0 || port > 65535) {
      throw ArgumentError.value(port, 'port', 'must be a TCP port.');
    }
  }

  /// From `SUPABASE_URL`, `SUPABASE_SECRET_KEY`, `PORT` (default 8080) and
  /// `ALLOWED_ORIGINS` (comma-separated web origins allowed to call the
  /// server from a browser, e.g. `https://geriogerg.github.io`).
  factory ServerConfig.fromEnvironment(Map<String, String> env) {
    String required(String name) {
      final value = env[name]?.trim() ?? '';
      if (value.isEmpty) {
        throw ArgumentError('Environment variable $name is not set.');
      }
      return value;
    }

    final port = env['PORT'];
    return ServerConfig(
      supabaseUrl: Uri.parse(required('SUPABASE_URL')),
      supabaseSecretKey: required('SUPABASE_SECRET_KEY'),
      port: port == null || port.isEmpty ? 8080 : int.parse(port),
      allowedOrigins: {
        for (final origin in (env['ALLOWED_ORIGINS'] ?? '').split(','))
          if (origin.trim().isNotEmpty) origin.trim(),
      },
    );
  }

  final Uri supabaseUrl;

  /// Supabase secret key (`sb_secret_…`, or the legacy service-role JWT):
  /// bypasses row-level security. Only this process holds it.
  final String supabaseSecretKey;

  final int port;
  final Set<String> allowedOrigins;

  /// Never prints the key.
  @override
  String toString() =>
      'ServerConfig(supabaseUrl: $supabaseUrl, port: $port, '
      'allowedOrigins: $allowedOrigins, supabaseSecretKey: <redacted>)';
}
