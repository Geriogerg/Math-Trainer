# Math Trainer

Application mobile Flutter de calcul mental compétitif (adolescents et adultes).
Expérience ludique, rapide, orientée compétition.

**État : MVP fonctionnel, validé sur Android et web.**

## Interlocuteur

Développeur expérimenté : Python, Java, C/C++, algorithmique, ML/DL.
Solide en architecture logicielle et en conception de systèmes.

Peu familier avec : Dart, Flutter, le développement mobile, les conventions iOS/Android,
la publication sur les stores.

**Conséquence sur tes réponses :** ne pas expliquer les concepts généraux (patterns,
tests, complexité, immutabilité, injection de dépendances). Expliquer en revanche les
idiomes Dart/Flutter non évidents : `late`, `factory`, `sealed class`, cycle de vie des
widgets, `BuildContext`, `const`/`final`, `Key`, `async`/`Future`/`Stream`.

Explique un idiome à sa première apparition, pas ensuite.

## Stack

- Flutter / Dart — cibles Android et iOS (web utilisé uniquement pour itérer)
- Git
- Tests automatisés sur toute la logique métier
- **Pas de backend actuellement**

Développement sous Windows. Le build iOS n'est pas réalisable localement (nécessitera
macOS ou un CI cloud). Ne propose pas de solution exigeant Xcode en local.

<!-- À COMPLÉTER : gestion d'état retenue, et pourquoi -->

## Structure du projet

<!-- À COMPLÉTER : arborescence réelle après le MVP, avec le rôle de chaque dossier.
     Demander à Claude Code de la générer, puis la relire. -->

## Contraintes d'architecture

Non négociables sans discussion explicite.

### 1. Le cœur métier est du Dart pur

Génération d'exercices, scoring, modèles de domaine : **aucun import de
`package:flutter`**. Testables via `dart test` sans binding Flutter.

Raison : rapidité des tests, et surtout réutilisabilité côté serveur. Quand le
multijoueur arrivera, le serveur devra revalider les réponses en régénérant les
questions — il exécutera ce même code.

### 2. Le générateur d'exercices est déterministe

Toute génération part d'une **seed explicite**. Aucun `Random()` non seedé dans le code
métier. Un test doit vérifier que même seed → même séquence.

Raison : le mode duel exige que deux joueurs reçoivent la même séquence, et que le
serveur puisse la reconstituer pour validation.

### 3. Persistance derrière une abstraction

Le code métier ne connaît **jamais** l'implémentation du stockage. Il parle à des
interfaces de repository. Aucun import de `shared_preferences`, `sqflite` ou `drift`
en dehors de la couche d'infrastructure.

Raison : permettre le passage à une implémentation synchronisée avec un backend sans
toucher au domaine.

### 4. Toutes les méthodes de repository sont asynchrones

Signatures en `Future<T>` même quand l'implémentation locale est synchrone.

Raison : le jour où le réseau entre en jeu, toute la chaîne d'appel serait à réécrire
autrement.

### 5. Identifiants globalement uniques

UUID pour le joueur, les sessions et les réponses. **Jamais d'`AUTOINCREMENT`** sur
une entité destinée à être synchronisée.

Raison : deux appareils générant `id = 1` créent un conflit insoluble à la première
synchronisation.

### 6. Timestamps en UTC

Toutes les dates stockées en UTC, converties en local uniquement à l'affichage.
Distinguer explicitement `createdAt` et `syncedAt`.

Raison : les séries quotidiennes et les classements deviennent incohérents pour un
joueur qui change de fuseau.

### 7. Séparation stricte des couches

Ne jamais mélanger dans un même fichier : UI, logique métier, génération, scoring,
modèles, gestion d'état, services. Pas de logique métier dans un widget.

### 8. Modèles immuables

`final` et `copyWith`. Pas de mutation en place sur les objets de domaine.

## Stratégie de données

