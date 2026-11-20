import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// The digit-typeface candidates of `doc/plan.md` (Phase 5 commit 1), each
/// cut to digits and operators (`tool/fonts/subset_digits.py`).
const specimenCandidates = [
  (family: 'Specimen Space Grotesk', asset: 'SpaceGrotesk'),
  (family: 'Specimen Sora', asset: 'Sora'),
  (family: 'Specimen Manrope', asset: 'Manrope'),
  (family: 'Specimen JetBrains Mono', asset: 'JetBrainsMono'),
];

/// Loads the candidates from `assets/fonts/specimen/`, declared as plain
/// assets: they are fetched only when this screen opens, never by a player.
Future<void> loadSpecimenFonts() async {
  for (final c in specimenCandidates) {
    final loader = FontLoader(c.family)
      ..addFont(rootBundle.load('assets/fonts/specimen/${c.asset}-Digits.ttf'));
    await loader.load();
  }
}

/// Standalone app for the specimen, opened with `?specimen` on a debug or
/// preview build (`main.dart`), never in a release for the public — no
/// account, no database.
class SpecimenApp extends StatefulWidget {
  const SpecimenApp({super.key, this.fontsLoaded});

  /// Tests pass the fonts already loaded.
  final Future<void>? fontsLoaded;

  @override
  State<SpecimenApp> createState() => _SpecimenAppState();
}

class _SpecimenAppState extends State<SpecimenApp> {
  late final Future<void> _fonts = widget.fontsLoaded ?? loadSpecimenFonts();
  bool _dark = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digit specimen',
      debugShowCheckedModeBanner: false,
      theme: _dark ? buildDarkTheme() : buildLightTheme(),
      home: FutureBuilder<void>(
        future: _fonts,
        builder: (context, snapshot) => SpecimenScreen(
          ready: snapshot.connectionState == ConnectionState.done,
          dark: _dark,
          onToggleTheme: () => setState(() => _dark = !_dark),
        ),
      ),
    );
  }
}

/// Every candidate at play size: the session's operation (48), the typed
/// answer (32), the keypad digits; the glyphs that get confused at speed
/// (1/7, 6/8/9/0, 3/8); and a tabular check (each pair of lines must end
/// at the same x). Today's face, Inter, comes first as the baseline.
class SpecimenScreen extends StatelessWidget {
  const SpecimenScreen({
    super.key,
    required this.ready,
    required this.dark,
    required this.onToggleTheme,
  });

  final bool ready;
  final bool dark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text('Digit specimen', style: theme.textTheme.titleMedium),
        actions: [
          IconButton(
            tooltip: dark ? 'Day theme' : 'Night theme',
            icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: onToggleTheme,
          ),
        ],
      ),
      body: SafeArea(
        child: !ready
            ? Center(child: Text('Loading…', style: theme.textTheme.bodyMedium))
            : ListView(
                padding: metrics.rootPadding,
                children: [
                  const _Sample(name: 'Inter (today)', family: null),
                  for (final c in specimenCandidates)
                    _Sample(
                      name: c.family.replaceFirst('Specimen ', ''),
                      family: c.family,
                    ),
                ],
              ),
      ),
    );
  }
}

class _Sample extends StatelessWidget {
  const _Sample({required this.name, required this.family});

  final String name;

  /// `null`: Inter, the app's face.
  final String? family;

  TextStyle? _in(TextStyle? style) => family == null
      ? style
      : style?.copyWith(fontFamily: family, fontFamilyFallback: ['Inter']);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = text.bodyMedium?.copyWith(
      color: theme.extension<AppPalette>()!.textMuted,
    );
    final operation = _in(text.displayMedium);
    final answer = _in(text.headlineMedium);
    final keypad = _in(text.displaySmall);
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: text.titleMedium),
          const SizedBox(height: 8),
          for (final line in const [
            '47 + 68',
            '92 − 35',
            '24 × 7',
            '96 ÷ 8',
            '√169',
            '25% of 80',
          ])
            Text(line, style: operation),
          const SizedBox(height: 8),
          Text('Confused at speed', style: muted),
          Text('1717 7171', style: operation),
          Text('6890 0986', style: operation),
          Text('3838 8383', style: operation),
          const SizedBox(height: 8),
          Text('Typed answer', style: muted),
          Text('1234567890', style: answer),
          const SizedBox(height: 8),
          Text('Keypad', style: muted),
          Text('1 2 3 4 5 6 7 8 9 0', style: keypad),
          const SizedBox(height: 8),
          Text('Tabular: both lines end together', style: muted),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('111 111', style: answer),
                Text('888 888', style: answer),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
