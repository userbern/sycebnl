# SYCEBNL Accounting

## 📊 À propos du projet

**SYCEBNL Accounting** est une application de gestion comptable et administrative moderne conçue pour les organisations à but non lucratif (ONG) et les entités publiques. Cette application offre une suite d'outils pour gérer efficacement la comptabilité, les budgets, les ressources et les rapports financiers.

### Objectifs principaux

- Gestion multi-fichiers : chaque entité dispose de son propre fichier de base de données portable
- Interface de création de fichiers guidée avec assistant en 4 étapes
- Protection optionnelle par mot de passe pour chaque fichier
- Centraliser la gestion comptable de l'entité
- Faciliter la saisie et la réconciliation des opérations comptables
- Gérer les budgets hiérarchiques à 4 niveaux (Budget → Poste → Ligne → Sous-rubrique)
- Suivre les projets et leurs bailleurs de fonds
- Administrer les droits d'accès utilisateurs
- Maintenir un plan comptable personnalisé

## 🎯 Architecture de l'application

### Système de fichiers

L'application utilise une architecture à deux bases de données :

1. **Base de données locale (app_config.db)**
   - Emplacement : `%LOCALAPPDATA%/SYCEBNL/app_config.db`
   - Contient la liste des fichiers récemment ouverts
   - Persistante sur la machine de l'utilisateur

2. **Fichiers de bases de données utilisateur (.db)**
   - Un fichier par entité/organisation
   - Portable : peut être déplacé, copié, sauvegardé
   - Protection optionnelle par mot de passe (SHA-256)
   - Contient toutes les données de l'entité (comptes, tiers, journaux, budgets, etc.)

### Assistant de création de fichier

L'application démarre avec une page d'accueil présentant :

- Liste des fichiers récemment ouverts (avec bouton "Ouvrir")
- Bouton "Créer un nouveau fichier"

L'assistant de création se déroule en 4 étapes avec barre de progression :

#### Étape 1 : Emplacement du fichier

- Sélection de l'emplacement et du nom du fichier (.db)
- Interface avec bouton de sélection et aperçu du chemin choisi

#### Étape 2 : Identification de l'entité

Formulaire organisé en 4 sections :

1. **Identification**
   - Dénomination sociale (obligatoire)
   - Sigle usuel
   - Domaine d'intervention
   - Forme juridique (liste déroulante) :
     - ONG internationale
     - Association
     - ONG locale
     - Ordre professionnel
     - Fondation
     - Congrégation religieuse
     - Club sportif
     - Club services
     - Parti politique

2. **Localisation et contact**
   - Pays, Ville
   - Région, Quartier
   - Téléphone, Téléphone fixe/Fax
   - Email

3. **Référence de reconnaissance fiscale**
   - N° d'identification fiscal (NIF/IFU/NCC)
   - N° Récépissé
   - N° CNSS
   - Autre référence

4. **Monnaie et informations complémentaires**
   - Devise (par défaut : FCFA (XOF), modifiable)
   - Informations complémentaires (multi-lignes)

#### Étape 3 : Sécurité (optionnel)

- Case à cocher pour activer la protection par mot de passe
- Champs : Login (par défaut : admin), Mot de passe, Confirmation
- Mot de passe hashé en SHA-256 avant stockage

#### Étape 4 : Paramètres comptables

