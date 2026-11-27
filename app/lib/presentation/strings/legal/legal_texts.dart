import '../brand.dart';
import 'legal_details.dart';

/// One section of a legal page: a heading and its paragraphs. A paragraph
/// may hold `⟦detail⟧` marks (a [LegalDetail]'s name): the owner's details,
/// shown as given in `LegalDetails`, or as a visible placeholder until then.
typedef LegalSection = (String heading, List<String> paragraphs);

/// The privacy policy and the legal notice (Phase 6c commit 2, plan v4.1;
/// review B1), in each language the launch needs. **One class per language
/// implementing this interface** (the owner's rule, plan v4.1): a
/// translation that misses a member does not compile.
///
/// What the policy says must stay true of the code: a new table of player
/// data cascades from `auth.users` and is named here, in both languages.
abstract interface class LegalTexts {
  /// The language's own name, for the switch ("English", "Français").
  String get languageName;

  String get privacyTitle;
  List<LegalSection> get privacy;

  String get noticeTitle;
  List<LegalSection> get notice;

  /// Above a page that still shows placeholders.
  String get draftBanner;

  /// The placeholder shown for a detail not given yet.
  String placeholder(LegalDetail detail);

  /// What a screen reader says for it.
  String placeholderSpoken(LegalDetail detail);
}

/// English.
class EnglishLegalTexts implements LegalTexts {
  const EnglishLegalTexts();

  @override
  String get languageName => 'English';

  @override
  String get privacyTitle => 'Privacy policy';

  @override
  List<LegalSection> get privacy => [
    (
      'Who is responsible',
      [
        '${Brand.name} is published by ⟦publisher⟧, who decides how your '
            'data is used (the data controller). Contact: ⟦contactEmail⟧.',
      ],
    ),
    (
      'What is stored',
      [
        'Your account: a random id; if you save your progress, your email, '
            'the player name you choose, and that you declared being 15 or '
            'older. Your password is kept only by our account provider, '
            'never in readable form.',
        'Every game you play: each question, your answer, how long it took, '
            'whether it was right, your level at the time, whether you typed '
            'on the keypad or a keyboard, and the version of the game.',
        'Online duels: each run you play (answers and times), its result '
            'and your duel ratings.',
        'Friends: your friend code, the requests you send and receive, and '
            'your friends.',
        'Fair play: marks the server puts on a game or duel whose timing '
            'looks impossible, the name reports you make, and, if the '
            'publisher puts your account under review, that decision and its '
            'reason.',
        'Feedback you send, with the version of the game, and — while the '
            'game is invitation-only — the invitation code you came in with.',
        'Technical data: your IP address and browser, seen by the services '
            'that deliver the game, to send it to you and to stop abuse '
            '(request limits) — and, before a guest is created or a sign-in, '
            'by Cloudflare Turnstile, which checks that a person, not a '
            'script, is there. They are not used to identify you.',
      ],
    ),
    (
      'Why, and on what basis',
      [
        'To give you the game you ask for — levels, history, Ranks, duels, '
            'friends, a saved account you can sign back into (performance of '
            'a contract, GDPR article 6(1)(b)).',
        'To keep the game fair and safe — checking every game and duel, '
            'limiting abuse, reviewing reported names, keeping finished duels '
            'in your opponents’ history (legitimate interest, article '
            '6(1)(f)).',
        'To improve the game — setting the levels from how fast players '
            'really answer (legitimate interest).',
        'No ads, no third-party analytics, nothing sold or shared for '
            'marketing.',
      ],
    ),
    (
      'Who sees it',
      [
        'Other players see your player name and levels on Ranks, only if '
            'you saved your progress — never your email or your games. A '
            'name another player reports is hidden until it is reviewed.',
        'Players who race your duel runs see your player name, your duel '
            'rating and how fast you answered — never what you typed. Your '
            'friends see your name and the duels you played together.',
        'The publisher can read the stored data to run the game.',
        'Service providers process it for us, under contract: Supabase '
            '(accounts and database, ⟦dataRegion⟧), Render (the game’s '
            'server, United States) and Cloudflare (delivering the site, the '
            'robot check). Emails (the link that confirms your address) are '
            'sent by Supabase. '
            'Transfers outside the European Union rely on the EU–US Data '
            'Privacy Framework or the European Commission’s standard '
            'contractual clauses.',
      ],
    ),
    (
      'How long',
      [
        'As long as your account exists. A guest account unused for 30 days '
            'is deleted with everything stored about it.',
        'When you delete your account, everything is removed at once, on '
            'this device and on the servers — except finished duels, which '
            'stay in your opponents’ history as “Deleted player”: the '
            'result and how fast each answer came, never your name or what '
            'you typed.',
      ],
    ),
    (
      'Your rights',
      [
        'You can see, correct, take away or delete your data, object to its '
            'use or ask for it to be limited. Profile changes your player '
            'name; “Delete my data” (or “Delete my account”) deletes '
            'everything at once. For anything else, write to ⟦contactEmail⟧: '
            'you get an answer within a month.',
        'You can also complain to the French data protection authority, the '
            'CNIL (cnil.fr), or to your own country’s.',
      ],
    ),
    (
      'Age',
      [
        'You must be 15 or older to save your progress (France’s age of '
            'digital consent). If you learn that someone younger did, write '
            'to ⟦contactEmail⟧: the account is deleted.',
      ],
    ),
    (
      'On your device',
      [
        'The game keeps your games, settings and sign-in in your browser’s '
            'storage, so it works offline. Nothing there is for advertising '
            'or tracking: it is needed for the game to work, so no consent is '
            'asked for it.',
      ],
    ),
    (
      'Changes',
      [
        'This version: ⟦effectiveDate⟧. A change that matters to you is '
            'announced in the game.',
      ],
    ),
  ];

