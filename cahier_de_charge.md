# Cahier des charges du projet SYCEBNL Accounting

## 1. Présentation générale

### 1.1 Contexte

SYCEBNL Accounting est une application de gestion comptable et administrative développée en Flutter pour les organisations à but non lucratif, les associations, les ONG et les entités publiques. Elle vise à centraliser la tenue comptable, la gestion budgétaire et le suivi des référentiels métiers dans une application desktop simple à déployer et utilisable hors ligne.

### 1.2 Finalité du projet

Le projet a pour objectif de fournir un outil fiable permettant de :

- créer et ouvrir des fichiers comptables portables par entité ;
- gérer les paramètres de base de l'organisation ;
- tenir un plan comptable structuré ;
- saisir et suivre les journaux comptables ;
- organiser les budgets par hiérarchie métier ;
- gérer les tiers, projets et bailleurs ;
- produire des états de synthèse et des exports.

### 1.3 Périmètre

L'application est conçue en priorité pour un usage desktop sur Windows, Linux et macOS. Le projet repose sur une architecture locale avec SQLite et un fichier de données par entité.

---

## 2. Objectifs du projet

### 2.1 Objectifs fonctionnels

- Permettre la création d'un fichier comptable dédié à une entité.
- Sécuriser l'accès par mot de passe si nécessaire.
- Centraliser les données d'identification de l'entité.
- Gérer les comptes, journaux, exercices, tiers, budgets et projets.
- Faciliter la saisie comptable avec contrôle de cohérence.
- Offrir des états de consultation et de reporting.

### 2.2 Objectifs métier

- Réduire la dispersion des données comptables.
- Harmoniser la saisie et le suivi des opérations.
- Améliorer le contrôle interne grâce aux permissions utilisateurs.
- Faciliter la préparation des rapports financiers et budgétaires.

---

## 3. Parties prenantes

### 3.1 Utilisateurs cibles

- Administrateur du fichier comptable.
- Comptable ou agent de saisie.
- Responsable financier.
- Superviseur ou contrôleur.
- Utilisateur de consultation selon les droits accordés.

### 3.2 Rôles attendus

- **Administrateur** : configure l'entité, les comptes, les exercices et les permissions.
- **Saisie comptable** : enregistre les écritures et consulte les journaux.
- **Gestionnaire** : suit les budgets, projets, bailleurs et états de synthèse.
- **Consultation** : lit les informations sans modification.

---

## 4. Besoins fonctionnels

### 4.1 Accueil et gestion des fichiers

- Afficher les fichiers récemment ouverts.
- Permettre la création d'un nouveau fichier comptable.
- Ouvrir un fichier existant.
- Conserver une base locale de configuration pour les fichiers récents.

### 4.2 Création d'un fichier comptable

L'assistant de création doit permettre :

- le choix de l'emplacement du fichier .db ;
- la saisie des informations d'identification de l'entité ;
- l'activation optionnelle d'un mot de passe ;
- la définition des paramètres comptables de base.

### 4.3 Gestion de l'entité

Le système doit permettre de stocker et modifier :

- la dénomination sociale ;
- le sigle usuel ;
- le domaine d'intervention ;
- la forme juridique ;
- les coordonnées géographiques et de contact ;
- les références fiscales et administratives ;
- la devise de travail ;
- les informations complémentaires.

### 4.4 Authentification et permissions

- Connexion par identifiant et mot de passe.
- Gestion des utilisateurs du fichier.
- Attributions de droits par rôle ou par permission.
- Protection des données sensibles selon le niveau d'accès.

### 4.5 Exercices comptables

- Création d'exercices comptables.
- Définition des dates de début et de fin.
- Activation d'un exercice courant.
- Gestion du statut ouvert ou clôturé.

### 4.6 Plan comptable

- Création, modification, consultation et suppression des comptes.
- Gestion des comptes de détail et de total.
- Association d'une nature comptable au compte.
- Prise en charge de la longueur configurée des numéros de compte.
- Gestion du rattachement éventuel aux tiers.

### 4.7 Journaux comptables

- Création et modification des journaux.
- Distinction entre journaux financiers et non financiers.
- Association d'un compte de trésorerie aux journaux financiers.
- Recherche, filtrage et suppression des journaux.

### 4.8 Saisie comptable

