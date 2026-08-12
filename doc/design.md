# Design — Math Trainer

Direction visuelle et règles d'interface. **Non chargé automatiquement** — lis-le avant tout
travail sur `presentation/` ou sur le thème.

Principe directeur : le jeu se vend sur la vitesse. Tout ce qui ralentit la lecture, déplace un
élément ou demande un geste supplémentaire est un défaut, pas un détail. La sobriété n'est pas
une esthétique ici, c'est une contrainte fonctionnelle — l'opération doit être la seule chose
que l'œil accroche.

## Direction retenue : « nuit électrique »

Registre compétitif assumé, cohérent avec la trajectoire du produit (classement, Elo, duels).

### Palette — mode sombre (défaut)

| Rôle | Hex | Usage |
|---|---|---|
| Fond | `#101528` | canvas de tous les écrans |
| Surface | `#1B2340` | cartes, touches du pavé, champs |
| Bordure | `#2A3352` | séparateurs, piste du chrono |
| Accent | `#5DCAA5` | action principale, chrono, saisie active, onglet actif |
| Texte primaire | `#E6F1FB` | opération, chiffres, titres |
| Texte secondaire | `#85B7EB` | libellés, métadonnées |
| Texte discret | `#5A6B8C` | onglets inactifs, indications |

### Palette — mode clair (obligatoire, pas optionnel)

Un jeu mobile se joue autant dehors qu'au lit. Le mode clair n'est pas une variante de confort.

| Rôle | Hex |
|---|---|
| Fond | `#F4F6FB` |
| Surface | `#FFFFFF` |
| Bordure | `#D6DEEC` |
| Accent | `#0F6E56` |
| Texte primaire | `#101528` |
| Texte secondaire | `#3E5170` |
| Texte discret | `#7A8AA6` |

### Feedback juste / faux

L'accent étant vert d'eau, **le vert ne peut pas signaler la bonne réponse** — il serait
confondu avec la couleur d'action. Et de toute façon :

**Le feedback ne repose jamais sur la couleur seule.** Trois canaux simultanés, ~120 ms :

- **Juste** — flash blanc bref sur le champ de saisie, légère mise à l'échelle (1,0 → 1,06 → 1,0),
  vibration très courte.
- **Faux** — flash `#E24B4A`, secousse horizontale de faible amplitude, vibration plus longue.

Aucun écran intermédiaire, aucun bouton « suivant », aucune pause au-delà de 150 ms. La question
suivante arrive pendant que le flash s'éteint.

## Typographie

`Inter` (ou `Roboto Flex` en repli). Deux graisses seulement : 400 pour le texte courant,
500 pour les chiffres et les titres. Jamais 600 ou 700.

**Chiffres tabulaires partout** (`FontFeature.tabularFigures()`). Sans cela, la réponse en cours
de saisie se décale à chaque touche et l'œil décroche.

| Élément | Taille |
|---|---|
| Opération | 48 sp, poids 500 |
| Réponse saisie | 32 sp, poids 500 |
| Titres d'écran | 17 sp, poids 500 |
| Libellés | 13 sp, poids 400 |
| Métadonnées | 11 sp, poids 400 |

## Notation mathématique

Ces caractères sont non négociables — le trait d'union et l'accent circonflexe sont interdits.

| Type | Rendu |
|---|---|
| Addition | `47 + 68` |
| Soustraction | `92 − 35` — vrai signe moins U+2212, jamais `-` |
| Multiplication | `24 × 7` — U+00D7, jamais `x` |
| Division | `96 ÷ 8` — U+00F7, jamais `/` |
| Puissance | base pleine taille, exposant en position haute, ~55 % de la taille, jamais `^` |
| Racine | `√` avec **barre horizontale au-dessus du radicande** — sans elle, `√169` se lit `√1` puis `69` |
| Pourcentage | `25% de 80` — le mot est conservé |

L'exposant se rend avec `Text.rich` : un `TextSpan` pour la base, un span décalé vers le haut et
réduit pour l'exposant. La barre de la racine est un simple `Border(top:)` sur le radicande.

### Conséquence sur le domaine

`Exercise.prompt` renvoyant une `String` **doit disparaître**. Un exposant en position haute
n'est pas représentable dans une chaîne plate, et les caractères Unicode `²`/`³` s'arrêtent trop
vite et rendent mal selon les polices.

L'affichage se compose dans la couche présentation à partir des champs de chaque variante
(`base`/`exponent`, `percent`/`base`, etc.). Bénéfice : ça résout la dette documentée du texte
français en dur dans `core/domain/`. Le domaine redevient purement mathématique ; le mot « de »
des pourcentages vit dans la présentation, seul élément traduisible de l'ensemble.

## Écran de session

Aucune navigation. Plein écran par-dessus la barre d'onglets — ça libère la place pour une
opération vraiment grande et évite qu'on quitte une partie en visant un onglet.

De haut en bas : compteur de progression et **chrono en barre** (jamais en chiffres — on ne lit
pas un chrono en calculant, on le perçoit ; et la barre représente le temps de **la question**,
pas de la session), type et niveau en discret, l'opération centrée, la réponse en cours sous
elle, puis le pavé.

## Pavé numérique intégré

**Toujours visible, jamais le clavier natif.** Le clavier système masque le champ et le chrono
(piège documenté), impose une animation d'apparition, et propose des touches parasites.