  @override
  String get noticeTitle => 'Legal notice';

  @override
  List<LegalSection> get notice => [
    (
      'Publisher',
      [
        '${Brand.name} is published by ⟦publisher⟧. Contact: '
            '⟦contactEmail⟧.',
        'Director of publication: ⟦publicationDirector⟧.',
      ],
    ),
    (
      'Hosting',
      [
        'The site is hosted by Cloudflare, Inc., ⟦hostDetails⟧.',
        'The game’s server is hosted by Render Services, Inc. (United '
            'States); accounts and data by Supabase, Inc. (⟦dataRegion⟧).',
      ],
    ),
    (
      'Intellectual property',
      [
        'The game, its code, its design and its texts belong to the '
            'publisher. The fonts Inter, Space Grotesk and Roboto are used '
            'under the SIL Open Font License.',
      ],
    ),
    ('Contact', ['To report a problem or a content: ⟦contactEmail⟧.']),
  ];

  @override
  String get draftBanner =>
      'Draft: the highlighted parts are not filled in yet. This page is not '
      'final until they are and it has been reviewed.';

  @override
  String placeholder(LegalDetail detail) => '[${_label(detail)}]';

  @override
  String placeholderSpoken(LegalDetail detail) =>
      'Not filled in yet: ${_label(detail)}';

  String _label(LegalDetail detail) => switch (detail) {
    LegalDetail.publisher => 'publisher',
    LegalDetail.contactEmail => 'contact email',
    LegalDetail.publicationDirector => 'director of publication',
    LegalDetail.hostDetails => 'Cloudflare’s address and phone number',
    LegalDetail.dataRegion => 'Supabase region',
    LegalDetail.effectiveDate => 'date of this version',
  };
}

/// Français.
class FrenchLegalTexts implements LegalTexts {
  const FrenchLegalTexts();

  @override
  String get languageName => 'Français';

  @override
  String get privacyTitle => 'Politique de confidentialité';

