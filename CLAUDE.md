# Math Trainer

Jeu Flutter de calcul mental compétitif (ados et adultes). Rapide, ludique, orienté compétition.
État : 43 commits, 7 types d'exercices, persistance locale, direction visuelle « nuit
électrique » livrée (étape 5), comptes Supabase (étape 6, tranches 1-2). 166 tests domaine /
280 au total.

Détails non nécessaires à chaque session : `doc/architecture.md` (structure, gestion d'état,
modèle d'exercice, dépendances), `doc/decisions.md` (arbitrages passés et leurs raisons),
`doc/design.md` (palette, typographie, notation, règles d'interface) et `doc/online.md`
(comptes, classement, mode en ligne — étapes 6 et 7).
Va les lire quand le sujet se présente — ils ne sont pas importés ici volontairement.

## Interlocuteur

Développeur expérimenté (Python, Java, C/C++, algorithmique, ML/DL), solide en architecture.
Débutant en Dart, Flutter, mobile, conventions iOS/Android, publication sur les stores.

N'explique pas les concepts généraux (patterns, tests, immutabilité, injection de dépendances).
Explique les idiomes Dart/Flutter non évidents à leur **première apparition seulement** :
`late`, `factory`, `sealed class`, enhanced enums, exhaustivité du `switch`, cycle de vie des
widgets, `BuildContext`, `const`/`final`, `Key`, `async`/`Future`/`Stream`.

## Plateforme

Développement sous Windows. Cibles Android et iOS ; le web ne sert qu'à itérer.
**Le build iOS est impossible localement** (macOS ou CI cloud requis) — ne propose jamais
de solution exigeant Xcode en local.

## Contraintes d'architecture

Non négociables sans discussion explicite.

1. **Cœur métier en Dart pur.** Aucun import `package:flutter` dans `core/domain/`.
   → tests rapides, et surtout code réexécutable côté serveur pour revalider les duels.
2. **Génération déterministe.** Seed explicite, aucun `Random()` non seedé. Même couple
   (seed, config) → même séquence, toujours. La config inclut les niveaux du joueur.
   → le mode duel exige que deux joueurs et le serveur reconstituent la même séquence.
3. **Persistance derrière une abstraction.** Aucun import `sqflite`/`shared_preferences`/`drift`
   hors de `infrastructure/`. → passage à un backend sans toucher au domaine.
4. **Repositories toujours asynchrones.** `Future<T>` même si l'implémentation est synchrone.
5. **Identifiants UUID.** Jamais d'`AUTOINCREMENT` sur une entité synchronisable.
6. **Timestamps UTC**, convertis en local à l'affichage seulement. Distinguer `createdAt`
   et `syncedAt`.
7. **Séparation stricte des couches.** Jamais UI + métier + état dans un même fichier.
8. **Modèles immuables.** `final` et `copyWith`, pas de mutation en place.
9. **Toute réponse attendue est un `int`.** `Exercise.correctAnswer` typé `int`, jamais `num` ;
   division en `~/`. → règle vérifiée par le compilateur, pas promise dans un document.
10. **La génération construit le résultat, elle ne le teste pas.** Tirer la racine `r` et
    présenter `r²` ; jamais de rejet-échantillonnage. → une boucle de rejet consomme un nombre
    variable de tirages, la séquence dépendrait des bornes et casserait la règle 2.
11. **Pas de clause `default`** sur un `switch` d'`Exercise`, d'`ExerciseType` ou
    d'`OperationType`. → l'erreur d'exhaustivité du compilateur signale les traitements oubliés.
12. **`OperationType` reste interne à `ArithmeticExercise`.** L'axe de sélection des types est
    `ExerciseType`. → l'étendre rendrait non exhaustifs les `switch` de symbole et de calcul
    binaire, forçant des cas dépourvus de sens.
13. **Un invariant se défend par `throw`, jamais par `assert`.** Les `assert` sont retirés des
    builds release : l'invariant n'existe alors plus là où il compte. Tout `assert` gardant une
    précondition publique est un bug. → trois occurrences déjà corrigées (division par zéro,
    timestamps non-UTC, `OperandRange`/`CompositeExerciseGenerator`). Chaque garde s'accompagne
    d'un test qui exerce le cas invalide.

14. **Un signal d'interface ne repose jamais sur la couleur seule.** Juste/faux se distinguent
    par la couleur *et* le mouvement *et* le retour haptique. → daltonisme, luminosité extérieure,
    et lisibilité à la vitesse où le jeu se joue.

## Stratégie de données

Tout est local aujourd'hui : `shared_preferences` pour les scalaires, SQLite pour l'historique.

**Granularité obligatoire :** stocker chaque réponse individuelle (type, opérandes, réponse
donnée, temps, correct/incorrect, niveau au moment du jeu), jamais des agrégats — le moteur
adaptatif doit pouvoir isoler une lenteur sur une opération à un palier donné, et un agrégat ne
se décompose pas rétroactivement.

**Les niveaux sont un cache, pas une source de vérité.** Ils se recalculent intégralement à
partir de l'historique des réponses. → le serveur recalculera lui-même plutôt que de croire un
client qui annoncerait 700 au classement. La fonction de mise à jour appartient donc au domaine
pur, au même titre que le `Scorer`, et doit pouvoir être rejouée sur une liste de réponses.

Plus tard, offline-first : local = source de vérité en solo et cache du reste ; serveur =
autorité **exclusive** sur tout le compétitif (Elo, classement, résultats de duels).

Backend tranché à l'étape 6 : **Supabase** (Postgres, agrégations natives pour le ladder ;
Auth intégrée). La règle 1 (code réexécutable côté serveur) exclut de faire porter le calcul de
niveau/score par les Edge Functions Supabase (TypeScript, pas Dart) : un petit service Dart
dédié (probablement `shelf`), hébergé à part, réutilise `core/domain` tel quel pour revalider
niveau et score à partir des réponses soumises — Supabase reste la source pour Auth et Postgres,
mais n'est jamais celle qui calcule un niveau. Détail : `doc/online.md`.

## Périmètre

Faites : 1. tests du cœur métier — 2. persistance locale — 3. sept types d'exercices —
4. système de niveaux — 4.1 corrections (échantillonnage garanti, erreurs UI, découplage,
rangement, script de recalibration).

**Étape 4.2 — boucle de session ← courante.** Timeout de 15 s par question avec passage
automatique ; interruption de la session après 3 timeouts consécutifs sans saisie (non
comptabilisée, réponses déjà données conservées) ; pas de niveau pondéré par `√(n / n_min)` ;
`n_min` 8 → 4, **couplé à un élargissement de `δ`** ; relance immédiate en fin de session (mêmes
types, niveaux actualisés, **nouvelle seed**). Le nombre de questions reste dérivé
(`n_min × types actifs`), le joueur ne le règle pas. Détail et justifications :
`doc/decisions.md`.

**Étape 5 — direction visuelle et expérience (terminée).** Direction « nuit électrique » :
palette, typographie, notation mathématique, pavé intégré, navigation, animations et disposition
des écrans, tout est arrêté dans `doc/design.md`. Lis-le avant d'écrire une ligne de
`presentation/`. Livrée avec, en plus du périmètre initial : bascule nuit/jour persistée, niveau
global calculé sur les 7 types (plancher à 1 pour un type jamais joué, pas d'exclusion), écran de
progression qui se recharge à chaque retour sur l'onglet.

**Étape 6 — comptes et classement général.** Création de compte, identité en ligne, classement
solo entre tous les joueurs de l'app. Direction, choix de backend (Supabase) et architecture
détaillés dans `doc/online.md` — lis-le avant d'écrire une ligne touchant aux comptes ou au
réseau. Pas de duels ni d'Elo dans cette étape (voir étape 7) : « pas d'abstraction pour un seul
cas d'usage » s'applique aussi au matchmaking, qui n'existe pas encore.

- Tranche 1 (livrée) : création de compte, connexion.
- Tranche 2 ← courante : connexion obligatoire pour utiliser l'app (session persistée
  localement — pas de réseau requis à chaque lancement pour un joueur déjà connecté), nom de
  joueur, onglet Progression renommé Profil.
- Tranche 3 : classement solo, synchronisation des réponses, service Dart de validation serveur.

Hors périmètre de l'étape 6 : matchs en ligne, Elo, matchmaking (étape 7).

Ensuite : 7. matchs en ligne et Elo (`doc/online.md`, section « Étape 7 »).

**Point d'attente indépendant du code :** les ~20 constantes du système de niveaux restent non
calibrées faute de données. `tool/recalibrate.dart` existe mais n'a rien à traiter tant que
quelques dizaines de sessions réelles n'ont pas été jouées.

**N'implémente rien au-delà de l'étape courante sans demande explicite.**

## Hors périmètre (définitif)

**Fractions** et **divisions euclidiennes** : réponses non entières ou composites, contraires à
la règle 9. Ne pas reproposer.

## Futur (anticiper, ne pas implémenter)

Multijoueur, duels, ligues, saisons, tournois, défis quotidiens, XP, badges, moteur adaptatif,
abonnement, publicité, analytics.
Anticiper = ne pas fermer la porte. Pas d'abstraction pour un seul cas d'usage.

## Règles de collaboration

- **Proposer avant d'implémenter.** Mode Plan pour toute tâche non triviale, attendre validation.
- **Vérifier les ripples avant d'implémenter** — suivre chaque renommage ou ajout de champ
  jusqu'à la persistance. Le renommage `operationTypes` → `enabledTypes` aurait silencieusement
  cassé l'historique si `PersistedSession` n'avait pas été suivi jusqu'au bout.
- **Expliquer les conséquences** de toute décision architecturale, y compris sur le futur.
- **Ne pas réécrire du code qui fonctionne.** Modifications minimales et ciblées.
- **Lister les fichiers modifiés** avec une justification brève.
- En cas d'ambiguïté, proposer une solution raisonnable et expliciter le choix.
- Simplicité avant sur-ingénierie. Une étape à la fois, livrable et testable, puis un commit.
- **Signaler les écarts** constatés entre le code réel et `doc/architecture.md`.

## Conventions

- Toute logique métier ajoutée vient avec ses tests unitaires.
- **Chaque variante d'`Exercise` implémente `==` et `hashCode`.** Le compilateur ne l'exige pas ;
  un test paramétré sur `ExerciseType.values` sert de garde-fou.
- Commenter uniquement le non-évident, jamais paraphraser le code.
- Pas de valeur codée en dur dans l'UI : `Theme.of(context)`.
- `SafeArea` sur tous les écrans (notch, Dynamic Island).
- Saisie numérique : `TextInputType.number`, et vérifier que le clavier natif ne masque
  ni le champ ni le chrono.
- **Les tests de déterminisme sont indexés sur le couple (seed, config)**, jamais sur la seed
  seule : ajouter une valeur à `ExerciseType` ou changer un niveau modifie légitimement la
  séquence.

(Nommage, formatage et lints : imposés par `flutter_lints`, vérifiés par `dart analyze`.)

## Validation avant commit

1. `dart test test/domain` puis `flutter test` au vert
2. `flutter analyze` sans avertissement
3. **Vérification sur Android réel ou émulateur** — jamais uniquement sur web.
   *Suspendu temporairement (depuis le 2026-11-17, demande de l'utilisateur) : émulateur
   inutilisable, développement sur web uniquement. Signaler dans chaque commit que la
   vérification Android reste à faire.*

## Commandes

```bash
dart test test/domain      # cœur métier — le scope est obligatoire (cf. pièges)
flutter test               # tests incluant les widgets
flutter analyze            # analyse statique
flutter run -d edge --web-port=8080 --dart-define-from-file=dart_defines.json
                           # itération rapide (port fixe : cf. pièges)
flutter build apk --debug --dart-define-from-file=dart_defines.json \
  && adb install -r <apk> && adb shell am start <activité>
                           # vérification Android fiable (cf. pièges)
```

`dart_defines.json` (non versionné, modèle : `dart_defines.example.json`) porte l'URL et la clé
publique Supabase. Sans lui, l'app démarre sur un écran « Configuration manquante ».

## Pièges (non déductibles du code)

- **Ne jamais tirer au hasard directement dans un `Set`.** L'ordre d'itération suit l'insertion :
  `{power, addition}` et `{addition, power}` donneraient des séquences différentes pour la même
  seed, cassant la règle 2 sans erreur visible. Convertir en liste triée par `index` d'enum.
- **`flutter run` attaché se déconnecte** de façon répétée sur cet environnement. Préférer
  `flutter build apk --debug` puis `adb install -r` et `adb shell am start`, nettement plus fiable.
- `CompositeExerciseGenerator` consomme un tirage inutile (`nextInt(1)`) par exercice
  arithmétique. Sans conséquence fonctionnelle, mais **le supprimer changerait toutes les
  séquences pour une seed donnée** — donc jamais en même temps qu'autre chose.
- Les noms des valeurs d'`ExerciseType` servent de discriminant en base via `exercise_codec`.
  Les renommer casse l'historique déjà stocké.
- `dart test` **sans le scope `test/domain`** échoue : il scanne aussi les tests widgets.
- `kotlin.incremental=false` dans `android/gradle.properties` contourne un bug Windows
  (compilateur Kotlin qui plante quand projet et caches Gradle sont sur des lettres de lecteur
  différentes). À revérifier sur machine propre ou en CI avant le premier `flutter build appbundle`.
- **Rien n'est persisté sur web** : `InMemorySessionRepository` sert de repli, un rechargement
  efface tout. À traiter avant tout déploiement web public.
- **Sur web, toujours le même port** (`--web-port=8080`). Session Supabase, `playerId`, thème et
  sélection de types vivent dans le `localStorage`, propre à l'origine (port compris) : un port
  aléatoire à chaque `flutter run` repart d'un joueur inconnu et déconnecté.
- **Environnement Windows à cheval sur C: et D:** (migration partielle du 14/08/2026) : SDK
  Android, AVD et `GRADLE_USER_HOME` sur `D:\Users\GREgo`, cache pub encore sur `C:`. Le cache
  Gradle copié était corrompu (« immutable workspace … modified ») ; vider
  `D:\Users\GREgo\.gradle\caches\<version>\transforms` règle ce symptôme.
- **Table `profiles` côté Supabase** : créée par `supabase/profiles.sql` (à exécuter dans
  l'éditeur SQL du projet) — rien ne la crée automatiquement.
- `sqrt()` en virgule flottante est à proscrire : arithmétique entière uniquement.
