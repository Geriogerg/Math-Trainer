import 'package:material_ui/material_ui.dart';
import '../strings/strings.dart';

import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/method/method_for.dart';

import '../../core/state/duel_controller.dart';
import '../kit/kit.dart';
import '../screens/result_screen.dart' show MistakeRow;
import '../theme/app_theme.dart';
import 'package:math_trainer/presentation/strings/duel_texts.dart';

/// A duel's result (`doc/mockups/online.html`, screen 3): Won / Lost /
/// Draw, the mode and the rating's move, both scores, the mistakes with
/// their Method (Get the count: each unsolved round's solution), then
/// Online and Rematch. Shown at once from the device's own reckoning; the
/// rating appears when the server has decided.
class DuelResultView extends StatelessWidget {
  const DuelResultView({
    super.key,
    required this.controller,
    required this.onOnline,
    required this.onRematch,
  });

  final DuelController controller;
  final VoidCallback onOnline;

  /// `null`: no rematch (a challenger waiting for their friend).
  final VoidCallback? onRematch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metrics = theme.extension<AppMetrics>()!;
    final offer = controller.offer;
    final verdict = controller.verdict;
    final result = controller.result;
    final waiting = verdict?.waiting ?? offer.lane == null;
    final headline = controller.refusal != null
        ? strings.online.notCounted
        : waiting
        ? strings.online.sent
        : result == null
        ? '…'
        : resultWord(result);
    final mine = verdict?.you ?? controller.local?.score;
    final theirs = verdict?.them ?? offer.lane?.score;

    return SingleChildScrollView(
      padding: metrics.rootPadding.copyWith(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            headline,
            key: const ValueKey('duel-headline'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: result == 1 ? scheme.primary : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitle(offer, verdict, waiting),
            key: const ValueKey('duel-subtitle'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.digits.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (controller.pending) ...[
            const SizedBox(height: 8),
            Center(
              child: AppButton.secondary(
                label: strings.online.sendAgain,
                onPressed: controller.retry,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ScoreTile(label: strings.online.you, score: mine),
              ),
              if (!waiting) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _ScoreTile(label: opponentLabel(offer), score: theirs),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (offer.mode.isQuiz)
            for (final (i, outcome) in controller.outcomes.indexed)
              if (!outcome.isCorrect)
                MistakeRow(
                  key: ValueKey('duel-mistake-$i'),
                  outcome: outcome,
                  method: methodFor(
                    outcome.exercise,
                    family: controller.families.elementAtOrNull(i),
                  ),
                ),
          if (!offer.mode.isQuiz)
            for (final (i, round) in controller.playedRounds.indexed)
              if (round.bestDistance > 0)
                Padding(
                  key: ValueKey('duel-round-$i'),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    [
                      '${round.puzzle.target}',
                      for (final step in round.solution) step.toString(),
                    ].join('\n'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.digits,
                  ),
                ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: strings.online.online,
                  onPressed: onOnline,
                ),
              ),
              if (onRematch case final rematch?) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton.primary(
                    label: strings.online.rematch,
                    onPressed: rematch,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// "Basics · 1 542 → 1 560" when rated; "· Practice" for a simulated
  /// opponent; the rating as it stands for an unrated duel.
  static String _subtitle(DuelOffer offer, DuelVerdict? verdict, bool waiting) {
    final mode = duelModeLabel(offer.mode);
    if (verdict == null) return mode;
    if (offer.kind == DuelKind.practice) {
      return strings.online.practiceSubtitle(mode);
    }
    final provisional = verdict.provisional;
    if (verdict.rated &&
        verdict.ratingBefore != null &&
        verdict.ratingAfter != null) {
      return '$mode · ${ratingText(verdict.ratingBefore!, provisional: false)}'
          ' → ${ratingText(verdict.ratingAfter!, provisional: provisional)}';
    }
    if (verdict.ratingNow case final now?) {
      return '$mode · ${ratingText(now, provisional: provisional)}';
    }
    return mode;
  }
}

/// One player's score (the mockup's tiles): name, headline, time.
class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.label, required this.score});

  final String label;
  final DuelScore? score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metrics = theme.extension<AppMetrics>()!;
    final score = this.score;
    final texts = score == null ? null : scoreTexts(score);
    final small = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Semantics(
      container: true,
      label: '$label: ${texts?.value ?? '–'}, ${texts?.time ?? ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(metrics.radius),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: small,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              texts?.value ?? '–',
              style: theme.textTheme.headlineSmall?.digits.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(texts?.time ?? '', style: small?.digits),
          ],
        ),
      ),
    );
  }
}