  @override
  List<LegalSection> get privacy => [
    (
      'Responsable du traitement',
      [
        '${Brand.name} est édité par ⟦publisher⟧, qui décide de l’usage de '
            'vos données (le responsable du traitement). Contact : '
            '⟦contactEmail⟧.',
      ],
    ),
    (
      'Ce qui est conservé',
      [
        'Votre compte : un identifiant aléatoire ; si vous sauvegardez votre '
            'progression, votre e-mail, le nom de joueur que vous choisissez '
            'et votre déclaration d’avoir 15 ans ou plus. Votre mot de passe '
            'n’est conservé que par notre fournisseur de comptes, jamais sous '
            'une forme lisible.',
        'Chaque partie jouée : chaque question, votre réponse, son temps, si '
            'elle était juste, votre niveau à ce moment, si vous avez tapé '
            'sur le pavé ou au clavier, et la version du jeu.',
        'Les duels en ligne : chaque course jouée (réponses et temps), son '
            'résultat et vos classements de duel.',
        'Les amis : votre code ami, les demandes envoyées et reçues, et vos '
            'amis.',
        'Le fair-play : les marques que le serveur pose sur une partie ou un '
            'duel au temps impossible, les signalements de nom que vous '
            'faites et, si l’éditeur met votre compte en examen, cette '
            'décision et son motif.',
        'Les retours que vous envoyez, avec la version du jeu, et — tant que '
            'le jeu est sur invitation — le code d’invitation utilisé.',
        'Les données techniques : votre adresse IP et votre navigateur, vus '
            'par les services qui distribuent le jeu, pour vous l’envoyer et '
            'pour empêcher les abus (limites de requêtes) — et, avant la '
            'création d’un invité ou une connexion, par Cloudflare Turnstile, '
            'qui vérifie qu’une personne, et non un script, est là. Elles ne '
            'servent pas à vous identifier.',
      ],
    ),
    (
      'Pourquoi, et sur quelle base',
      [
        'Pour vous fournir le jeu que vous demandez — niveaux, historique, '
            'classements, duels, amis, un compte sauvegardé où vous '
            'reconnecter (exécution d’un contrat, article 6.1.b du RGPD).',
        'Pour garder le jeu loyal et sûr — vérifier chaque partie et chaque '
            'duel, limiter les abus, examiner les noms signalés, garder les '
            'duels terminés dans l’historique de vos adversaires (intérêt '
            'légitime, article 6.1.f).',
        'Pour améliorer le jeu — régler les niveaux sur la vitesse réelle '
            'des joueurs (intérêt légitime).',
        'Pas de publicité, pas d’outil d’analyse tiers, rien de vendu ni de '
            'partagé à des fins commerciales.',
      ],
    ),
    (
      'Qui y a accès',
      [
        'Les autres joueurs voient votre nom de joueur et vos niveaux dans '
            'les classements, seulement si vous avez sauvegardé votre '
            'progression — jamais votre e-mail ni vos parties. Un nom '
            'signalé par un autre joueur est masqué jusqu’à son examen.',
        'Les joueurs qui affrontent vos courses de duel voient votre nom de '
            'joueur, votre classement de duel et la vitesse de vos réponses '
            '— jamais ce que vous avez tapé. Vos amis voient votre nom et les '
            'duels joués ensemble.',
        'L’éditeur peut lire les données conservées pour faire fonctionner '
            'le jeu.',
        'Des prestataires les traitent pour nous, sous contrat : Supabase '
            '(comptes et base de données, ⟦dataRegion⟧), Render (le serveur '
            'du jeu, États-Unis) et Cloudflare (la distribution du site, la '
            'vérification anti-robot). Les e-mails (le lien qui confirme votre '
            'adresse) sont envoyés par Supabase. Les '
            'transferts hors de l’Union européenne reposent sur le cadre de '
            'protection des données UE–États-Unis ou sur les clauses '
            'contractuelles types de la Commission européenne.',
      ],
    ),
    (
      'Combien de temps',
      [
        'Tant que votre compte existe. Un compte invité inutilisé pendant 30 '
            'jours est supprimé avec tout ce qui le concerne.',
        'Quand vous supprimez votre compte, tout est effacé aussitôt, sur '
            'cet appareil et sur les serveurs — sauf les duels terminés, qui '
            'restent dans l’historique de vos adversaires sous « Joueur '
            'supprimé » : le résultat et la vitesse de chaque réponse, jamais '
            'votre nom ni ce que vous avez tapé.',
      ],
    ),
    (
      'Vos droits',
      [
        'Vous pouvez consulter, corriger, récupérer ou effacer vos données, '
            'vous opposer à leur usage ou en demander la limitation. Le '
            'profil change votre nom de joueur ; « Delete my data » (ou '
            '« Delete my account ») efface tout d’un coup. Pour le reste, '
            'écrivez à ⟦contactEmail⟧ : vous recevez une réponse sous un '
            'mois.',
        'Vous pouvez aussi saisir la CNIL, l’autorité française de '
            'protection des données (cnil.fr), ou celle de votre pays.',
      ],
    ),
    (
      'Âge',
      [
        'Il faut avoir 15 ans ou plus pour sauvegarder sa progression (l’âge '
            'de la majorité numérique en France). Si vous apprenez qu’une '
            'personne plus jeune l’a fait, écrivez à ⟦contactEmail⟧ : le '
            'compte est supprimé.',
      ],
    ),
    (
      'Sur votre appareil',
      [
        'Le jeu garde vos parties, vos réglages et votre connexion dans le '
            'stockage de votre navigateur, pour fonctionner hors ligne. Rien '
            'n’y sert à la publicité ni au suivi : ce stockage est '
            'nécessaire au jeu, aucun consentement n’est donc demandé.',
      ],
    ),
    (
      'Modifications',
      [
        'Cette version : ⟦effectiveDate⟧. Un changement qui vous concerne '
            'est annoncé dans le jeu.',
      ],
    ),
  ];

