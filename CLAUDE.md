Voici un prompt complet, structuré et suffisamment précis pour être donné directement à Claude.

---

# PROMPT

## CONTEXTE

Je souhaite refondre entièrement la gestion des exercices comptables de mon application Flutter Desktop afin d'adopter une logique métier similaire à celle des logiciels comptables professionnels (type Sage 100), sans reproduire leur interface.

Les pages concernées sont principalement :

* `nouvel_exercice_page.dart`
* `liste_exercices_page.dart`

Cette refonte doit concerner à la fois :

* la logique métier,
* les interfaces utilisateur,
* les traitements de clôture,
* les traitements de création d'exercice,
* ainsi que tous les services, modèles, providers et fichiers nécessaires.

Avant toute modification, réalise un audit complet du fonctionnement actuel afin d'identifier toutes les dépendances impactées.

---

# OBJECTIF PRINCIPAL

La logique actuelle doit être remplacée par une logique basée sur le **Journal des A-Nouveaux (AN)**.

À partir de cette refonte :

* le journal AN sera généré automatiquement lors de la clôture d'un exercice ;
* ce journal deviendra l'unique source utilisée pour créer les comptes d'ouverture de l'exercice suivant ;
* il ne devra plus y avoir de recalcul des soldes lors de la création d'un nouvel exercice.

Le flux devra être :

```
Création exercice
        ↓
Saisies comptables
        ↓
Clôture
        ↓
Création automatique du journal AN
        ↓
Création de l'exercice suivant
        ↓
Lecture du journal AN
        ↓
Création des comptes d'ouverture
```

---

# 1. REFONTE DE LA CLÔTURE D'UN EXERCICE

Lorsque l'utilisateur clique sur **Clôturer l'exercice**, l'application ne doit plus simplement changer son statut.

Elle doit automatiquement générer un journal comptable.

Ce journal devra être créé avec les informations suivantes :

Code :

```
AN
```

Intitulé :

```
Journal des A-Nouveaux
```

Ce journal servira exclusivement aux reports d'ouverture.

---

# 2. GÉNÉRATION DES ÉCRITURES DU JOURNAL AN

Lors de la clôture :

Calculer les soldes des comptes appartenant uniquement aux classes :

* Classe 1
* Classe 2
* Classe 3
* Classe 4
* Classe 5

Les comptes des classes 6 et 7 ne doivent jamais être reportés.

Pour chaque compte ayant un solde non nul :

* créer automatiquement une écriture dans le journal AN ;
* respecter le sens comptable du solde (Débit ou Crédit).

Après avoir créé toutes les écritures de report, calculer le résultat global afin d'équilibrer le journal.

### Cas 1 : résultat excédentaire

Créer automatiquement une écriture sur le compte :

```
12100000
```

afin d'équilibrer le journal.

### Cas 2 : résultat déficitaire

Créer automatiquement une écriture sur le compte :

```
12900000
```

afin d'équilibrer le journal.

Le journal AN doit toujours être parfaitement équilibré.

---

# 3. LE JOURNAL AN DEVIENT LA SOURCE UNIQUE DES REPORTS

À partir de cette refonte :

La création d'un exercice avec report ne doit plus recalculer les soldes.

Les comptes d'ouverture devront être créés uniquement à partir des écritures présentes dans le journal AN.

Le journal AN devient donc l'unique source de vérité pour les reports.

---

# 4. REFONTE DE LA PAGE "NOUVEL EXERCICE"

L'écran actuel doit être entièrement repensé.

Au lieu de demander directement les dates, l'utilisateur doit d'abord choisir l'un des trois modes suivants.

---

## Option 1 : Créer un exercice avec report

Cette option permet de créer un nouvel exercice en reprenant les soldes de l'exercice précédent.

### Au clic :

L'application vérifie automatiquement si l'exercice précédent est clôturé.

### Si l'exercice précédent n'est pas clôturé

