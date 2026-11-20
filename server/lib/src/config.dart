/// The server's settings, from environment variables only — never from a
/// file in the repo (rule 17: the secret key never appears in the repo or
/// in logs). Set on the host (`render.yaml` lists them, without values).
class ServerConfig {
  ServerConfig({
    required this.supabaseUrl,
    required this.supabaseSecretKey,
    this.port = 8080,
    this.allowedOrigins = const {},
    this.requireBetaCode = true,
    this.version = 'dev',
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

  /// From `SUPABASE_URL`, `SUPABASE_SECRET_KEY`, `PORT` (default 8080),
  /// `ALLOWED_ORIGINS` (comma-separated web origins allowed to call the
  /// server from a browser, e.g. `https://geriogerg.github.io`) and
  /// `BETA_GATE` (`false` turns the invitation check off — the public
  /// launch, Phase 6; anything else, or unset, keeps it on).
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
      requireBetaCode: env['BETA_GATE']?.trim().toLowerCase() != 'false',
      // Render sets RENDER_GIT_COMMIT to the deployed commit.
      version: switch (env['RENDER_GIT_COMMIT']?.trim()) {
        final sha? when sha.length >= 7 => sha.substring(0, 7),
        _ => 'dev',
      },
    );
  }

  final Uri supabaseUrl;

  /// Supabase secret key (`sb_secret_…`, or the legacy service-role JWT):
  /// bypasses row-level security. Only this process holds it.
  final String supabaseSecretKey;

  final int port;
  final Set<String> allowedOrigins;

  /// Uploads from anonymous players need an invitation code (Phase 5.1
  /// commit 5). On by default: the beta is invite-only until Phase 6.
  final bool requireBetaCode;

  /// The deployed commit, short (`/health`); `dev` outside Render.
  final String version;

  /// Never prints the key.
  @override
  String toString() =>
      'ServerConfig(supabaseUrl: $supabaseUrl, port: $port, '
      'allowedOrigins: $allowedOrigins, requireBetaCode: $requireBetaCode, '
      'supabaseSecretKey: <redacted>)';
}
