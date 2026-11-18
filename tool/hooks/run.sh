#!/usr/bin/env bash
# Runs a Claude Code hook written in Dart (usage: run.sh <script.dart>), with
# the tool call's JSON on stdin. Only Dart files are checked: anything else
# returns at once, without starting a Dart VM. Uses the Dart VM inside the
# Flutter SDK rather than the `dart` wrapper on PATH, whose Flutter update
# check costs about two seconds per call; falls back to `dart`.
input=$(cat)
case "$input" in
  *'.dart"'*) ;;
  *) exit 0 ;;
esac
dart_bin="$(dirname "$(command -v flutter)")/cache/dart-sdk/bin/dart"
if [ ! -x "$dart_bin" ] && [ ! -x "$dart_bin.exe" ]; then
  dart_bin=dart
fi
printf '%s' "$input" | "$dart_bin" "$(dirname "$0")/$1"
