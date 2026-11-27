import '../account_strings.dart';
import '../brand.dart';

/// [AccountStrings] en français (Phase 6d).
class FrenchAccountStrings implements AccountStrings {
  const FrenchAccountStrings();

  @override
  final appName = Brand.name;

  @override
  final email = 'E-mail';

  @override
  final password = 'Mot de passe';

  @override
  final showPassword = 'Afficher le mot de passe';

  @override
  final hidePassword = 'Masquer le mot de passe';

  @override
  final playerName = 'Nom de joueur';

  @override
  final save = 'Enregistrer';

  @override
  final haveAccount = 'J’ai déjà un compte';

  @override
  final privacyPolicy = 'Confidentialité';

  @override
  final legalNotice = 'Mentions légales';

  @override
  final ageBox = 'J’ai 15 ans ou plus';

  @override
  final ageMissing =
      'Il faut avoir 15 ans ou plus pour sauvegarder ta progression\u202f: coche '
      'la case si c’est ton cas.';

  @override
  final signIn = 'Se connecter';

  @override
  final signInMissing = 'Entre ton e-mail et ton mot de passe.';

  @override
  final guestReplaced =
      'Ta progression d’invité sur ce navigateur sera remplacée par ce compte. '
      'Elle reste sur cet appareil mais n’est plus affichée, et les deux '
      'historiques ne sont jamais fusionnés. Pour la garder, reviens en arrière '
      'et sauvegarde ta progression avec un nouvel e-mail.';

  @override
  final signInReplacing = 'Se connecter et remplacer la progression';

  @override
  final saveProgress = 'Sauvegarde ta progression';

  @override
  final saveProgressMissing =
      'Entre un e-mail, un mot de passe et un nom de joueur.';

  @override
  final saveProgressDetail =
      'Tes niveaux et ton historique restent tels quels. Avec un e-mail et un '
      'mot de passe, tu peux jouer sur un autre appareil, et ton nom de joueur '
      'peut apparaître dans les classements.';

  @override
  final signInInstead = 'Me connecter à ce compte';

  @override
  final gateDetail =
      'La bêta se fait sur invitation. Entre le code de ton invitation.';

  @override
  final invitationCode = 'Code d’invitation';

  @override
  final checking = 'Vérification…';

  @override
  final continueLabel = 'Continuer';

  @override
  final codeEmpty = 'Entre le code de ton invitation.';

  @override
  final codeInvalid =
      'Ce code n’est pas valide. Vérifie-le sur ton invitation.';

  @override
  final codeFull = 'Ce code a déjà été utilisé.';

  @override
  final codeDisabled = 'Ce code n’est plus actif.';

  @override
  final codeOffline = 'Pas de connexion. Vérifie-la et réessaie.';

  @override
  final couldNotStart = 'Démarrage impossible';

  @override
  final tryAgain = 'Réessayer';

  @override
  final startOffline =
      'Pas de connexion. ${Brand.name} a besoin d’internet la première fois\u202f; '
      'ensuite, il marche aussi hors ligne.';

  @override
  final startRateLimited =
      'Trop de nouveaux joueurs depuis ce réseau en ce moment. Réessaie dans '
      'quelques minutes.';

  @override
  final startUnknown = 'Le jeu n’a pas pu démarrer. Réessaie.';

  @override
  final forgotPassword = 'Mot de passe oublié\u202f?';

  @override
  final resetTitle = 'Réinitialiser ton mot de passe';

  @override
  final resetDetail =
      'Entre l’e-mail de ton compte\u202f: un lien pour choisir un nouveau mot de '
      'passe y sera envoyé.';

  @override
  final sendLink = 'Envoyer le lien';

  @override
  String resetSent(String email) =>
      'Si un compte utilise $email, un lien est en route. Ouvre-le sur cet '
      'appareil ou un autre\u202f: il te ramène ici pour choisir un nouveau mot '
      'de passe.';

  @override
  final resetMissing = 'Entre ton e-mail.';

  @override
  final newPasswordTitle = 'Nouveau mot de passe';

  @override
  final newPasswordDetail =
      'Tu as ouvert un lien de mot de passe\u202f: choisis un nouveau mot de passe '
      'pour ce compte.';

  @override
  final newPassword = 'Nouveau mot de passe';

  @override
  final newPasswordMissing = 'Entre un nouveau mot de passe.';

  @override
  final passwordChanged = 'Mot de passe changé.';

  @override
  final emailConfirmed =
      'E-mail confirmé\u202f: ta progression est sauvegardée.';

  @override
  final linkFailed =
      'Ce lien a expiré ou a déjà servi. Demandes-en un nouveau.';

  @override
  final checkInbox = 'Regarde ta boîte mail';

  @override
  String linkSent(String email) =>
      'Un lien a été envoyé à $email. Ouvre-le pour finir de sauvegarder ta '
      'progression. D’ici là, tu joues en invité\u202f: rien n’est perdu.';

  @override
  final sendAgain = 'Renvoyer le lien';

  @override
  final sentAgain = 'Renvoyé. Ça peut prendre une minute pour arriver.';

  @override
  final done = 'Terminé';

  @override
  final startHumanCheck =
      'La vérification anti-robot n’a pas abouti. Réessaie.';

  @override
  final startFailedTitle = 'Le jeu n’a pas pu démarrer';

  @override
  final startFailedDetail =
      'Recharge la page. Si ça recommence, réessaie un peu plus tard.';

  @override
  String detail(Object error) => 'Détail\u202f: $error';

  @override
  final missingConfigTitle = 'Configuration manquante';

  @override
  String missingConfig(List<String> keys) =>
      'Cette version a été lancée sans la configuration Supabase '
      '(${keys.join(', ')}).';

  @override
  final missingConfigFix =
      'Relance-la avec\u202f:\n'
      '--dart-define-from-file=dart_defines.json\n\n'
      'Modèle\u202f: dart_defines.example.json';

  @override
  final webStorageTitle = 'Stockage web indisponible';

  @override
  final webStorageDetail =
      'La base de données locale n’a pas pu s’ouvrir dans le navigateur\u202f: '
      'web/sqlite3.wasm ou web/sqflite_sw.js manque sans doute.';

  @override
  final webStorageFix =
      'Génère-les une fois, depuis le dossier du projet\u202f:\n'
      'dart run sqflite_common_ffi_web:setup';
}
