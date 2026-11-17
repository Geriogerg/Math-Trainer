import 'account.dart';

/// Compte en ligne — implémentation concrète (Supabase) dans
/// `infrastructure/backend/`, jamais dans le domaine (règle 3).
abstract class AccountRepository {
  /// Compte connecté, `null` si personne n'est connecté. Chaque abonnement
  /// reçoit d'abord l'état **courant**, puis chaque changement (connexion,
  /// déconnexion, expiration de session) sans polling — donc `.first` donne
  /// le compte connecté à l'instant de l'appel, jamais un état antérieur.
  Stream<Account?> get authState;

  /// `null` : compte créé, mais confirmation par email requise avant de
  /// pouvoir se connecter (comportement par défaut d'un projet Supabase) —
  /// distinct d'un échec, `authState` reste `null` jusqu'à la confirmation
  /// et une connexion explicite. Lance une `Exception` en cas d'échec réel
  /// (email déjà utilisé, réseau indisponible).
  Future<Account?> signUp({required String email, required String password});

  /// Lance une `Exception` en cas d'échec (identifiants invalides, réseau
  /// indisponible).
  Future<Account> signIn({required String email, required String password});

  Future<void> signOut();
}