Conséquence de disposition à respecter : **dimensionner l'écran à l'envers** — hauteur du pavé
fixée d'abord, l'opération occupe ce qui reste. Rien ne bouge alors entre deux questions, et
l'œil reste ancré au même endroit toute la session.

Disposition : 1–9 sur trois rangées, puis rangée basse `retour arrière` / `0` / `valider`.

- **Validation à droite** : côté du pouce pour la majorité, et c'est le geste le plus fréquent
  de la session — il doit être le plus rapide.
- **Effacement à gauche** : plus rare, donc plus loin.
- **Pas de touche `−`.** Décision produit associée : la soustraction ne produit jamais de
  résultat négatif (`operandA ≥ operandB`). Les réponses négatives sont une source d'erreurs de
  saisie sans intérêt pédagogique à ce stade. Si cette décision change un jour, le pavé change
  aussi.

## Navigation

**Barre d'onglets en bas**, quatre entrées : Jouer, En ligne, Progression, Classement.

Pas de tiroir latéral : deux gestes au lieu d'un, navigation cachée, et sur un grand téléphone
il force le pouce vers le coin haut-gauche, le point le moins accessible. La barre basse reste
visible, atteignable, et accueillera les pastilles de notification quand les duels arriveront.

Profil et réglages : icône dans un coin de l'écran d'accueil, pas un cinquième onglet.

## Animation

Tempérament nerveux mais sans fantaisie. Aucun rebond, aucun `elasticOut`, aucune transition
décorative.

| Élément | Durée | Courbe |
|---|---|---|
| Feedback réponse | 120 ms | `easeOut` |
| Enfoncement d'une touche | 60 ms | `easeOut` |
| Transition entre questions | ≤ 150 ms | `easeOut` |
| Changement d'onglet | ≤ 200 ms | `easeInOut` |
| Montée de niveau (écran progression) | 600 ms | `easeOutCubic` |

La montée de niveau est la seule animation qui a le droit de prendre son temps : c'est le moment
émotionnel du solo, le seul endroit où le joueur regarde au lieu de réagir.

## Écran de résultat

C'est la conclusion de la session et le moment où le système de niveaux devient perceptible.
Aujourd'hui il n'affiche ni le changement de niveau, ni la série, ni la composition du score.

De haut en bas : **le changement de niveau en premier** (animation `AppMotion.levelUp`, 600 ms,
la seule qui a le droit de prendre son temps), le score avec sa décomposition (base, bonus de
vitesse, bonus de série, multiplicateur de difficulté), le décompte juste / faux / **hors délai
distingués**, le temps moyen, la meilleure série, et les types joués.

Le taux de réussite s'affiche en décompte brut (« 9/12 »), jamais en courbe ni en pourcentage
présenté comme un progrès.

Deux actions : **Rejouer** (dominante, à droite) et **Nouvelle sélection**. Envisager de porter
les puces de types directement sur cet écran — changer un seul type coûte aujourd'hui 3 taps.

## Écran de progression

Quatre blocs, du général au détail : niveau global avec sa variation récente ; courbe d'évolution
du niveau sur 30 jours ; ventilation par opération (barre de niveau + **temps moyen**, qui dit au
joueur où il est lent) ; sessions récentes avec score et variation de niveau.

Les opérations jamais jouées apparaissent en état « non joué » plutôt que masquées — c'est ce qui
rend visible ce que la sélection par défaut laisse de côté.

## Règles de disposition

- **Padding racine uniforme sur tous les écrans.** Trois valeurs différentes coexistent
  aujourd'hui (`all(24)`, `fromLTRB(24,16,24,8)`, aucune).
- **Un seul style de titre d'écran.** `headlineMedium` et `headlineSmall` coexistent.
- **Tout `Text` cite un style de thème explicite.** Aucun style hérité par défaut.
- **Hauteur du pavé en valeur fixe, jamais en ratio d'écran.** `0.38 * height` fait bouger la
  mise en page d'un appareil à l'autre et contredit le principe de dimensionnement à l'envers.
- **Un message d'erreur ne contient pas l'action.** Le texte décrit le problème, le bouton porte
  l'action — une seule formulation partout, pas « Réessayez » tantôt dans le texte tantôt dans le
  bouton.
- **Un état désactivé explique pourquoi.** Un bouton grisé sans message (sélection de types vide)
  laisse le joueur sans issue lisible.

## Règles d'implémentation

- **Aucune couleur, taille ou durée en dur dans un widget.** Tout passe par `ThemeData` et des
  extensions de thème, consommées via `Theme.of(context)`.
- `SafeArea` sur tous les écrans.
- Les deux modes (clair et sombre) doivent être testés — un écran qui n'existe qu'en sombre est
  un écran non terminé.
- **Tests de golden** sur l'écran de session, l'écran de résultat et l'écran de progression,
  dans les deux modes. C'est le seul filet contre les régressions visuelles.
- **Aucune couleur Flutter littérale.** `Colors.black` en repli dans `exercise_prompt.dart`
  produit une barre de racine invisible en mode sombre — le repli doit venir du thème.
- **Aucun `SizedBox.shrink()` comme état d'écran.** Un écran vide est une impasse : message et
  action de sortie obligatoires.
- **Libellés centralisés**, sur le modèle de `exercise_type_labels.dart`. Pas urgent, mais chaque
  chaîne littérale ajoutée dans un widget est une ligne de plus à reprendre à l'internationalisation.