Interdire la création.

Afficher un message expliquant que la clôture est obligatoire avant de créer un exercice avec report, car cette clôture génère le journal AN.

### Si l'exercice précédent est clôturé

Demander :

* la date de début ;
* la date de fin.

Avant la validation finale, afficher un écran récapitulatif présentant :

* le journal AN qui sera utilisé ;
* la liste des comptes reportés ;
* le total global des reports ;
* le compte d'équilibrage utilisé (12100000 ou 12900000) ;
* un aperçu des écritures d'ouverture qui seront créées.

Après validation :

Créer automatiquement les comptes d'ouverture du nouvel exercice à partir du journal AN, sans aucun recalcul.

---

## Option 2 : Créer un exercice sans report

Cette option permet de créer un exercice totalement vide.

Au clic :

Demander uniquement :

* la date de début ;
* la date de fin.

Puis créer immédiatement l'exercice.

Aucun compte d'ouverture ne doit être créé.

Cependant, cette logique doit être pensée pour que cet exercice puisse être clôturé plus tard normalement.

Lors de sa future clôture :

* le journal AN devra être généré ;
* les comptes d'ouverture pourront être créés pour l'exercice suivant.

Cette option ne doit donc jamais casser la logique globale des reports.

---

## Option 3 : Créer un exercice antérieur

Cette option permet d'ajouter un exercice plus ancien que ceux déjà présents.

Exemple :

Si la base contient :

```
2026
```

l'utilisateur pourra créer :

```
2025
```

ou

```
2024
```

L'application devra vérifier la cohérence chronologique afin d'éviter des incohérences entre les exercices.

---

# 5. REFONTE DE LA LISTE DES EXERCICES

Moderniser l'interface.

Pour chaque exercice afficher clairement :

* le statut (Ouvert / Clôturé) ;
* la période ;
* la date de début ;
* la date de fin.

Si l'exercice est clôturé, ajouter une action :

```
Voir le journal AN
```

Cette action permettra d'ouvrir directement le journal généré.

Depuis cet écran, l'utilisateur devra pouvoir consulter :

* toutes les écritures du journal AN ;
* les comptes reportés ;
* le total global des reports ;
* le compte d'équilibrage utilisé (12100000 ou 12900000).

---

# 6. RÈGLES MÉTIER À RESPECTER

Respecter impérativement les règles suivantes :

* seuls les comptes des classes 1 à 5 sont reportés ;
* les comptes des classes 6 et 7 ne doivent jamais être reportés ;
* le journal AN est généré uniquement lors de la clôture ;
* le journal AN doit toujours être équilibré ;
* le compte 12100000 est utilisé si le résultat est excédentaire ;
* le compte 12900000 est utilisé si le résultat est déficitaire ;
* la création d'un exercice avec report est interdite tant que l'exercice précédent n'est pas clôturé ;
* la création avec report doit exclusivement utiliser le journal AN ;
* aucun recalcul des soldes ne doit être effectué lors de la création d'un exercice avec report ;
* la création sans report ne doit pas empêcher une future clôture ni la génération du journal AN ;
* toute la logique doit rester cohérente même avec plusieurs exercices successifs.

---

# 7. ATTENTES TECHNIQUES

Je ne veux pas une simple modification de l'interface.

Je souhaite une véritable refonte de la logique métier.

Avant de coder :

1. Audite entièrement l'implémentation actuelle.
2. Identifie les fichiers concernés.
3. Explique les modifications nécessaires.
4. Propose une architecture propre si nécessaire.
5. Implémente ensuite cette nouvelle logique en conservant la compatibilité avec le reste de l'application.

Le code devra être propre, modulaire, maintenable et conforme aux bonnes pratiques Flutter/Dart.

Je souhaite également une interface moderne, intuitive et adaptée à un logiciel comptable professionnel, tout en restant différente visuellement de Sage 100.