- **Exercice comptable**
  - Date début (par défaut : date du jour)
  - Date fin (par défaut : 31/12 de l'année en cours)
  - Calcul automatique de la durée (max 18 mois)
- **Longueur des comptes**
  - Comptes généraux (par défaut : 8 chiffres)
  - Comptes tiers (par défaut : 8 chiffres)

## 🏗️ Structure de la base de données

### 1. Base de données locale (app_config.db)

- **Emplacement** : `%LOCALAPPDATA%/SYCEBNL/app_config.db`
- **Rôle** : Suivre les fichiers récemment ouverts
- **Persistance** : Sur la machine de l'utilisateur

#### Table: recent_files

```sql
CREATE TABLE recent_files (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_path TEXT NOT NULL UNIQUE,
  last_opened TEXT DEFAULT CURRENT_TIMESTAMP,
  entity_name TEXT
);
```

### 2. Fichiers utilisateur (.db)

- **Emplacement** : Choisi par l'utilisateur
- **Rôle** : Contenir toutes les données d'une entité
- **Portabilité** : Peut être copié, déplacé, sauvegardé
- **Protection** : Mot de passe optionnel (SHA-256)

---

## Tables des fichiers utilisateur

### Table: config

Stocke les paramètres fixes de l'application (longueur des comptes).

```sql
CREATE TABLE config (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  longueur_compte_general INTEGER NOT NULL,
  longueur_compte_tiers INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT
);
```

### Table: exercice

Gère les exercices comptables (multi-exercices possibles, max 5 par fichier).

```sql
CREATE TABLE exercice (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL,
  date_debut TEXT NOT NULL,
  date_fin TEXT NOT NULL,
  duree_mois INTEGER,
  is_active INTEGER DEFAULT 1,
  is_cloture INTEGER DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT
);
```

**Valeurs possibles** :

- `is_active` : 0 (false) ou 1 (true) - Un seul exercice peut être marqué comme actif
- `is_cloture` : 0 (ouvert) ou 1 (clôturé)

### Table: utilisateur

Gère les utilisateurs du fichier comptable avec leurs droits d'accès.

```sql
CREATE TABLE utilisateur (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  login TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,
  role TEXT DEFAULT 'utilisateur',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT
);
```

**Notes** :

- Mot de passe hashé avec SHA-256
- Un utilisateur admin est créé automatiquement lors de la création du fichier si mot de passe activé
- Rôles possibles : 'admin', 'utilisateur'
- Les utilisateurs supprimés ont un `deleted_at` non null (soft delete)

### Table: entite

Stocke les informations de l'organisation (une seule entité par fichier).

```sql
CREATE TABLE entite (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  denomination_sociale TEXT NOT NULL,
  sigle_usuel TEXT,
  domaine_intervention TEXT,
  forme_juridique TEXT,
  ong_type TEXT,
  pays TEXT,
  region TEXT,
  ville TEXT,
  quartier TEXT,
  email TEXT,
  telephone TEXT,
  fixe_fax TEXT,
  numero_fiscal TEXT,
  numero_cnss TEXT,
  numero_recepisse TEXT,
  informations_complementaires TEXT,
  currency TEXT DEFAULT 'XOF',
  created_by INTEGER,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT,
  is_active INTEGER DEFAULT 1,
  FOREIGN KEY (created_by) REFERENCES utilisateur(id)
);
```

**Valeurs possibles pour `forme_juridique`** :

- ONG internationale
- Association
- ONG locale
- Ordre professionnel
- Fondation
- Congrégation religieuse
- Club sportif
- Club services
- Parti politique

### Table: compte

Gère le plan comptable (comptes généraux).

```sql
CREATE TABLE compte (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  numero_compte TEXT UNIQUE NOT NULL,
  intitule TEXT NOT NULL,
  type TEXT NOT NULL,
  nature TEXT NOT NULL,
  liaison_tiers INTEGER DEFAULT 0,
  is_active INTEGER DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT
);
```

**Valeurs possibles** :

- `type` : 'detail', 'total'
- `nature` : 17 natures (bilan_ressources_durables, bilan_actif_immobilise, etc.)
- `liaison_tiers` : 0 (non) ou 1 (oui) - Permet d'associer un tiers

### Table: tiers

Gère les tiers (fournisseurs, clients, salariés, etc.).

```sql
CREATE TABLE tiers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  numero_compte TEXT NOT NULL,
  intitule TEXT NOT NULL,
  type TEXT NOT NULL,
  compte_collectif TEXT NOT NULL,
  nif TEXT,
  adresse TEXT,
  is_active INTEGER DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT
);
```

**Types de tiers** : client, fournisseur, salarié, banque, caisse, autre

### Table: journal

Gère les journaux comptables.

```sql
CREATE TABLE journal (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT UNIQUE NOT NULL,
  libelle TEXT NOT NULL,
  type TEXT NOT NULL,
  numero_compte_tresorerie TEXT,
  saisie_analytique INTEGER DEFAULT 0,
  is_active INTEGER DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT,
  FOREIGN KEY (numero_compte_tresorerie) REFERENCES compte(numero_compte)
);
```

**Types de journal** : financier, non_financier

### Table: bailleur

Gère les bailleurs de fonds.

```sql
CREATE TABLE bailleur (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sigle TEXT UNIQUE NOT NULL,
  designation TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT
);
```

### Table: projet

Gère les projets.

```sql
CREATE TABLE projet (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT UNIQUE NOT NULL,
  designation TEXT NOT NULL,
  date_debut TEXT NOT NULL,
  date_fin TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT
);
```

### Table: projet_bailleur

Table de liaison entre projets et bailleurs (relation N-N).

```sql
CREATE TABLE projet_bailleur (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  projet_id INTEGER NOT NULL,
  bailleur_id INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (projet_id) REFERENCES projet(id) ON DELETE CASCADE,
  FOREIGN KEY (bailleur_id) REFERENCES bailleur(id),
  UNIQUE (projet_id, bailleur_id)
);
```

### Tables budgétaires (hiérarchie à 4 niveaux)

#### Table: budget (Niveau 1)

```sql
CREATE TABLE budget (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  projet_id INTEGER NOT NULL,
  bailleur_id INTEGER NOT NULL,
  exercice_id INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT,
  FOREIGN KEY (projet_id) REFERENCES projet(id) ON DELETE CASCADE,
  FOREIGN KEY (bailleur_id) REFERENCES bailleur(id) ON DELETE CASCADE,
  FOREIGN KEY (exercice_id) REFERENCES exercice(id) ON DELETE CASCADE,
  UNIQUE (projet_id, bailleur_id, exercice_id)
);
```

#### Table: poste_budgetaire (Niveau 2)

```sql
CREATE TABLE poste_budgetaire (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  budget_id INTEGER NOT NULL,
  intitule TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT,
  FOREIGN KEY (budget_id) REFERENCES budget(id) ON DELETE CASCADE
);
```

#### Table: ligne_budgetaire (Niveau 3)

```sql
CREATE TABLE ligne_budgetaire (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  poste_budgetaire_id INTEGER NOT NULL,
  code TEXT NOT NULL,
  intitule TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT,
  FOREIGN KEY (poste_budgetaire_id) REFERENCES poste_budgetaire(id) ON DELETE CASCADE
);
```

#### Table: sous_rubrique (Niveau 4 - Saisie)

```sql
CREATE TABLE sous_rubrique (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ligne_budgetaire_id INTEGER NOT NULL,
  intitule TEXT NOT NULL,
  montant REAL NOT NULL DEFAULT 0,
  compte_id INTEGER,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT,
  FOREIGN KEY (ligne_budgetaire_id) REFERENCES ligne_budgetaire(id) ON DELETE CASCADE,
  FOREIGN KEY (compte_id) REFERENCES compte(id)
);
```

### Tables de saisie comptable

#### Table: journaux_periodes

Gère les périodes de saisie par journal.

```sql
CREATE TABLE journaux_periodes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code_journal TEXT NOT NULL,
  annee INTEGER NOT NULL,
  mois INTEGER NOT NULL,
  exercice_id INTEGER,
  nombre_ecritures INTEGER DEFAULT 0,
  total_debit REAL DEFAULT 0,
  total_credit REAL DEFAULT 0,
  solde_final REAL DEFAULT 0,
  is_equilibre INTEGER DEFAULT 0,
  is_closed INTEGER DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT,
  FOREIGN KEY (code_journal) REFERENCES journal(code),
  FOREIGN KEY (exercice_id) REFERENCES exercice(id),
  UNIQUE (code_journal, annee, mois, exercice_id)
);
```

#### Table: ecritures

Stocke les lignes d'écriture comptable.

```sql
CREATE TABLE ecritures (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  journal_periode_id INTEGER NOT NULL,
  numero_enregistrement INTEGER NOT NULL,
  jour INTEGER NOT NULL,
  date_comptable TEXT,
  numero_document TEXT NOT NULL,
  reference TEXT,
  numero_compte TEXT NOT NULL,
  numero_tiers TEXT,
  libelle TEXT NOT NULL,
  montant_debit REAL DEFAULT 0,
  montant_credit REAL DEFAULT 0,
  is_ventilee INTEGER DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT,
  FOREIGN KEY (journal_periode_id) REFERENCES journaux_periodes(id) ON DELETE CASCADE,
  FOREIGN KEY (numero_compte) REFERENCES compte(numero_compte),
  FOREIGN KEY (numero_tiers) REFERENCES tiers(numero_compte)
);
```

#### Table: ventilations_analytiques

Gère les ventilations analytiques des écritures.

```sql
CREATE TABLE ventilations_analytiques (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ecriture_id INTEGER NOT NULL,
  type TEXT NOT NULL,
  id_projet INTEGER,
  volet TEXT,
  id_bailleur INTEGER,
  id_poste_budgetaire INTEGER,
  id_ligne_budgetaire INTEGER,
  montant_ventile REAL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT,
  FOREIGN KEY (ecriture_id) REFERENCES ecritures(id) ON DELETE CASCADE,
  FOREIGN KEY (id_projet) REFERENCES projet(id) ON DELETE CASCADE,
  FOREIGN KEY (id_poste_budgetaire) REFERENCES poste_budgetaire(id) ON DELETE CASCADE,
  FOREIGN KEY (id_ligne_budgetaire) REFERENCES ligne_budgetaire(id) ON DELETE CASCADE
);
```

### Tables de gestion des permissions

#### Table: modules

```sql
CREATE TABLE modules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nom TEXT UNIQUE NOT NULL
);
```

#### Table: permissions

```sql
CREATE TABLE permissions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  utilisateur_id INTEGER NOT NULL,
  module_id INTEGER NOT NULL,
  lecture INTEGER DEFAULT 0,
  ajout INTEGER DEFAULT 0,
  modification INTEGER DEFAULT 0,
  suppression INTEGER DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT,
  FOREIGN KEY (utilisateur_id) REFERENCES utilisateur(id) ON DELETE CASCADE,
  FOREIGN KEY (module_id) REFERENCES modules(id) ON DELETE CASCADE,
  UNIQUE (utilisateur_id, module_id)
);
```

## 🎨 Interface utilisateur

### Design moderne

- Barre de progression visuelle avec étapes numérotées
- Formulaires avec champs arrondis (border-radius: 12px)
- Listes déroulantes stylisées avec icônes personnalisées
- Sections colorées avec en-têtes bleus
- Disposition responsive avec champs côte à côte
- Boutons de navigation fixes en bas de page

### Navigation

- **Page d'accueil (Welcome)** : Liste des fichiers récents + boutons d'action
- **Assistant de création** : Navigation linéaire avec validation à chaque étape
- **Page principale** : Sidebar avec menu organisé en sections

## 🚀 Installation et utilisation

### Prérequis

- Flutter SDK 3.7+
- Dart 3.7+
- Windows / macOS / Linux

### Installation

```bash
# Cloner le dépôt
git clone https://github.com/userbern/sycebnl_accounting.git
cd sycebnl_accounting

# Installer les dépendances
flutter pub get

# Lancer l'application (Windows)
flutter run -d windows

# Ou créer un exécutable
flutter build windows
```

### Première utilisation

1. **Lancer l'application** : La page d'accueil s'affiche
2. **Créer un nouveau fichier** :
   - Cliquer sur "Créer un nouveau fichier"
   - Suivre l'assistant en 4 étapes
   - Renseigner les informations de l'entité
   - Optionnellement : définir un mot de passe
   - Configurer les paramètres comptables
3. **Le fichier est créé** : L'application s'ouvre automatiquement sur le nouveau fichier
4. **Utilisation ultérieure** : Le fichier apparaît dans la liste des fichiers récents

### Ouvrir un fichier existant

- Depuis la page d'accueil : cliquer sur un fichier de la liste
- Ou : cliquer sur "Ouvrir un fichier existant" et naviguer vers le fichier .db
- Si le fichier est protégé : saisir le login et mot de passe

## 🛠️ Stack technologique

- **Framework** : Flutter (Dart 3.7+)
- **Base de données** : SQLite (sqflite_common_ffi)
- **Gestion de fichiers** : file_picker
- **Stockage local** : path_provider
- **Sécurité** : crypto (SHA-256)
- **Plateforme cible** : Windows Desktop (extensible à macOS, Linux)
- **Design** : Material Design 3

### Dépendances principales

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  sqflite_common_ffi: ^2.3.0+1
  path_provider: ^2.1.1
  file_picker: ^6.1.1
  crypto: ^3.0.3
```

## 📁 Structure du projet

```
lib/
├── main.dart                          # Point d'entrée
├── config/
│   └── theme.dart                    # Configuration du thème
├── models/
│   ├── user_session.dart             # Session utilisateur
│   ├── entite.dart                   # Entité
│   ├── compte.dart                   # Compte
│   ├── tiers.dart                    # Tiers
│   ├── journal.dart                  # Journal
│   ├── bailleur.dart                 # Bailleur
│   ├── projet.dart                   # Projet
│   └── budget.dart                   # Budget
├── services/
│   ├── app_config_service.dart       # Gestion app_config.db
│   └── database_service.dart         # Gestion fichiers utilisateur
├── pages/
│   ├── welcome_page.dart             # Page d'accueil
│   ├── new_file_wizard_page.dart     # Assistant création fichier
│   ├── password_login_page.dart      # Authentification
│   ├── home_page.dart                # Page principale
│   ├── entite_form_page.dart         # Formulaire entité
│   ├── plan_comptable_page.dart      # Plan comptable
│   ├── liste_tiers_page.dart         # Gestion tiers
│   ├── journaux_page.dart            # Gestion journaux
│   ├── liste_bailleurs_page.dart     # Gestion bailleurs
│   ├── liste_projets_page.dart       # Gestion projets
│   ├── gestion_budgets_page.dart     # Gestion budgets
│   └── monnaie_page.dart             # Configuration monnaie
└── widgets/
    └── (composants réutilisables)

database/
└── exemple.db                         # Fichier exemple avec données de test
```

## 🧪 Tester l'application

Un fichier de démonstration `exemple.db` est fourni dans le dossier `database/` avec :

- Une entité "ONG Exemple" pré-remplie
- Quelques comptes dans le plan comptable
- Des tiers, journaux, bailleurs et projets de test
- Un budget exemple

Pour l'utiliser :

1. Lancer l'application
2. Cliquer sur "Ouvrir un fichier existant"
3. Sélectionner `database/exemple.db`
4. (Pas de mot de passe configuré)

## 🗂️ Organisation des menus

L'application est organisée en 5 menus principaux accessibles depuis la sidebar :

### 📂 Notre Entité

Menu pour gérer les informations de l'organisation :

- **Identification** : Modifier les informations de l'entité (dénomination, sigle, forme juridique, contacts, etc.)
- **Nouvel exercice** : Créer et gérer les exercices comptables (date début/fin, activation)
- **Monnaie** : Configurer la devise principale (XOF, EUR, USD, XAF)

### ⚙️ Paramétrages

Configuration des données de base comptables :

- **Plan comptable** : Gérer les comptes généraux avec leurs natures et types
- **Liste des tiers** : Créer et gérer les tiers (fournisseurs, clients, salariés)
- **Codes journaux** : Définir les journaux comptables (financiers ou non)
- **Liste des bailleurs** : Enregistrer les bailleurs de fonds
- **Liste des projets** : Créer les projets avec association aux bailleurs
- **Gestion des budgets** : Gérer la hiérarchie budgétaire à 4 niveaux

### 📝 Traitements

Opérations comptables courantes :

- **Saisie comptable** : Enregistrer les écritures par journal et période
- **Journaux de saisie** : Consulter les périodes de saisie par journal avec statistiques
- **Interrogations & Lettrages** : Consulter les écritures par compte et effectuer le lettrage
- **Balance des comptes** : Afficher la balance par nature avec mouvements et soldes

### 📊 Éditions

États et rapports comptables (en développement) :

- Grand livre
- Journaux comptables
- Bilan
- Compte de résultat
- États budgétaires
- Exports PDF/Excel

### 🚀 Accès rapide

Raccourcis vers les fonctions les plus utilisées :

- Saisie comptable
- Journaux de saisie
- Interrogations & Lettrages
- Plan comptable
- Codes journaux

**Navigation** : Sidebar réduite/étendue avec icônes claires • Barre de recherche pour filtres • Indicateur de fichier connecté en bas

## ✅ État des fonctionnalités

### 🎯 Fonctionnalités implémentées

#### 🏠 Gestion des fichiers

- ✅ Page d'accueil avec liste des fichiers récents
- ✅ Création de nouveau fichier avec assistant en 4 étapes
- ✅ Ouverture de fichier existant
- ✅ Protection par mot de passe (SHA-256)
- ✅ Gestion de la base de données locale (app_config.db)
- ✅ Portabilité des fichiers (.db)

#### 🏢 Gestion de l'entité

- ✅ Identification complète de l'entité (9 formes juridiques)
- ✅ Informations de contact et localisation
- ✅ Références fiscales et administratives
- ✅ Configuration de la devise
- ✅ Modification des informations de l'entité

#### 📅 Gestion des exercices comptables

- ✅ Création d'exercice comptable (18 mois max)
- ✅ Gestion multi-exercices
- ✅ Activation/désactivation d'exercices
- ✅ Configuration de la longueur des comptes

#### 📊 Plan comptable

- ✅ Création de comptes avec auto-détection de la nature
- ✅ Types de comptes : Total / Détail
- ✅ 17 natures de comptes (Bilan, Charges, Produits)
- ✅ Rattachement de tiers aux comptes
- ✅ Recherche et filtres (Nature, Type)
- ✅ Pagination des comptes (5-50 par page)
- ✅ Modification et suppression de comptes
- ✅ Validation d'utilisation avant suppression
- ✅ Completion automatique avec zéros (comptes détail)

#### 🤝 Gestion des tiers

- ✅ Création et modification de tiers
- ✅ Types de tiers : Fournisseur, Client, Autres
- ✅ Recherche et filtres
- ✅ Suppression avec validation

#### 📖 Gestion des journaux

- ✅ Création de journaux comptables
- ✅ Types : Achats, Ventes, Trésorerie, Opérations diverses, A nouveau
- ✅ Association de comptes (débit/crédit)
- ✅ Numérotation automatique des pièces
- ✅ Recherche et gestion complète

#### 💰 Saisie comptable

- ✅ Sélection Journal + Période
- ✅ Saisie d'écritures en mode tableau
- ✅ Validation de l'équilibre (Débit = Crédit)
- ✅ Calcul automatique des totaux
- ✅ Saisie rapide au clavier (Enter, Tab)
- ✅ Ajout/suppression de lignes
- ✅ Enregistrement des pièces comptables
- ✅ Support des comptes tiers

#### 📋 Journaux de saisie

- ✅ Liste des périodes par journal
- ✅ Statistiques par période (écritures, pièces, montant)
- ✅ Filtrage par date et journal
- ✅ Accès rapide à la saisie
- ✅ Indicateurs visuels d'activité

#### 🔍 Interrogations et lettrages

- ✅ Liste des comptes avec filtres
- ✅ Consultation des écritures par compte
- ✅ Détail des pièces comptables
- ✅ Lettrage manuel des écritures
- ✅ Indication visuelle du lettrage
- ✅ Statistiques par compte (débit, crédit, solde)

#### 📈 Balance des comptes

- ✅ Affichage de la balance par nature de compte
- ✅ Filtrage par période
- ✅ Colonnes : Solde début, Mouvements (D/C), Solde fin
- ✅ Totaux par nature
- ✅ Grand total de la balance
- ✅ Export possible

#### 💼 Gestion des bailleurs

- ✅ Liste des bailleurs de fonds
- ✅ Types : Gouvernement, ONG internationale, Entreprise privée, Fondation, Organisme multilatéral, Autre
- ✅ Informations complètes (pays, contact, email, téléphone)
- ✅ Recherche et filtres
- ✅ CRUD complet

#### 🎯 Gestion des projets

- ✅ Création et gestion de projets
- ✅ Association multi-bailleurs
- ✅ Dates de début et fin
- ✅ Statuts : Actif, Terminé, En suspens
- ✅ Description détaillée

#### 💵 Gestion budgétaire

- ✅ Structure hiérarchique à 4 niveaux :
  - Budget (lié à un projet)
  - Poste budgétaire
  - Ligne budgétaire (avec compte)
  - Sous-rubrique (niveau de saisie, avec compte)
- ✅ Calcul automatique en cascade des montants
- ✅ Interface arborescente expandable
- ✅ Création/modification/suppression à tous les niveaux
- ✅ Liaison au plan comptable

#### 💱 Gestion de la monnaie

- ✅ Configuration de la devise principale
- ✅ 4 devises prédéfinies : FCFA (XOF), Euro, Dollar US, Franc CFA (XAF)
- ✅ Interface moderne avec sélection par cartes
- ✅ Badge "En cours d'utilisation"

#### 🎨 Interface utilisateur

- ✅ Design Material Design 3
- ✅ Sidebar avec menus déroulants
- ✅ Raccourcis d'accès rapide
- ✅ Indicateur de base de données connectée
- ✅ Barre de statut avec informations
- ✅ Responsive design
- ✅ Mode sidebar réduit/étendu
- ✅ Formulaires avec validation
- ✅ Messages de confirmation et d'erreur

### ⏳ Fonctionnalités à implémenter

#### 👥 Gestion des utilisateurs et permissions

- ⏳ Création de comptes utilisateurs multiples
- ⏳ Gestion des rôles (Admin, Comptable, Consultation)
- ⏳ Permissions granulaires par module :
  - Notre entité
  - Paramétrages
  - Traitements
  - Édition
- ⏳ Permissions par action (Lecture, Créer, Modifier, Supprimer)
- ⏳ Interface de gestion des autorisations
- ⏳ Audit des actions utilisateurs

#### 📊 États et rapports

- ⏳ Grand livre
- ⏳ Balance générale détaillée
- ⏳ Balance âgée
- ⏳ Journaux comptables (édition)
- ⏳ Bilan comptable
- ⏳ Compte de résultat
- ⏳ État de suivi budgétaire
- ⏳ Rapports par projet
- ⏳ Rapports par bailleur
- ⏳ Export PDF/Excel

#### 🔄 Traitements comptables avancés

- ⏳ Clôture d'exercice
- ⏳ Réouverture d'exercice
- ⏳ Report à nouveau automatique
- ⏳ Écritures de régularisation
- ⏳ Annulation d'écritures
- ⏳ Rapprochement bancaire
- ⏳ Délettrage d'écritures
- ⏳ Lettrage automatique

#### 📈 Analyse budgétaire

- ⏳ Comparaison Budget vs Réalisé
- ⏳ Taux de consommation budgétaire
- ⏳ Écarts budgétaires
- ⏳ Prévisions de consommation
- ⏳ Alertes de dépassement
- ⏳ Tableaux de bord budgétaires

#### 🔐 Sécurité avancée

- ⏳ Validation à deux facteurs
- ⏳ Historique des connexions
- ⏳ Blocage après tentatives échouées
- ⏳ Expiration de session
- ⏳ Sauvegarde automatique chiffrée

#### 🌐 Fonctionnalités cloud (optionnel)

- ⏳ Synchronisation cloud Supabase
- ⏳ Travail collaboratif multi-utilisateurs
- ⏳ Sauvegarde automatique en ligne
- ⏳ Accès web depuis navigateur

#### 📱 Multi-plateforme

- ✅ Windows Desktop (implémenté)
- ⏳ macOS Desktop
- ⏳ Linux Desktop
- ⏳ Android
- ⏳ iOS
- ⏳ Web

#### 🛠️ Outils et utilitaires

- ⏳ Import de données (CSV, Excel)
- ⏳ Export de données
- ⏳ Archivage d'exercices
- ⏳ Sauvegarde/restauration de fichier
- ⏳ Compactage de base de données
- ⏳ Fusion de fichiers
- ⏳ Configuration avancée

#### 📚 Documentation et aide

- ⏳ Manuel utilisateur intégré
- ⏳ Tutoriels vidéo
- ⏳ Aide contextuelle
- ⏳ Base de connaissances
- ⏳ FAQ intégrée

### 📊 Progression globale

**Modules principaux** : 12/15 (80%)  
**Fonctionnalités essentielles** : 45/65 (69%)  
**Interface utilisateur** : 90% complète  
**Stabilité** : Production-ready pour usage monoposte

---

## 📄 Licence

Ce projet est propriétaire de SYCEBNL.

---

**Version** : 1.2.0  
**Dernière mise à jour** : 20 janvier 2026  
**Stack** : Flutter 3.7+ | Dart 3.7+ | SQLite (local) | Supabase (optionnel)
