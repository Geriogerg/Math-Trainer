/// The owner's details the legal pages need (Phase 6c commit 2, plan
/// v4.1): until one is given, every page that uses it shows a visible
/// placeholder and a "Draft" banner. Stored names are not involved: these
/// are only the marks `⟦name⟧` in `legal_texts.dart`.
enum LegalDetail {
  /// Who publishes the game: the owner's name, or — a private publisher's
  /// right (plan section 6.6) — a sentence saying the host keeps their
  /// identity.
  publisher,

  /// Where players write (rights, problems).
  contactEmail,

  /// The director of publication (French law: the publisher, for an
  /// individual).
  publicationDirector,

  /// Cloudflare's address and telephone number, as the law asks of a host.
  hostDetails,

  /// Where the Supabase project keeps the data (its region).
  dataRegion,

  /// The date this version of the pages takes effect.
  effectiveDate,
}

/// A mark in the legal texts: `⟦name⟧`, the name a [LegalDetail]'s.
final legalMark = RegExp('⟦([a-zA-Z]+)⟧');

/// What the owner has given so far, by detail and language code (`en`,
/// `fr`); a detail missing for a language shows its placeholder there.
/// Filled in when the owner sends the values (the launch checklist,
/// `doc/launch-checklist.md`), then the pages are reviewed (plan 6.6).
abstract final class LegalDetails {
  static const Map<LegalDetail, Map<String, String>> given = {};
}
