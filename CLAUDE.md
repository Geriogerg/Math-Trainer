# Math Trainer

Application mobile Flutter de calcul mental compétitif, destinée aux adolescents et adultes.
Expérience ludique, rapide, orientée compétition.

## Interlocuteur

Développeur expérimenté : Python, Java, C/C++, algorithmique, ML/DL.
Solide en architecture logicielle et en conception de systèmes.

Peu familier avec : Dart, Flutter, le développement mobile, la conception d'UI mobile,
les conventions iOS/Android, la publication sur les stores.

**Conséquence directe sur tes réponses :** ne pas expliquer les concepts généraux
(patterns, tests, complexité, immutabilité, injection de dépendances). Expliquer en
revanche les idiomes Dart/Flutter non évidents : `late`, `factory`, `sealed class`,
cycle de vie des widgets, `BuildContext`, différence `const`/`final`, gestion des
`Key`, conventions de nommage Dart.

Quand tu introduis un idiome Flutter pour la première fois, ajoute une ligne
d'explication. Ne le refais pas ensuite.

## Stack

- Flutter / Dart
- Cibles : Android et iOS
- Git
- Tests automatisés sur toute la logique métier
- **Pas de backend** tant que le MVP ne l'exige pas

Environnement de développement : Windows. Le build iOS n'est pas réalisable localement
(il exigera macOS ou un CI cloud). Ne propose pas de solution nécessitant Xcode en local.

## Contraintes d'architecture

Ces contraintes ne sont pas négociables sans discussion explicite.

### 1. Le cœur métier est du Dart pur

La génération d'exercices, le scoring et les modèles de données ne doivent contenir
**aucun import de `package:flutter`**. Ils doivent être testables via `dart test`,
sans binding Flutter ni widget tester.

Raison : rapidité des tests, et réutilisabilité côté serveur quand le multijoueur
arrivera.

### 2. Le générateur d'exercices est déterministe

Toute génération part d'une **seed explicite**. Aucun `Random()` non seedé dans le
code métier.

Raison : le mode duel exige que deux joueurs distincts reçoivent exactement la même
séquence de questions. Si cette contrainte est violée, la fonctionnalité devra être
réécrite entièrement.

### 3. Séparation stricte des couches

Ne jamais mélanger dans un même fichier : UI, logique métier, génération d'exercices,
scoring, modèles, gestion d'état, services.

Pas de fichier monolithique. Pas de logique métier dans un widget.

### 4. Modèles immuables

Les modèles de données sont immuables (`final`, `copyWith`). Pas de mutation en place
sur les objets de domaine.

## Périmètre du MVP

Le MVP actuel se limite strictement à :

1. Lancer une session
2. Afficher une question
3. Saisir une réponse
4. Vérifier la réponse
5. Afficher le résultat
6. Calculer un score
7. Afficher les statistiques de session
8. Recommencer

**N'implémente rien au-delà de ce périmètre sans demande explicite.**

## Fonctionnalités futures (à anticiper, pas à implémenter)

L'architecture doit permettre d'ajouter sans réécriture :

- comptes utilisateurs, backend (Firebase / Supabase / custom — non tranché)
- multijoueur, duels, classement, Elo, ligues, saisons, tournois, défis quotidiens
- XP, niveaux, séries, badges, historique de performance
- moteur adaptatif : détection des faiblesses par type d'opération
  (ex. lenteur sur les divisions, les fractions, les tables de 7/8/9) et
  génération d'exercices ciblés
- abonnement, analytics

Anticiper signifie : ne pas fermer la porte. Cela ne signifie pas construire
l'abstraction maintenant.

## Règles de collaboration

- **Proposer avant d'implémenter.** Pour toute tâche non triviale, décrire l'approche
  et attendre validation. Utiliser le mode Plan.
- **Aucune décision architecturale majeure sans explication préalable** de ses
  conséquences, y compris sur les fonctionnalités futures listées ci-dessus.
- **Ne pas réécrire de code qui fonctionne.** Modifications minimales et ciblées.
- **Lister les fichiers modifiés** à chaque changement, avec une justification brève.
- **En cas d'ambiguïté**, proposer une solution raisonnable et expliciter le choix
  plutôt que de demander des précisions sur des détails mineurs.
- **Simplicité avant sur-ingénierie.** Un MVP fonctionnel prime sur une architecture
  élégante mais spéculative. Ne pas introduire d'abstraction pour un seul cas d'usage.

## Conventions de code

- Respecter `flutter_lints` ; le code doit passer `dart analyze` sans avertissement.
- Nommage : `snake_case` pour les fichiers, `UpperCamelCase` pour les types,
  `lowerCamelCase` pour les membres.
- Toute logique métier ajoutée est accompagnée de ses tests unitaires.
- Documenter uniquement ce qui n'est pas évident à la lecture — pas de commentaire
  paraphrasant le code.
- Pas de valeur codée en dur dans l'UI : passer par `Theme.of(context)`.
- Envelopper les écrans dans `SafeArea` (notch et Dynamic Island iOS).

## Commandes utiles

```bash
dart test                  # tests du cœur métier (rapide)
flutter test               # tests incluant les widgets
flutter analyze            # analyse statique
flutter run -d edge        # exécution web, itération rapide sans émulateur
flutter run                # exécution sur device Android connecté
```

## Minimalisme des dépendances

N'ajouter une dépendance que si elle est réellement nécessaire, et le justifier.
Privilégier la bibliothèque standard Dart quand elle suffit.
