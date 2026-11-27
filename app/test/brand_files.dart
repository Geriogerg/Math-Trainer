import 'dart:convert';

import 'package:math_trainer/presentation/strings/brand.dart';

/// What the web files must say about the product (Phase 6c commit 1): built
/// from `Brand`, written by `tool/brand/write_brand_test.dart`, checked by
/// `test/brand_test.dart`. One function per file, shared by both.

const brandStart = '  <!-- brand:';
const brandEnd = '  <!-- /brand -->';

/// The preview image's size: the size every link preview expects.
const previewWidth = 1200;
const previewHeight = 630;

String _attribute(String value) =>
    const HtmlEscape(HtmlEscapeMode.attribute).convert(value);

/// `web/index.html`'s brand block, its comment and end marker included.
String brandHead() {
  final name = _attribute(Brand.name);
  final description = _attribute(Brand.description);
  return [
    '$brandStart the name, its line and the link preview, written from Brand',
    '       (lib/presentation/strings/brand.dart) by tool/brand/write_brand_test.dart',
    '       — never by hand. CI makes og:image absolute (SITE_URL). -->',
    '  <title>${const HtmlEscape(HtmlEscapeMode.element).convert(Brand.name)}</title>',
    '  <meta name="description" content="$description">',
    '  <meta name="apple-mobile-web-app-title" content="$name">',
    '  <meta property="og:type" content="website">',
    '  <meta property="og:title" content="$name">',
    '  <meta property="og:description" content="$description">',
    '  <meta property="og:image" content="preview.png">',
    '  <meta property="og:image:width" content="$previewWidth">',
    '  <meta property="og:image:height" content="$previewHeight">',
    '  <meta property="og:image:alt" content="$name: + − × ÷">',
    '  <meta name="twitter:card" content="summary_large_image">',
    brandEnd,
  ].join('\n');
}

/// The loading screen's title (`web/index.html`, painted before any script).
String loaderTitle() =>
    '<div class="mt-title">'
    '${const HtmlEscape(HtmlEscapeMode.element).convert(Brand.name)}</div>';

/// The loading bar's spoken label.
String loaderLabel() => 'aria-label="Loading ${_attribute(Brand.name)}"';

final _loaderTitle = RegExp(r'<div class="mt-title">[^<]*</div>');
final _loaderLabel = RegExp(r'aria-label="Loading [^"]*"');

/// [html] with its brand block replaced by [brandHead] and the loading
/// screen's name by Brand's; throws when a place is missing.
String withBrand(String html) {
  final start = html.indexOf(brandStart);
  final end = html.indexOf(brandEnd);
  if (start < 0 || end < start) {
    throw StateError('web/index.html: the brand markers are missing');
  }
  if (_loaderTitle.allMatches(html).length != 1 ||
      _loaderLabel.allMatches(html).length != 1) {
    throw StateError("web/index.html: the loading screen's name is missing");
  }
  return html
      .replaceRange(start, end + brandEnd.length, brandHead())
      .replaceFirst(_loaderTitle, loaderTitle())
      .replaceFirst(_loaderLabel, loaderLabel());
}

/// `web/manifest.json` with the product's words, everything else kept.
String withBrandManifest(String manifest) {
  final json = (jsonDecode(manifest) as Map).cast<String, Object?>();
  json['name'] = Brand.name;
  json['short_name'] = Brand.shortName;
  json['description'] = Brand.description;
  return '${const JsonEncoder.withIndent('    ').convert(json)}\n';
}

/// The emails Supabase sends (Phase 6c commit 3; the recovery email with
/// commit 4), by file under `supabase/templates/`, each with its subject on
/// its first line, for the owner to paste into the project (Authentication
/// → Emails). `{{ .ConfirmationURL }}` is Supabase's link.
Map<String, String> emailTemplates() {
  final name = const HtmlEscape(HtmlEscapeMode.element).convert(Brand.name);
  String page({
    required String template,
    required String subject,
    required String heading,
    required String lead,
    required String button,
    required String otherwise,
  }) => [
    '<!-- Supabase → Authentication → Emails → "$template".',
    '     Subject: $subject',
    '     Written from Brand by app/tool/brand/write_brand_test.dart: never',
    '     by hand. -->',
    '<h2>$heading</h2>',
    '<p>$lead</p>',
    '<p><a href="{{ .ConfirmationURL }}">$button</a></p>',
    '<p>$otherwise</p>',
    '<p>— $name</p>',
    '',
  ].join('\n');
  return {
    'confirmation.html': page(
      template: 'Confirm sign up',
      subject: 'Confirm your email for ${Brand.name}',
      heading: 'Confirm your email',
      lead:
          'You saved your progress in $name with this address. Open the link '
          'to confirm it:',
      button: 'Confirm my email',
      otherwise: 'Not you? Ignore this email: nothing changes.',
    ),
    'email_change.html': page(
      template: 'Change email address',
      subject: 'Confirm your email for ${Brand.name}',
      heading: 'Confirm your email',
      lead:
          'You asked to save your progress in $name with this address. Open '
          'the link to finish — until then you play as a guest:',
      button: 'Confirm my email',
      otherwise: 'Not you? Ignore this email: nothing changes.',
    ),
  };
}
