import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:math_trainer/presentation/kit/kit.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import 'golden_test_utils.dart';

/// Phase 5 exit test: a golden for every kit component, every state, in
/// both themes (`doc/plan.md`, Phase 5 commit 2).
void main() {
  setUpAll(loadInterFontForGoldens);

  final components = <String, Widget>{
    'app_button': Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton.primary(label: 'Play again', onPressed: () {}),
        const SizedBox(height: 8),
        const AppButton.primary(label: 'Start', onPressed: null),
        const SizedBox(height: 8),
        AppButton.primary(label: 'Save', onPressed: () {}, busy: true),
        const SizedBox(height: 8),
        AppButton.secondary(label: 'New selection', onPressed: () {}),
        const SizedBox(height: 8),
        AppButton.secondary(
          label: 'Delete my data',
          onPressed: () {},
          destructive: true,
        ),
      ],
    ),
    'type_chip': Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TypeChip(label: 'Addition', selected: true, onSelected: (_) {}),
        TypeChip(label: 'Powers', selected: false, onSelected: (_) {}),
        const TypeChip(label: 'Overall', selected: false, onSelected: null),
      ],
    ),
    'keypad_key': SizedBox(
      height: 75,
      child: Row(
        children: [
          Expanded(child: KeypadKey.digit('7', onTap: () {})),
          Expanded(
            child: KeypadKey.icon(
              Icons.backspace_outlined,
              semanticLabel: 'Backspace',
              onTap: () {},
            ),
          ),
          Expanded(
            child: KeypadKey.icon(
              Icons.check,
              semanticLabel: 'Submit',
              onTap: () {},
              isPrimary: true,
            ),
          ),
        ],
      ),
    ),
    'stat_tile': const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 160,
          child: StatTile(value: '1 240', label: 'Score', emphasis: true),
        ),
        SizedBox(height: 8),
        StatTileRow(
          tiles: [
            StatTile(value: '9', label: 'Right'),
            StatTile(value: '2', label: 'Wrong'),
            StatTile(value: '1', label: 'Timed out'),
          ],
        ),
      ],
    ),
    'level_badge': const Wrap(
      spacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        LevelBadge(level: 7),
        LevelBadge(level: 42),
        LevelBadge(level: null),
        LevelBadge(level: 100, large: true),
      ],
    ),
  };

  for (final (mode, theme) in [
    ('dark', buildDarkTheme()),
    ('light', buildLightTheme()),
  ]) {
    for (final MapEntry(key: name, value: component) in components.entries) {
      testWidgets('$name — $mode', (tester) async {
        tester.view.physicalSize = const Size(360, 360);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(alignment: Alignment.topCenter, child: component),
              ),
            ),
          ),
        );
        // The busy ring spins forever: one frame, no settle.
        await tester.pump();
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/kit_${name}_$mode.png'),
        );
      });
    }
  }
}
