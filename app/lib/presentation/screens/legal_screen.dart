import 'dart:ui' show PlatformDispatcher;

import 'package:material_ui/material_ui.dart';

import '../kit/kit.dart';
import '../strings/legal/legal_details.dart';
import '../strings/legal/legal_texts.dart';
import '../theme/app_theme.dart';

/// The two legal pages (Phase 6c commit 2, plan v4.1; review B1).
enum LegalPage { privacy, notice }

/// Opens [page] over the current screen.
Future<void> openLegalPage(BuildContext context, LegalPage page) =>
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => LegalScreen(page: page)));

/// The two pages' links side by side: before any data is given (the gate,
/// the save form) and on Profile.
class LegalLinks extends StatelessWidget {
  const LegalLinks({
    super.key,
    required this.privacyLabel,
    required this.noticeLabel,
  });

  final String privacyLabel;
  final String noticeLabel;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      AppButton.secondary(
        onPressed: () => openLegalPage(context, LegalPage.privacy),
        label: privacyLabel,
      ),
      AppButton.secondary(
        onPressed: () => openLegalPage(context, LegalPage.notice),
        label: noticeLabel,
      ),
    ],
  );
}

/// The languages they exist in (plan 6.6: French and English), English
/// first like the interface.
const legalLanguages = <String, LegalTexts>{
  'en': EnglishLegalTexts(),
  'fr': FrenchLegalTexts(),
};

/// A legal page, in English or French (a switch at the top; it opens in
/// French when the device's language is French). The owner's details not given
/// yet show as highlighted placeholders, under a "Draft" banner (plan
/// v4.1: "placeholders visible until filled"). Plain text, no link out: it
/// reads the same offline.
class LegalScreen extends StatefulWidget {
  const LegalScreen({
    super.key,
    required this.page,
    this.details = LegalDetails.given,
    this.languageCode,
  });

  final LegalPage page;

  /// The owner's details (tests pass their own).
  final Map<LegalDetail, Map<String, String>> details;

  /// The language to open in; the device's when `null`.
  final String? languageCode;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late String _language = () {
    final wanted =
        widget.languageCode ?? PlatformDispatcher.instance.locale.languageCode;
    return legalLanguages.containsKey(wanted) ? wanted : 'en';
  }();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final texts = legalLanguages[_language]!;
    final (title, sections) = switch (widget.page) {
      LegalPage.privacy => (texts.privacyTitle, texts.privacy),
      LegalPage.notice => (texts.noticeTitle, texts.notice),
    };
    final draft = sections.any(
      (s) => s.$2.any(
        (p) => legalMark
            .allMatches(p)
            .any((m) => _value(LegalDetail.values.byName(m[1]!)) == null),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: theme.extension<AppMetrics>()!.rootPadding,
          children: [
            SegmentedChoice<String>(
              values: legalLanguages.keys.toList(),
              selected: _language,
              label: (code) => legalLanguages[code]!.languageName,
              onChanged: (code) => setState(() => _language = code),
            ),
            const SizedBox(height: 16),
            if (draft) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(
                    theme.extension<AppMetrics>()!.radius / 2,
                  ),
                ),
                child: Text(
                  texts.draftBanner,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            for (final (heading, paragraphs) in sections) ...[
              Semantics(
                header: true,
                child: Text(heading, style: theme.textTheme.titleSmall),
              ),
              const SizedBox(height: 8),
              for (final paragraph in paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _paragraph(context, texts, paragraph),
                ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  String? _value(LegalDetail detail) => widget.details[detail]?[_language];

  /// [text] with each `⟦detail⟧` given, or a highlighted placeholder that
  /// is said as "not filled in yet" — never shown by colour alone: it is in
  /// brackets and bold too (rule 14).
  Widget _paragraph(BuildContext context, LegalTexts texts, String text) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in legalMark.allMatches(text)) {
      spans.add(TextSpan(text: text.substring(at, m.start)));
      final detail = LegalDetail.values.byName(m[1]!);
      final value = _value(detail);
      spans.add(
        value != null
            ? TextSpan(text: value)
            : TextSpan(
                text: texts.placeholder(detail),
                semanticsLabel: texts.placeholderSpoken(detail),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onErrorContainer,
                  backgroundColor: theme.colorScheme.errorContainer,
                ),
              ),
      );
      at = m.end;
    }
    spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