  @override
  String get noticeTitle => 'Mentions légales';

  @override
  List<LegalSection> get notice => [
    (
      'Éditeur',
      [
        '${Brand.name} est édité par ⟦publisher⟧. Contact : '
            '⟦contactEmail⟧.',
        'Directeur de la publication : ⟦publicationDirector⟧.',
      ],
    ),
    (
      'Hébergement',
      [
        'Le site est hébergé par Cloudflare, Inc., ⟦hostDetails⟧.',
        'Le serveur du jeu est hébergé par Render Services, Inc. '
            '(États-Unis) ; les comptes et les données par Supabase, Inc. '
            '(⟦dataRegion⟧).',
      ],
    ),
    (
      'Propriété intellectuelle',
      [
        'Le jeu, son code, son design et ses textes appartiennent à '
            'l’éditeur. Les polices Inter, Space Grotesk et Roboto sont '
            'utilisées sous licence SIL Open Font License.',
      ],
    ),
    ('Contact', ['Pour signaler un problème ou un contenu : ⟦contactEmail⟧.']),
  ];

  @override
  String get draftBanner =>
      'Brouillon : les passages surlignés ne sont pas encore remplis. Cette '
      'page n’est pas définitive tant qu’ils ne le sont pas et qu’elle n’a '
      'pas été relue.';

  @override
  String placeholder(LegalDetail detail) => '[${_label(detail)}]';

  @override
  String placeholderSpoken(LegalDetail detail) =>
      'Pas encore rempli : ${_label(detail)}';

  String _label(LegalDetail detail) => switch (detail) {
    LegalDetail.publisher => 'éditeur',
    LegalDetail.contactEmail => 'e-mail de contact',
    LegalDetail.publicationDirector => 'directeur de la publication',
    LegalDetail.hostDetails => 'adresse et téléphone de Cloudflare',
    LegalDetail.dataRegion => 'région Supabase',
    LegalDetail.effectiveDate => 'date de cette version',
  };
}