**Aujourd'hui — tout est local.**

- `shared_preferences` : préférences et scalaires simples (paramètres, dernier profil).
- SQLite : historique des sessions et **des réponses individuelles**.

**Granularité obligatoire :** stocker chaque réponse (type d'exercice, opérandes,
réponse donnée, temps de réponse, correct/incorrect), pas seulement des agrégats.
Le futur moteur adaptatif doit pouvoir détecter une lenteur sur les tables de 7/8/9 ou
sur les fractions. Un agrégat ne se décompose pas rétroactivement.

**Plus tard — modèle offline-first.**

- Local : source de vérité pour l'entraînement solo, cache du reste. L'app reste
  jouable hors ligne.
- Serveur : autorité **exclusive** sur tout ce qui est compétitif (Elo, classement,
  résultats de duels). Le client ne calcule jamais un Elo et ne s'auto-attribue jamais
  un résultat de duel.

Backend non tranché. Supabase est le candidat privilégié (Postgres, donc agrégations
natives pour le ladder). Ne pas introduire de dépendance qui fermerait cette option.

## Périmètre actuel

Le MVP est terminé. Les étapes suivantes, dans l'ordre :

1. Consolidation des tests du cœur métier (déterminisme, scoring, validation)
2. Persistance locale : repository abstrait, SQLite, historique granulaire
3. Élargissement des types d'exercices
4. Difficulté paramétrable
5. Polish UI et feedback

**N'implémente rien au-delà de l'étape en cours sans demande explicite.**

## Fonctionnalités futures (anticiper, ne pas implémenter)

Comptes, backend, multijoueur, duels, classement, Elo, ligues, saisons, tournois,
défis quotidiens, XP, niveaux, séries, badges, moteur adaptatif, abonnement, analytics.

Anticiper = ne pas fermer la porte. Cela ne signifie **pas** construire l'abstraction
maintenant. Pas d'interface pour un seul cas d'usage.

## Règles de collaboration

- **Proposer avant d'implémenter.** Décrire l'approche et attendre validation pour
  toute tâche non triviale. Utiliser le mode Plan.
- **Aucune décision architecturale majeure sans expliquer ses conséquences**, y compris
  sur les fonctionnalités futures.
- **Ne pas réécrire de code qui fonctionne.** Modifications minimales et ciblées.
- **Lister les fichiers modifiés** avec une justification brève.
- **En cas d'ambiguïté**, proposer une solution raisonnable et expliciter le choix.
- **Simplicité avant sur-ingénierie.**
- **Une étape à la fois**, livrable et testable, suivie d'un commit.

## Conventions de code

- `flutter_lints` respecté ; `dart analyze` sans avertissement.
- Fichiers en `snake_case`, types en `UpperCamelCase`, membres en `lowerCamelCase`.
- Toute logique métier ajoutée est accompagnée de ses tests unitaires.
- Commenter uniquement ce qui n'est pas évident — pas de paraphrase du code.
- Pas de valeur codée en dur dans l'UI : `Theme.of(context)`.
- `SafeArea` sur tous les écrans (notch, Dynamic Island).
- Champs de saisie numérique : `TextInputType.number`, et vérifier que le clavier natif
  ne masque pas le champ ni le chrono.

## Validation avant commit

1. `dart test` puis `flutter test` au vert
2. `flutter analyze` sans avertissement
3. Vérification sur Android réel ou émulateur — pas uniquement sur web

## Commandes

```bash
dart test                  # tests du cœur métier (rapide)
flutter test               # tests incluant les widgets
flutter analyze            # analyse statique
flutter run -d edge        # itération rapide
flutter run                # device Android
```

## Dépendances

N'ajouter une dépendance que si elle est réellement nécessaire, et le justifier.
Privilégier la bibliothèque standard Dart quand elle suffit.

<!-- À COMPLÉTER : liste des dépendances actuelles avec la raison de chacune -->
