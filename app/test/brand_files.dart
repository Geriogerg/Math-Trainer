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

/// One email's words, in one language.
typedef _Email = ({
  String subject,
  String heading,
  String lead,
  String button,
  String otherwise,
});

/// The three emails Supabase sends (Phase 6c commits 3 and 4), by
/// Supabase's template name, in English and French (Phase 6d, "tu").
Map<String, ({String file, String template, _Email en, _Email fr})> _emails() {
  final name = const HtmlEscape(HtmlEscapeMode.element).convert(Brand.name);
  return {
    'confirmation': (
      file: 'confirmation',
      template: 'Confirm sign up',
      en: (
        subject: 'Confirm your email for ${Brand.name}',
        heading: 'Confirm your email',
        lead:
            'You saved your progress in $name with this address. Open the '
            'link to confirm it:',
        button: 'Confirm my email',
        otherwise: 'Not you? Ignore this email: nothing changes.',
      ),
      fr: (
        subject: 'Confirme ton e-mail pour ${Brand.name}',
        heading: 'Confirme ton e-mail',
        lead:
            'Tu as sauvegardé ta progression dans $name avec cette adresse. '
            'Ouvre le lien pour la confirmer\u202f:',
        button: 'Confirmer mon e-mail',
        otherwise:
            'Ce n’est pas toi\u202f? Ignore cet e-mail\u202f: rien ne change.',
      ),
    ),
    'email_change': (
      file: 'email_change',
      template: 'Change email address',
      en: (
        subject: 'Confirm your email for ${Brand.name}',
        heading: 'Confirm your email',
        lead:
            'You asked to save your progress in $name with this address. Open '
            'the link to finish — until then you play as a guest:',
        button: 'Confirm my email',
        otherwise: 'Not you? Ignore this email: nothing changes.',
      ),
      fr: (
        subject: 'Confirme ton e-mail pour ${Brand.name}',
        heading: 'Confirme ton e-mail',
        lead:
            'Tu as demandé à sauvegarder ta progression dans $name avec cette '
            'adresse. Ouvre le lien pour finir — d’ici là, tu joues en '
            'invité\u202f:',
        button: 'Confirmer mon e-mail',
        otherwise:
            'Ce n’est pas toi\u202f? Ignore cet e-mail\u202f: rien ne change.',
      ),
    ),
    // Phase 6c commit 4 (review B3).
    'recovery': (
      file: 'recovery',
      template: 'Reset password',
      en: (
        subject: 'Set a new password for ${Brand.name}',
        heading: 'Set a new password',
        lead:
            'Someone asked to reset the password of your $name account. Open '
            'the link to choose a new one:',
        button: 'Set a new password',
        otherwise: 'Not you? Ignore this email: your password stays as it is.',
      ),
      fr: (
        subject: 'Nouveau mot de passe pour ${Brand.name}',
        heading: 'Choisis un nouveau mot de passe',
        lead:
            'Quelqu’un a demandé à réinitialiser le mot de passe de ton compte '
            '$name. Ouvre le lien pour en choisir un nouveau\u202f:',
        button: 'Choisir un nouveau mot de passe',
        otherwise:
            'Ce n’est pas toi\u202f? Ignore cet e-mail\u202f: ton mot de passe ne '
            'change pas.',
      ),
    ),
  };
}

String _body(_Email words) => [
  '<h2>${words.heading}</h2>',
  '<p>${words.lead}</p>',
  '<p><a href="{{ .ConfirmationURL }}">${words.button}</a></p>',
  '<p>${words.otherwise}</p>',
  '<p>— ${const HtmlEscape(HtmlEscapeMode.element).convert(Brand.name)}</p>',
].join('\n');

/// The emails, by file under `supabase/templates/`, each with its subject
/// on its first lines, for the owner to paste into the project
/// (Authentication → Emails). `{{ .ConfirmationURL }}` is Supabase's link.
///
/// - `<name>.html` — English; `<name>.fr.html` — French (Phase 6d);
/// - `<name>.by-language.html` — both, picked by the account's language
///   (`language` in its metadata, which the app keeps): Supabase holds one
///   template per email, so this is the one to paste once French ships.
Map<String, String> emailTemplates() {
  String header(String template, String subject, String note) => [
    '<!-- Supabase → Authentication → Emails → "$template".',
    '     Subject: $subject',
    if (note.isNotEmpty) '     $note',
    '     Written from Brand by app/tool/brand/write_brand_test.dart: never',
    '     by hand. -->',
  ].join('\n');
  return {
    for (final e in _emails().values) ...{
      '${e.file}.html':
          '${header(e.template, e.en.subject, '')}\n${_body(e.en)}\n',
      '${e.file}.fr.html':
          '${header(e.template, e.fr.subject, 'French (Phase 6d).')}\n'
          '${_body(e.fr)}\n',
      '${e.file}.by-language.html':
          '${header(e.template, '${e.en.subject} · ${e.fr.subject}', 'English or French, by the account\'s language (its metadata\'s "language", kept by the app).')}\n'
          '{{ if and .Data .Data.language (eq .Data.language "fr") }}\n'
          '${_body(e.fr)}\n'
          '{{ else }}\n'
          '${_body(e.en)}\n'
          '{{ end }}\n',
    },
  };
}