- Création d'écritures par journal et par période.
- Saisie des lignes débit et crédit.
- Contrôle de l'équilibre comptable.
- Consultation de l'historique des écritures.
- Lettrage des comptes.

### 4.9 Budgets

- Gestion des budgets hiérarchiques.
- Organisation par niveau : budget, poste, ligne, sous-rubrique.
- Consultation des détails budgétaires.
- Suivi de la structure budgétaire par exercice.

### 4.10 Tiers, projets et bailleurs

- Création et gestion des tiers.
- Suivi des projets.
- Gestion des bailleurs de fonds.
- Rattachement des éléments de suivi au besoin métier.

### 4.11 États et consultations

- Balance des comptes.
- État de résultat.
- Interrogations comptables.
- Consultation des lettrages.

### 4.12 Export et exploitation

- Génération de documents exploitables.
- Export des données vers des formats de travail usuels selon les besoins du projet.

---

## 5. Besoins non fonctionnels

### 5.1 Ergonomie

- Interface en français.
- Navigation claire et structurée.
- Formulaires guidés pour limiter les erreurs de saisie.

### 5.2 Performance

- Réactivité correcte avec des bases locales SQLite.
- Chargement rapide des listes et formulaires.

### 5.3 Fiabilité

- Sauvegarde locale des données par entité.
- Gestion des erreurs d'accès et de saisie.
- Conservation de l'intégrité des données comptables.

### 5.4 Sécurité

- Protection optionnelle par mot de passe.
- Hachage des mots de passe avant stockage.
- Contrôle d'accès par utilisateur et par rôle.

### 5.5 Portabilité

- Un fichier de données par entité.
- Possibilité de déplacer, copier et sauvegarder les fichiers .db.

### 5.6 Maintenabilité

- Architecture organisée par modèles, services et pages.
- Séparation des responsabilités entre interface et logique métier.

---

## 6. Contraintes techniques

### 6.1 Stack actuelle

- Flutter / Dart.
- SQLite via sqflite_common_ffi pour les plateformes desktop.
- Gestion de fichiers locale et portable.
- Génération d'exports selon les modules du projet.

### 6.2 Plateformes visées

- Windows.
- Linux.
- macOS.

### 6.3 Stockage

- Base locale de configuration pour les fichiers récents.
- Base utilisateur autonome par entité.

---

## 7. Données principales

Les données du projet couvrent notamment :

- entité ;
- configuration comptable ;
- exercice ;
- utilisateur ;
- compte ;
- tiers ;
- journal ;
- saisie comptable ;
- budget ;
- poste budgétaire ;
- ligne budgétaire ;
- sous-rubrique ;
- projet ;
- bailleur ;
- lettrage.

Ces objets doivent être cohérents entre eux et respectent les règles métiers du plan comptable et de la tenue des journaux.

---

## 8. Règles de gestion

- Un fichier comptable est rattaché à une seule entité.
- Un exercice actif doit être identifiable à tout moment.
- Les journaux financiers doivent être reliés à un compte de trésorerie valide.
- Les comptes doivent respecter la longueur configurée.
- Les écritures comptables doivent être équilibrées entre débit et crédit.
- Les données supprimées doivent conserver si possible une trace logique de suppression.

---

## 9. Livrables attendus

- Application Flutter desktop compilable.
- Documentation utilisateur minimale.
- Documentation technique sur la structure des données.
- Fichiers de configuration et scripts de démarrage du projet.
- Base de données locale et fichier utilisateur conforme au modèle défini.

---

## 10. Critères d'acceptation

Le projet sera considéré comme conforme si :

- l'utilisateur peut créer, ouvrir et exploiter un fichier comptable ;
- l'entité peut être paramétrée correctement ;
- les comptes, journaux, exercices et utilisateurs sont gérés sans incohérence ;
- la saisie comptable fonctionne avec contrôle des règles essentielles ;
- les budgets, projets, bailleurs et états de synthèse sont accessibles ;
- l'application fonctionne de manière stable sur les plateformes desktop ciblées.

---

## 11. Conclusion

SYCEBNL Accounting est une solution de gestion comptable locale, portable et structurée, pensée pour répondre aux besoins des organisations qui doivent centraliser leur comptabilité, maîtriser leurs budgets et sécuriser leurs données. Le présent cahier des charges formalise les besoins fonctionnels, techniques et organisationnels du projet tel qu'il est actuellement défini.
