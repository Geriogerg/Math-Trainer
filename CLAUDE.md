# Math Trainer

Jeu Flutter de calcul mental compétitif (ados et adultes). Rapide, ludique, orienté compétition.
État : MVP + persistance locale, validé Android et web.

Détails non nécessaires à chaque session : `docs/architecture.md` (structure, gestion d'état,
modèle d'exercice, dépendances) et `docs/decisions.md` (arbitrages passés et leurs raisons).
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
   (seed, config) → même séquence, toujours.
   → le mode duel exige que deux joueurs et le serveur reconstituent la même séquence.
3. **Persistance derrière une abstraction.** Aucun import `sqflite`/`shared_preferences`/`drift`
   hors de `infrastructure/`. → passage à un backend sans toucher au domaine.
4. **Repositories toujours asynchrones.** `Future<T>` même si l'implémentation est synchrone.
   → sinon toute la chaîne d'appel serait à réécrire à l'arrivée du réseau.
5. **Identifiants UUID.** Jamais d'`AUTOINCREMENT` sur une entité synchronisable.
   → deux appareils générant `id = 1` créent un conflit insoluble.
6. **Timestamps UTC**, convertis en local à l'affichage seulement. Distinguer `createdAt`
   et `syncedAt`. → séries et classements incohérents sinon en cas de changement de fuseau.
7. **Séparation stricte des couches.** Jamais UI + métier + état dans un même fichier.
   Aucune logique métier dans un widget.
8. **Modèles immuables.** `final` et `copyWith`, pas de mutation en place.
9. **Toute réponse attendue est un `int`.** `Exercise.correctAnswer` est typé `int`, jamais
   `num` ni `double` ; la division utilise `~/`. Aucun type d'exercice n'introduit de réponse
   composite, fractionnaire ou approchée. → la règle est vérifiée par le compilateur et non
   promise dans un document ; maintient `TextInputType.number`, la colonne `INTEGER`, et évite
   une refonte UI + `Scorer` + codec + schéma. Comparer des `double` exposerait à une réponse
   correcte comptée fausse par erreur de représentation binaire.
10. **La génération construit le résultat, elle ne le teste pas.** Tirer la racine `r` et
    présenter `r²` ; jamais de rejet-échantillonnage. → une boucle de rejet consomme un
    nombre variable de tirages, la séquence dépendrait des bornes et casserait la règle 2.
11. **Pas de clause `default`** sur un `switch` d'`Exercise`, d'`ExerciseType` ou
    d'`OperationType`. → l'erreur d'exhaustivité du compilateur est ce qui signale les points
    de traitement oubliés à l'ajout d'un type ; un `default` masque le trou.
12. **`OperationType` reste interne à `ArithmeticExercise`.** L'axe de sélection des types
    d'exercice est `ExerciseType`. → y ajouter `power` ou `squareRoot` rendrait non exhaustifs
    les `switch` de symbole et de calcul binaire, forçant des cas dépourvus de sens.

## Stratégie de données

Tout est local aujourd'hui : `shared_preferences` pour les scalaires, SQLite pour l'historique.

**Granularité obligatoire :** stocker chaque réponse individuelle (type, opérandes, réponse
donnée, temps, correct/incorrect), jamais seulement des agrégats — le futur moteur adaptatif
doit pouvoir isoler une lenteur sur les tables de 7/8/9 ou sur les carrés élevés, et un
agrégat ne se décompose pas rétroactivement.

Plus tard, offline-first : local = source de vérité en solo et cache du reste ; serveur =
autorité **exclusive** sur tout le compétitif (Elo, classement, résultats de duels). Le client
ne calcule jamais un Elo et ne s'auto-attribue jamais un résultat.

Backend non tranché, Supabase privilégié (Postgres, agrégations natives pour le ladder).
Ne pas introduire de dépendance qui fermerait cette option.

## Périmètre

Étapes 1 (tests du cœur métier) et 2 (persistance locale) : faites.

**Étape 3 — élargissement des types d'exercices ← courante.** Trois types, tous à réponse
entière (règle 9) : puissances et carrés ; racines carrées de carrés parfaits ; pourcentages
entiers (5, 10, 20, 25, 50 sur bases compatibles). Inclut le passage de `correctAnswer` en
`int`, l'enum `ExerciseType`, `Set<ExerciseType> enabledTypes` dans `SessionConfig`, un
`CompositeExerciseGenerator` alimenté par **un seul flux seedé**, l'extension
d'`exercise_codec.dart`, et la sélection des types sur `HomeScreen`.
Une session mono-type est une session dont l'ensemble actif a un seul élément — pas deux modes.

Hors de l'étape 3 : plages d'opérandes et niveaux de difficulté (étape 4) ; les bornes restent
des constantes internes aux générateurs, `OperandRange` par type est la couture prévue, la
laisser apparente. Scoring uniforme entre types, la pondération par difficulté relève aussi
de l'étape 4.

Ensuite : 4. difficulté paramétrable — 5. polish UI et feedback.
**N'implémente rien au-delà de l'étape courante sans demande explicite.**

## Hors périmètre (définitif)

Écartés par décision produit, ne pas reproposer : **fractions** et **divisions euclidiennes
(quotient + reste)** — réponses non entières ou composites, contraires à la règle 9.

## Futur (anticiper, ne pas implémenter)

Comptes, backend, multijoueur, duels, classement, Elo, ligues, saisons, tournois, défis
quotidiens, XP, niveaux, séries, badges, moteur adaptatif, abonnement, analytics.
Anticiper = ne pas fermer la porte. Pas d'abstraction pour un seul cas d'usage.

## Règles de collaboration

- **Proposer avant d'implémenter.** Mode Plan pour toute tâche non triviale, attendre validation.
- **Expliquer les conséquences** de toute décision architecturale, y compris sur le futur.
- **Ne pas réécrire du code qui fonctionne.** Modifications minimales et ciblées.
- **Lister les fichiers modifiés** avec une justification brève.
- En cas d'ambiguïté, proposer une solution raisonnable et expliciter le choix.
- Simplicité avant sur-ingénierie. Une étape à la fois, livrable et testable, puis un commit.

## Conventions

- Toute logique métier ajoutée vient avec ses tests unitaires.
- **Chaque variante d'`Exercise` implémente `==` et `hashCode`.** Le compilateur ne l'exige
  pas ; un test paramétré sur `ExerciseType.values` sert de garde-fou. Sans lui, une variante
  oublieuse casse les tests de déterminisme avec un message opaque.
- Commenter uniquement le non-évident, jamais paraphraser le code.
- Pas de valeur codée en dur dans l'UI : `Theme.of(context)`.
- `SafeArea` sur tous les écrans (notch, Dynamic Island).
- Saisie numérique : `TextInputType.number`, et vérifier que le clavier natif ne masque
  ni le champ ni le chrono.
- **Les tests de déterminisme sont indexés sur le couple (seed, config)**, jamais sur la seed
  seule : ajouter une valeur à `ExerciseType` change légitimement la séquence, une référence
  figée transformerait chaque évolution de l'enum en fausse régression.

(Nommage, formatage et lints : imposés par `flutter_lints`, vérifiés par `dart analyze`.)

## Validation avant commit

1. `dart test test/domain` puis `flutter test` au vert
2. `flutter analyze` sans avertissement
3. **Vérification sur Android réel ou émulateur** — jamais uniquement sur web

## Commandes

```bash
dart test test/domain      # cœur métier — le scope est obligatoire (cf. pièges)
flutter test               # tests incluant les widgets
flutter analyze            # analyse statique
flutter run -d edge        # itération rapide
flutter run                # device Android
```

## Pièges (non déductibles du code)

- **Ne jamais tirer au hasard directement dans un `Set`.** L'ordre d'itération d'un `Set` Dart
  suit l'insertion : `{power, addition}` et `{addition, power}` produiraient des séquences
  différentes pour la même seed, cassant la règle 2 sans aucune erreur visible. Convertir en
  liste triée par `index` d'enum avant tout tirage.
- Les noms des valeurs d'`ExerciseType` servent de discriminant en base via `exercise_codec`.
  Conserver les noms existants (`addition`, `subtraction`…) évite toute migration de
  l'historique déjà stocké.
- `dart test` **sans le scope `test/domain`** échoue : il scanne aussi les tests widgets,
  qui importent Flutter et sont incompatibles avec ce runner.
- `kotlin.incremental=false` dans `android/gradle.properties` contourne un bug Windows
  (plantage du compilateur Kotlin quand projet et caches Gradle sont sur des lettres de
  lecteur différentes). Purement environnemental — à revérifier sur machine propre ou en CI
  avant le premier `flutter build appbundle`.
- **Rien n'est persisté sur web** : `InMemorySessionRepository` sert de repli, un rechargement
  efface tout. Décision assumée tant que le web reste une cible d'itération. À traiter
  impérativement avant tout déploiement web public.
- `sqrt()` en virgule flottante est à proscrire : arithmétique entière uniquement pour les
  carrés parfaits, sous peine d'erreurs d'arrondi sur les grandes valeurs.
