# Math Trainer

Competitive mental-arithmetic game — Flutter, web first. Product plan: `doc/plan.md`; working
rules: `CLAUDE.md`; structure: `doc/architecture.md`.

| Directory | What |
|---|---|
| `app/` | the Flutter app (`flutter test`, `flutter run -d edge --web-port=8080 --dart-define-from-file=dart_defines.json`) |
| `packages/math_core/` | pure-Dart core shared by the app and the server (`dart test`, `dart test -p node`) |
| `supabase/` | SQL migrations, applied by CI; SQL tests (`bash tool/sql/test_sql.sh <postgres url>`) |
| `tool/` | Claude Code hooks, preview smoke test, SQL test runner |

Preview: https://math-trainer-kjc.pages.dev/ (every push to `main`).
