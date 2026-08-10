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

## Le niveau est une estimation de compétence, pas une barre de progression

Option écartée : un niveau qui ne fait que monter avec le temps de jeu. Il aurait classé
l'assiduité plutôt que la compétence, et se serait tassé au plafond (tous ex æquo à 700/700)
en quelques mois, tuant le classement général.

Retenu : un niveau par opération reflétant la difficulté à laquelle le joueur répond juste et
vite. Il monte, il plafonne, et **il descend sur performance insuffisante**.

Option également écartée : ne faire descendre le niveau que par inactivité. Deux raisons.
D'une part c'est incohérent avec une estimation de compétence — un joueur qui échoue
systématiquement resterait bloqué à son meilleur jour, sur des questions dérivées d'un niveau
qu'il ne tient plus, sans mécanisme de retour. D'autre part, punir l'absence est une mécanique
de rétention agressive qui génère de la culpabilité et pousse à la désinstallation.

Compensation retenue à la place : après une longue absence, le multiplicateur `boost_retour`
fait bouger le niveau plus vite **dans les deux sens** pendant quelques sessions. Le joueur ne
perd rien, le système se réétalonne. C'est un facteur K variable appliqué au temps.

Conséquences : le niveau est l'unité comparable du classement général (les scores bruts ne le
sont pas, puisque les joueurs ne reçoivent pas les mêmes questions) ; et le taux de réussite
converge vers `p_cible` pour tout le monde, donc **il ne mesure plus rien et ne doit jamais
être affiché comme une récompense**. Ce qui progresse, c'est le niveau.

## Paramètres du système de niveaux — valeurs de départ

**Non calibrées.** Issues d'un simulateur reposant sur une hypothèse logistique de la courbe
de performance, pas de données réelles. À recalibrer en rejouant l'historique une fois quelques
dizaines de sessions accumulées — c'est l'usage prévu de la granularité de stockage.

Formule, par question : `p = 0` si faux, sinon `p = f + (1 − f) · vitesse`, où `vitesse` vaut 1
sous `t_rapide`, 0 au-dessus de `t_lent`, linéaire entre les deux.
En fin de session : `Δ = moyenne(p) − p_cible` ; si `|Δ| < δ` le niveau ne bouge pas ; sinon on
retire la bande morte, on multiplie par `K_haut` ou `K_bas` puis par le multiplicateur de
confiance, on borne à `Δ_max`, on applique.

| Paramètre | Valeur | Note |
|---|---|---|
| `p_cible` | 0,70 | performance d'équilibre visée |
| `f` | 0,30 | crédit d'une bonne réponse lente ; **paramètre de tempérament** — monter vers 0,60 rend le jeu plus nerveux |
| `K_haut` | 3,0 | vitesse de montée |
| `K_bas` | 1,5 | vitesse de descente ; ratio 2:1 volontaire |
| `δ` | 0,05 | bande morte ; à 0 le niveau oscille en permanence |
| `Δ_max` | 3 | déplacement max par session |
| `n_min` | 8 | en deçà, la session ne compte pas (échantillon de bruit) |
| `K_calib` | ×4 sur 3 sessions | calibrage initial |
| `boost_retour` | ×2 sur 2 sessions | après longue absence |
| `t_rapide` | 2000 ms | vitesse = 1 en deçà |
| `t_lent` | 8000 ms | vitesse = 0 au-delà ; ordre de grandeur choisi par cohérence avec `speedBonusWindowMs = 5000` de `ScoringRules`, sans lien fonctionnel avec lui |

**Portée de `t_rapide`/`t_lent` : deux constantes globales**, indépendantes de l'axe « temps
imparti » du commit C (qui varie par opération et par niveau, mais pour la *génération* des
exercices — un sujet distinct du calcul de `vitesse` dans la formule de mise à jour).

