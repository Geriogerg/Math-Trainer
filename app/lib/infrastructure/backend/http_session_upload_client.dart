import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:math_core/sync/session_upload.dart';
import 'package:math_core/sync/session_upload_client.dart';

/// Uploads a session to the Math Trainer server (`server/`,
/// `POST /v1/sessions`) with the player's access token. Every failure that
/// may pass (offline, timeout, server asleep or down, expired token) is an
/// [UploadUnavailable]: the queue retries later. Only the server's own
/// answer — accepted or refused — is final.
class HttpSessionUploadClient implements SessionUploadClient {
  HttpSessionUploadClient({
    required this.serverUrl,
    required this.accessToken,
    http.Client? client,
    this.timeout = const Duration(seconds: 90),
  }) : _client = client ?? http.Client();

  /// e.g. `https://math-trainer-server.onrender.com` (`SERVER_URL`).
  final Uri serverUrl;
  final Future<String?> Function() accessToken;
  final http.Client _client;

  /// Generous: a free host wakes up in about a minute after a pause, and
  /// uploads are background work.
  final Duration timeout;

  @override
  Future<UploadOutcome> upload(SessionUpload upload) async {
    final token = await accessToken();
    if (token == null) throw const UploadUnavailable('not signed in');
    final http.Response response;
    try {
      response = await _client
          .post(
            serverUrl.resolve('/v1/sessions'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
            body: jsonEncode(upload.toJson()),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const UploadUnavailable('timeout');
    } on http.ClientException catch (e) {
      throw UploadUnavailable('network: ${e.message}');
    }

    final Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      // A proxy's HTML page, a host waking up: not the server's answer.
      throw UploadUnavailable('HTTP ${response.statusCode}, not JSON');
    }
    if (body is! Map) {
      throw UploadUnavailable('HTTP ${response.statusCode}, not an object');
    }
    switch (body['status']) {
      case 'accepted':
        final syncedAt = DateTime.tryParse('${body['syncedAt']}');
        if (syncedAt == null) throw const UploadUnavailable('bad syncedAt');
        return UploadAccepted(
          syncedAt: syncedAt.toUtc(),
          duplicate: body['duplicate'] == true,
        );
      case 'refused':
        final levels = body['levels'];
        try {
          return UploadRefused(
            reason: '${body['reason']}',
            serverLevels: levels == null ? null : levelCacheFromJson(levels),
          );
        } on FormatException catch (e) {
          throw UploadUnavailable('bad server levels: ${e.message}');
        }
    }
    // 401 (token expired between refresh and call), 5xx, anything else.
    throw UploadUnavailable('HTTP ${response.statusCode}');
  }
}
