# Décisions — Math Trainer

Arbitrages passés et leurs raisons. **Non chargé automatiquement.** Objet : éviter de
re-litiguer une question déjà tranchée, et documenter à quelle condition rouvrir le dossier.

## `correctAnswer` typé `int` et non `num` (étape 3)

À l'origine `num`, avec `/` pour la division — donc un `double`. La règle 9 était alors une
promesse documentaire que le type système contredisait. Ça fonctionnait par chance : en Dart
`4 == 4.0` vaut `true`. Le jour où un résultat n'est pas exactement représentable en binaire,
la comparaison échoue silencieusement et le joueur voit une bonne réponse comptée fausse.
Passage à `int` et `~/`, décidé avant l'ajout des trois nouvelles variantes qui auraient
hérité de la signature fragile.

## `ExerciseType` au-dessus d'`OperationType` (étape 3)

Option écartée : étendre `OperationType` avec `power`, `squareRoot`, `percentage`.
`OperationType` n'est pas un axe de sélection mais un champ interne à `ArithmeticExercise`,
consommé par deux `switch` exhaustifs produisant un symbole et un calcul binaire. L'étendre
aurait rendu ces `switch` non exhaustifs et forcé l'écriture de cas absurdes (un symbole
d'opération binaire pour une racine), transformant la règle 11 en corvée de remplissage.

## Pas de `List<int> operands` générique sur `Exercise`

Envisagé pour absorber les variantes unaires (racine) et de futurs types exotiques.
Abandonné : la règle 9 ferme la porte aux types exotiques, donc le gain serait nul, tandis
que le coût serait de retoucher du code stable et de perdre le nommage métier des opérandes.
`operands_json` couvre déjà le besoin côté stockage.

## Fractions et divisions euclidiennes écartées du jeu

D�cision produit, définitive. Toutes deux violent la règle 9 : les fractions par leur type de
réponse, la division euclidienne par sa réponse composite (quotient + reste, donc deux champs
de saisie, gestion du focus, validation partielle). Conséquence : la colonne de réponse reste
`INTEGER` et `TextInputType.number` reste l'unique mode de saisie.

## `ChangeNotifier` natif plutôt que provider / riverpod / bloc

Un seul contrôleur actif sur trois écrans séquentiels ne justifie pas un package.
**Rouvrir quand** le multijoueur introduira des flux réseau concurrents (état du duel,
présence de l'adversaire).

## `sqflite` plutôt que `drift`

Schéma écrit à la main, pas de génération de code ni de build_runner dans la boucle.
Le volume de requêtes ne justifie pas le coût d'outillage de `drift`.
**Rouvrir si** les requêtes analytiques du moteur adaptatif deviennent pénibles à la main.

## Pas de dépendance `uuid`

Un générateur UUID v4 pure Dart (`core/domain/persistence/uuid.dart`, ~15 lignes,
`Random.secure()`) suffit.

## Pas de persistance web

`InMemorySessionRepository` sert de repli sur web ; un rechargement efface tout. Décision
assumée tant que le web n'est qu'une cible d'itération, pas de distribution.
**Rouvrir avant** tout déploiement web accessible à des joueurs réels, et de toute façon à
l'arrivée de la synchronisation serveur, qui exigera un cache local côté navigateur.

## Pas de comptes utilisateurs pour l'instant

Un backend avec comptes coûte incomparablement plus qu'un adaptateur de persistance local, et
l'app aurait de toute façon besoin de persistance locale (jouabilité hors ligne). Le schéma
est déjà prêt pour la synchro (`player_id`, UUID côté client, `synced_at`).
**Quand ce sera le moment :** authentification anonyme d'abord (compte invisible, données
sauvegardées), création de compte explicite seulement au passage sur un second appareil.
Imposer une inscription à l'ouverture ferait fuir une part importante des joueurs.
À noter : un public scolaire ou enfantin fait entrer le RGPD dans l'équation (consentement
parental, conservation, suppression).

## `points_awarded` retiré de la table `answers` (étape 2)

Proposé au plan initial, retiré à l'implémentation : absent de la liste explicite des colonnes,
et il faisait grossir le changement en retouchant `Scorer` et `AnswerResult`, tous deux stables.

## `kotlin.incremental=false`

Contourne un bug Windows : le compilateur Kotlin plante quand le projet et les caches Gradle
sont sur des lettres de lecteur différentes (D: vs C:). Purement environnemental.
**À revérifier** sur machine propre ou en CI avant le premier `flutter build appbundle`.