Cibles de réglage : convergence en 10–20 sessions, oscillation à l'équilibre sous ±2 niveaux,
biais moyen légèrement positif (conséquence attendue de `K_haut > K_bas`, sans effet sur
l'équité du classement puisqu'il s'applique identiquement à tous).

Le ratio `K_haut / K_bas` fait que le niveau surestime légèrement la compétence réelle. Choix
assumé : le confort du joueur prime, et le biais étant uniforme il ne fausse pas la comparaison.

## Un seul axe de difficulté à la fois

La difficulté dérive du niveau par l'ampleur des opérandes. **Ne pas faire varier simultanément
la taille des opérandes et le temps imparti** : les deux effets se composeraient et produiraient
une courbe brutale au milieu de l'échelle, difficile à diagnostiquer.

Conséquence sur la règle 2 : la séquence n'est plus reproductible à partir de la seed seule,
puisque les bornes dépendent du niveau. Le niveau doit entrer explicitement dans la config,
**être figé au début de la session** et jamais recalculé en cours de route — sinon le serveur ne
peut pas revalider et le mode duel tombe.

700 paliers (7 opérations × 100) ne se calibrent pas à la main : une fonction continue
`niveau → bornes` par opération, cinq points d'ancrage vérifiés manuellement (1, 25, 50, 75, 100),
et deux tests — monotonie et absence de saut brutal entre niveaux consécutifs.

## Interpolation linéaire, pas une table à 5 points (étape 4, commit C)

La « fonction continue » est une interpolation linéaire entre une valeur à niveau 1 et une
valeur à niveau 100 (2 paramètres par axe) — pas une table piecewise-linear à 5 segments. Les
points d'ancrage (1, 25, 50, 75, 100) de la section précédente restent des points de **test**
(monotonie, absence de saut), pas la définition de la fonction : avec seulement 2 points de
contrôle, monotonie et continuité sont garanties par construction, donc les tests documentent la
propriété plutôt que de la re-prouver.

Conséquence pratique : les 4 opérations arithmétiques, qui produisent toutes le même type de
sortie (`OperandRange`), partagent une seule classe paramétrée (`LinearOperandRangeDifficulty`)
plutôt que 4 corps de fonction dupliqués. « Sept fonctions niveau → bornes » se lit donc comme
sept points d'entrée (`additionDifficulty`, ..., `percentageDifficulty`), pas sept implémentations
séparées.

`lib/core/domain/difficulty/` centralise ces sept tables, parallèle à `leveling/` et `scoring/`.

## Un seul axe par opération, et lequel (étape 4, commit C)

| Opération | Axe qui varie | Fixe |
|---|---|---|
| Addition, soustraction | `max` de l'opérande (`min` reste à 1) | — |
| Multiplication, division | `max` du facteur (`min` reste à 1) | — |
| Puissance | `max` de l'exposant (`min` reste à 2) | base ∈ [2, 10] |
| Racine carrée | `max` de la racine tirée (`min` reste à 2) | — |
| Pourcentage | `min` et `max` de `percent` s'écartent tous deux | multiplicateur de base ∈ [1, 10] |

Valeurs de départ, **non calibrées** comme le reste des paramètres du système de niveaux :

| Axe | Niveau 1 | Niveau 100 |
|---|---|---|
| Addition / soustraction (max) | 5 | 999 |
| Multiplication / division (max) | 5 | 50 |
| Puissance (exposant max) | 2 | 5 |
| Racine (max) | 4 | 40 |
| Pourcentage (min, max) | 10, 50 | 1, 99 |

**Écart assumé sur les pourcentages.** La liste discrète {5, 10, 20, 25, 50} de l'étape 3
devient une plage continue de `percent`, pour rester cohérente avec le mécanisme d'interpolation
linéaire retenu pour les six autres axes — une liste ne s'interpole pas naturellement entre deux
points de contrôle. L'exactitude de la génération reste garantie par construction
(`percent × base` multiple de 100) quel que soit le pourcentage tiré : la « rondeur » de
5/10/20/25/50 n'a jamais été une nécessité de calcul, seulement un confort de lecture à faible
niveau, préservé côté bas de plage (10 à 50 au niveau 1) mais pas au-delà.

## `levels` optionnel dans `CompositeExerciseGenerator`, repli niveau 50 (étape 4, commit C)

Le commit C rend les générateurs paramétrables par niveau, mais le câblage des niveaux réels
depuis l'historique est explicitement le travail du commit D (`SessionConfig` n'a pas encore de
champ niveaux, `buildSessionController` garde sa signature actuelle). Rendre `levels` obligatoire
aurait cassé la compilation de `composition_root.dart` avant que ce câblage existe.

`levels: Map<ExerciseType, int>?` est donc optionnel ; tout type activé absent de la carte
utilise un repli niveau 50. `composition_root.dart` continue de fonctionner sans modification, à
l'identique de son comportement actuel (les anciennes constantes internes des générateurs
correspondaient globalement à un niveau médian). Le commit D remplacera ce repli par les vrais
niveaux lus depuis la persistance.

## `AnswerOutcome`, pas `AnswerResult` ni `PersistedAnswer` (étape 4)

