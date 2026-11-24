// Phase 4 commit 7: does the weak-spot schedule work? Reads accepted
// uploads, one JSON payload per line (as `dashboard.sh weak-spots` exports
// `uploaded_sessions.payload`), replays each player's history through the
// core's own scheduler and prints accuracy and time on each scheduled item
// before and after it entered the schedule.
//
//   bash tool/dashboard/dashboard.sh weak-spots         # from the repo root
//   dart run tool/weak_spots_report.dart < payloads.jsonl
//
// Prints testers' data: run it locally only, never from CI.

import 'dart:convert';
import 'dart:io';

import 'package:math_core/persistence/session_repository.dart';
import 'package:math_core/sync/session_upload.dart';

import 'src/weak_spots_report.dart';

void main() {
  final byPlayer = <String, List<StoredGame>>{};
  var skipped = 0;
  String? line;
  while ((line = stdin.readLineSync(encoding: utf8)) != null) {
    if (line!.trim().isEmpty) continue;
    try {
      final upload = SessionUpload.fromJson(jsonDecode(line));
      byPlayer.putIfAbsent(upload.session.playerId, () => []).add((
        session: upload.session,
        answers: upload.answers,
      ));
    } on FormatException catch (_) {
      skipped++;
    }
  }
  for (final games in byPlayer.values) {
    games.sort((a, b) {
      final t = a.session.createdAt.compareTo(b.session.createdAt);
      return t != 0 ? t : a.session.id.compareTo(b.session.id);
    });
  }
  stdout.write(formatWeakSpotsReport(weakSpotsReport(byPlayer)));
  if (skipped > 0) stdout.writeln('($skipped payloads not readable, skipped)');
}
