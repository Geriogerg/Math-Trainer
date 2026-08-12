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
| `t_rapide` | 2000 ms | en deçà, vitesse = 1 |
| `t_lent` | 8000 ms | au-delà, vitesse = 0 |
| `absence_days_threshold` | 30 jours | déclenche `boost_retour` |

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

## Direction visuelle : « nuit électrique »

Quatre directions comparées (ardoise sobre, papier clair, nuit électrique, terrain chaleureux).
Retenue : nuit électrique — registre compétitif cohérent avec la trajectoire du produit
(classement, Elo, duels), là où « ardoise » aurait mieux servi un outil d'entraînement.

Conséquence directe : l'accent étant vert d'eau, le vert ne peut plus signaler la bonne réponse.
Le feedback positif passe par un flash blanc — ce qui règle au passage l'accessibilité, puisque
la couleur seule n'a jamais été un signal fiable. Promu en règle 14.

Palette, typographie et durées d'animation : `doc/design.md`.

## Palette sombre assombrie après relecture au téléphone (étape 5, commits A-E)

Les hex d'origine (`Fond #101528`, `Accent #5DCAA5`) rendaient un bleu-nuit clair et un accent
pastel une fois sur l'écran réel — pas assez « nuit électrique », trop proche d'un simple thème
sombre générique. Assombri (`Fond #0A0E1C`, `Surface #151A30`, `Bordure #232A47`) et l'accent
resaturé (`#2ED9A0`, plus vif) pour se rapprocher de la référence visuelle initiale. Mode clair
non touché : le retour ne portait que sur le sombre. `onPrimary` reste sombre sur l'accent (choix
déjà pris au commit A, toujours valable avec le nouvel accent).

## Police Inter en asset local, pas `google_fonts`

`google_fonts` télécharge la police au premier lancement par défaut — contraire à l'esprit
offline-first (règle de stratégie de données), et il faudrait de toute façon la configurer en
mode bundlé pour l'éviter. Un asset `.ttf` local (licence SIL OFL, librement redistribuable)
n'ajoute aucune dépendance et reste cohérent avec le minimalisme déjà pratiqué ailleurs
(pas de `uuid`, pas de `provider`).

Un seul fichier suffit : la police récupérée (dépôt officiel `google/fonts`) est une police
variable couvrant tout l'axe `wght`, pas des fichiers statiques par graisse. `TextStyle.
fontWeight` pilote directement cet axe.

Pas de fichier « Roboto Flex » distinct pour le repli de `doc/design.md` : une fois Inter
bundlée elle est toujours disponible, ce scénario ne se déclenche donc jamais en pratique.
« Roboto Flex » n'est de toute façon pas garantie préinstallée sur Android — seule la police
`Roboto` (non `Flex`) l'est, et c'est elle que Flutter utiliserait par défaut si le chargement
d'un asset bundlé venait à échouer.

## Onglets « En ligne » et « Classement » : chrome posé, contenu en attente

La barre à quatre entrées (`doc/design.md`) inclut deux onglets dont la fonctionnalité est
explicitement hors périmètre étape 5 (comptes, réseau, classement). Construire les quatre
onglets maintenant avec un écran « bientôt disponible » derrière les deux non implémentés,
plutôt qu'une barre à deux entrées qui grossirait plus tard : c'est la structure de navigation
qui est fixée par le design, pas le contenu de chaque onglet. Cohérent avec « anticiper = ne pas
fermer la porte, pas d'abstraction pour un seul cas d'usage » — c'est du chrome, pas une
abstraction métier anticipée.

## `Exercise.prompt` quitte le domaine

Les exposants doivent s'afficher en position haute, ce qu'une `String` plate ne permet pas (les
caractères Unicode `²`/`³` s'arrêtent vite et rendent mal selon les polices). L'affichage se
compose donc dans la couche présentation à partir des champs de chaque variante.

Effet de bord bienvenu : la dette du texte français en dur dans `core/domain/`, documentée
depuis l'étape 3, disparaît. Le domaine redevient purement mathématique.

## Pas de résultat négatif en soustraction

Le générateur garantit `operandA ≥ operandB`. Motif : les réponses négatives sont une source
d'erreurs de saisie sans intérêt pédagogique à ce stade, et leur absence permet de supprimer la
touche `−` du pavé numérique. Décision produit — si elle change, le pavé change aussi.

## Pavé numérique intégré plutôt que clavier natif

Le clavier système masque le champ et le chrono (piège documenté depuis le début), impose une
animation d'apparition et propose des touches parasites. Un pavé dessiné donne une hauteur fixe,
donc aucun décalage de mise en page entre deux questions, et supprime plusieurs dizaines de
millisecondes par réponse.

## Barre d'onglets basse plutôt que tiroir latéral

Un tiroir demande deux gestes, cache la navigation, et force le pouce vers le coin haut-gauche.
La barre basse reste visible et accueillera les pastilles de notification des duels.
L'écran de session, lui, ne porte aucune navigation : plein écran, pour la place et pour éviter
qu'on quitte une partie en visant un onglet.

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
`INTEGER` ; la saisie se fait via le pavé numérique intégré depuis l'étape 5 (commit D), un seul
champ, jamais de virgule ni de second champ.

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