`LevelUpdater` a besoin de `isCorrect` et `elapsedMs`, rien d'autre. Réutiliser `AnswerResult`
aurait couplé le calcul du niveau au gameplay live (l'`Exercise` complet, la valeur soumise) ;
réutiliser `PersistedAnswer` l'aurait couplé à la persistance (id, timestamps, hors sujet pour
la formule). `AnswerOutcome` est un type dédié, minimal ; les deux autres s'y convertissent
trivialement. Coût nul aujourd'hui, découplage réel entre trois couches qui n'ont pas besoin de
se connaître.

## `LevelingRules` non-const dès l'écriture (étape 4)

Contrairement à `OperandRange` (const à l'origine, corrigé au commit A de cette étape),
`LevelingRules` est non-const et lève directement dans son constructeur
(`tRapideMs >= tLentMs`). La règle 13 est déjà actée au moment d'écrire ce fichier : autant
l'appliquer dès le départ que créer un cinquième cas à corriger plus tard.

## `assert` ne défend pas un invariant — utiliser `throw` (règle 13)

Le piège a resurgi trois fois : division par zéro (étape 1), timestamps non-UTC (étape 2), puis
`OperandRange` et `CompositeExerciseGenerator` (étape 3). Même cause à chaque fois : une
précondition gardée par `assert()`, donc supprimée du build release — l'invariant n'existe plus
exactement là où il compte.

Les deux dernières occurrences étaient moins graves (en release, un `Set` vide ou `min > max`
plante `Random.nextInt()` avec un `RangeError` au lieu de corrompre un résultat) mais relevaient
du même anti-pattern, et aucun test n'exerçait le cas invalide.

Corrigées à l'étape 4, parce que c'est elle qui les rend atteignables : tant que les bornes
étaient des constantes écrites à la main, `OperandRange` était valide par construction. Dès
qu'elles sont calculées à partir d'un niveau, un cas invalide devient réel.

Promu en règle 13 plutôt que corrigé une troisième fois au cas par cas.

## Cache `player_levels` et orchestration `LevelUpdater` (étape 4, commit D)

Trois lectures possibles pour retrouver le niveau de départ de la session suivante ont été
envisagées : rejouer l'historique complet à chaque démarrage, différer tout câblage à un commit
séparé, ou une petite table de cache mise à jour en fin de session. Retenue : la table de cache
(`player_levels`), pour coller au vocabulaire « cache » déjà utilisé plus bas dans ce document et
éviter de rejouer l'historique à chaque lancement.

**Écart assumé à la règle 5** (UUID, jamais d'identifiant naturel sur une entité synchronisable) :
`player_levels` utilise une clé composite `(player_id, exercise_type)`. Justifié par la raison
d'être de la règle elle-même — protéger l'identité d'une entité synchronisable — alors que cette
table est un cache **recalculable**, sans identité propre à préserver ; la source de vérité reste
les réponses individuelles dans `answers`.

**Orchestration** (`SessionController._computeLevelUpdates`, appelée en fin de session) : les
réponses sont groupées par `ExerciseType`, les groupes sous `n_min` ignorés (bruit, cache non
touché), `LevelUpdater.update()` appelé avec le niveau qui a *réellement servi* à générer la
session (`config.levels`, jamais relu depuis le cache à cet instant — le cache aurait pu changer
entre-temps dans un futur multi-appareils), le résultat écrit dans `player_levels` **dans la même
transaction** que `recordSession` : un niveau mis à jour sans que la session existe (ou l'inverse)
ne doit pas arriver.

**Seuil de « longue absence »** : `boostRetour` avait une valeur (×2) mais aucun seuil numérique
déclenchant `returning` — même trou que `t_rapide`/`t_lent`. Tranché à **30 jours** sans réponse
sur l'opération précise, nouveau paramètre `LevelingRules.absenceDaysThreshold` (non calibré,
ajustable sans ripple). Le décompte des sessions et de l'absence n'appartient pas à
`LevelingRules`/`LevelUpdater` (ce module le dit déjà explicitement) : nouvelle fonction pure
`confidenceFor()` dans `leveling/`, qui prend l'état de cache actuel (ou `null` si l'opération n'a
jamais été jouée) et l'horloge, et rend le `ConfidenceMultiplier` à appliquer.

**`buildSessionController` sans 3ᵉ paramètre explicite** : anticipé comme « au troisième
paramètre, préférer un objet de configuration » avant que le mécanisme de lecture du cache soit
choisi. Avec le cache lu en interne par `buildSessionController` (asynchrone, règle 4), il n'y a
plus de 3ᵉ paramètre à faire transmettre par l'appelant — `enabledTypes` reste le seul réglage
fourni par `HomeScreen`, les niveaux sont dérivés de la persistance, jamais passés en argument.

## Les niveaux sont un cache recalculable, pas une source de vérité

Ce qui est stocké peut être reconstruit intégralement à partir de l'historique des réponses.
Deux conséquences. Le serveur pourra recalculer le niveau lui-même au lieu de croire le client —
sans quoi n'importe qui annonce 700 au classement général. Et la fonction de mise à jour du
niveau appartient au domaine pur, comme le `Scorer`, avec une signature qui accepte une liste de
réponses : c'est ce qui rendra la recalibration des paramètres possible sur données réelles.

Ce qui est stocké **avec chaque session**, en revanche, ce sont les niveaux figés au moment du
jeu — pas la « difficulté ». C'est le couple (seed, niveaux) qui permet au serveur de régénérer
la séquence pour revalider un duel. Les niveaux étant par opération, un JSON par session plutôt
qu'un scalaire. Première vraie migration de schéma du projet : `schemaVersion` → 2, `onUpgrade`
enfin non vide.

## La difficulté n'est pas un réglage utilisateur

Options écartées : un sélecteur global facile/moyen/difficile, ou un réglage indépendant par
type. Les deux contredisent la sémantique du niveau — si le joueur choisit sa difficulté, le
niveau ne mesure plus sa compétence et le classement général perd son sens. Il n'y a donc aucun
contrôle de difficulté dans l'UI.

## Formule de pondération du score par la difficulté (étape 4, commit E)

Proposée avant implémentation, comme demandé (« choix produit, ne pas implémenter d'office »),
validée ensuite. Multiplicative plutôt qu'additive : compose proprement avec le barème existant
(base + bonus vitesse + bonus streak) sans dupliquer sa logique, et un même écart de niveau a un
effet relatif comparable quel que soit le score de base d'une réponse.

```
multiplier = 1 + (level - 1) / 99 * difficultyBonusMax
points_finaux = (points_bruts * multiplier).round()
```

`difficultyBonusMax = 1,0` — niveau 100 rapporte le double des points du niveau 1. **Non
calibré**, comme les autres constantes du système de niveaux ; vit dans `ScoringRules`, à côté
des autres réglages de barème plutôt que dans une classe séparée, puisque c'est un paramètre de
scoring qui *consomme* un niveau, pas un paramètre du calcul de niveau lui-même.

`level` est le niveau **figé** de l'opération pour la session (`SessionConfig.levels`), jamais
relu depuis le cache — la difficulté qui a réellement produit la question, cohérent avec le
même principe déjà appliqué à `LevelUpdater` et à la génération d'exercices.

## Le score reste un retour de session, le niveau reste l'unité de classement

Pondérer les points par difficulté est légitime : sans cela, progresser ne change rien au
ressenti, ce qui démotive. Mais le score ne classe jamais — c'est le niveau qui classe. Deux
chiffres qui racontent la même chose laissent le joueur sans savoir lequel regarder.

## Pas de `List<int> operands` générique sur `Exercise`

Envisagé pour absorber les variantes unaires (racine) et de futurs types exotiques.
Abandonné : la règle 9 ferme la porte aux types exotiques, donc le gain serait nul, tandis
que le coût serait de retoucher du code stable et de perdre le nommage métier des opérandes.
`operands_json` couvre déjà le besoin côté stockage.

## Fractions et divisions euclidiennes écartées du jeu

Décision produit, définitive. Toutes deux violent la règle 9 : les fractions par leur type de
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

## Vérification Android : `build apk` + `adb`, pas `flutter run`

`flutter run` resté attaché s'est déconnecté cinq à six fois au fil des étapes, sans raison
apparente. La séquence fiable est `flutter build apk --debug`, puis `adb install -r` et
`adb shell am start`. Purement environnemental, comme `kotlin.incremental=false`.

## Tirage RNG inutile dans `CompositeExerciseGenerator`

Réutiliser `ArithmeticExerciseGenerator` avec une liste à un seul élément fait quand même
appeler `random.nextInt(1)` (toujours 0). Déterministe et sans conséquence fonctionnelle, mais
c'est le signe que le générateur arithmétique n'expose pas de point d'entrée « une seule
opération, pas de tirage ».

Laissé en l'état volontairement : **le supprimer changerait toutes les séquences pour une seed
donnée.** Si c'est corrigé un jour, ce doit être dans un commit isolé, avec les références de
test de déterminisme régénérées dans le même commit.

## `kotlin.incremental=false`

Contourne un bug Windows : le compilateur Kotlin plante quand le projet et les caches Gradle
sont sur des lettres de lecteur différentes (D: vs C:). Purement environnemental.
**À revérifier** sur machine propre ou en CI avant le premier `flutter build appbundle`.
