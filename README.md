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
  - Comptes généraux (par défaut : 6 chiffres)
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
  longueur_compte_general INTEGER DEFAULT 6,
  longueur_compte_tiers INTEGER DEFAULT 8,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

### Table: exercice

Gère les exercices comptables (multi-exercices possibles).

```sql
CREATE TABLE exercice (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  date_debut TEXT NOT NULL,
  date_fin TEXT NOT NULL,
  duree_mois INTEGER NOT NULL,
  statut TEXT DEFAULT 'OUVERT',
  is_current INTEGER DEFAULT 0,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  CHECK(statut IN ('OUVERT', 'CLOTURE')),
  CHECK(is_current IN (0, 1))
);
```

**Valeurs possibles** :

- `statut` : 'OUVERT' ou 'CLOTURE'
- `is_current` : 0 (false) ou 1 (true) - Un seul exercice peut être marqué comme courant

### Table: users

Gère les utilisateurs du fichier comptable avec leurs droits d'accès.

```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nom TEXT NOT NULL,
  prenom TEXT,
  login TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  email TEXT,
  role TEXT DEFAULT 'user',
  is_active INTEGER DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  CHECK(role IN ('admin', 'user')),
  CHECK(is_active IN (0, 1))
);
```

**Notes** :

- Mot de passe hashé avec SHA-256
- Un utilisateur admin est créé automatiquement lors de la création du fichier si mot de passe activé
- Les utilisateurs inactifs ne peuvent pas se connecter

### Table: entite

Stocke les informations de l'organisation.

```sql
CREATE TABLE entite (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  denomination_sociale TEXT NOT NULL,
  sigle_usuel TEXT,
  domaine_intervention TEXT,
  forme_juridique TEXT,
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
  currency TEXT DEFAULT 'FCFA (XOF)',
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
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

### Tables principales

Chaque fichier utilisateur contient les tables suivantes :

````sql
-- Configuration de l'application
config (
  id, date_debut_exercice, date_fin_exercice, duree_exercice_mois,
  longueur_compte_general, longueur_compte_tiers
)

-- Authentification (si protection activée)
users (
  id, login, password_hash, created_at
)

-- Données de l'entité
entite (
  id, denomination_sociale, sigle_usuel, domaine_intervention,
  forme_juridique, pays, region, ville, quartier, email, telephone,
  fixe_fax, numero_fiscal, numero_cnss, numero_recepisse,
  informations_complementaires, currency
)

/* -- Plan comptable
compte (
  id, numero_compte, intitule, type_compte, created_at
)

-- Tiers (fournisseurs, clients)
tiers (
  id, nom, type_tiers, adresse, telephone, email, created_at
)

-- Journaux comptables
journal (
  id, code, libelle, type_journal, created_at
)

-- Bailleurs de fonds
bailleur (
  id, nom, type_bailleur, pays, contact, email, telephone, created_at
)

-- Projets
projet (
  id, code, intitule, date_debut, date_fin, statut, created_at
)

-- Budgets
budget (
  id, code, intitule, exercice, montant, projet_id, created_at
)

-- Monnaie
monnaie (
  id, code, nom, symbole, is_active, created_at
)
``` */

````

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
│   └── database_service_new.dart     # Gestion fichiers utilisateur
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

## 📝 Licence

Ce projet est sous licence MIT.

## 👥 Auteurs

- **SYCEBNL Team** - Développement initial

## 🆘 Support

Pour toute question ou problème, veuillez ouvrir une issue sur GitHub.

#### Table: `utilisateur`

Gère les utilisateurs et leurs accès

```sql
CREATE TABLE utilisateur (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nom VARCHAR(100) NOT NULL,
  prenom VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  is_admin BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

#### Table: `permission`

Gère les permissions par utilisateur et module

```sql
CREATE TABLE permission (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL,
  module VARCHAR(100) NOT NULL, -- Notre entité, Paramétrages, Traitements, Édition
  lecture BOOLEAN DEFAULT FALSE,
  creer BOOLEAN DEFAULT FALSE,
  modifier BOOLEAN DEFAULT FALSE,
  supprimer BOOLEAN DEFAULT FALSE,
  FOREIGN KEY (user_id) REFERENCES utilisateur(id) ON DELETE CASCADE
);
```

#### Table: `bailleur`

Organismes financeurs

```sql
CREATE TABLE bailleur (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code VARCHAR(20) UNIQUE NOT NULL,
  designation VARCHAR(255) NOT NULL,
  type VARCHAR(100),
  pays VARCHAR(100),
  contact VARCHAR(100),
  telephone VARCHAR(20),
  email VARCHAR(100),
  created_at TIMESTAMP DEFAULT NOW()
);
```

#### Table: `projet`

Projets et programmes

```sql
CREATE TABLE projet (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code VARCHAR(20) UNIQUE NOT NULL,
  designation VARCHAR(255) NOT NULL,
  date_debut DATE,
  date_fin DATE,
  statut VARCHAR(50) DEFAULT 'ACTIF', -- ACTIF, TERMINE, EN_SUSPEND
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

#### Table: `projet_bailleur`

Table de liaison projet-bailleur (relation N-N)

```sql
CREATE TABLE projet_bailleur (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  projet_id UUID NOT NULL,
  bailleur_id UUID NOT NULL,
  montant_finance DECIMAL(15,2),
  FOREIGN KEY (projet_id) REFERENCES projet(id) ON DELETE CASCADE,
  FOREIGN KEY (bailleur_id) REFERENCES bailleur(id) ON DELETE CASCADE,
  UNIQUE(projet_id, bailleur_id)
);
```

#### Table: `budget` (Niveau 1 - Hiérarchie budgétaire)

Budget principal lié à un projet

```sql
CREATE TABLE budget (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code VARCHAR(20) UNIQUE NOT NULL,
  designation VARCHAR(255) NOT NULL,
  projet_id UUID NOT NULL,
  montant DECIMAL(15,2), -- Montant planifié initial
  montant_total DECIMAL(15,2) DEFAULT 0, -- Calculé automatiquement (somme des postes)
  statut VARCHAR(50) DEFAULT 'En cours', -- En cours, Clôturé
  created_at TIMESTAMP DEFAULT NOW(),
  FOREIGN KEY (projet_id) REFERENCES projet(id) ON DELETE CASCADE
);
```

#### Table: `poste_budgetaire` (Niveau 2)

Postes budgétaires regroupant des lignes

```sql
CREATE TABLE poste_budgetaire (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code VARCHAR(20) NOT NULL,
  designation VARCHAR(255) NOT NULL,
  budget_id UUID NOT NULL,
  montant_total DECIMAL(15,2) DEFAULT 0, -- Calculé automatiquement (somme des lignes)
  created_at TIMESTAMP DEFAULT NOW(),
  FOREIGN KEY (budget_id) REFERENCES budget(id) ON DELETE CASCADE
);
```

#### Table: `ligne_budgetaire` (Niveau 3)

Lignes budgétaires regroupant des sous-rubriques

```sql
CREATE TABLE ligne_budgetaire (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code VARCHAR(20) NOT NULL,
  designation VARCHAR(255) NOT NULL,
  poste_budgetaire_id UUID NOT NULL,
  numero_compte VARCHAR(20), -- Liaison au plan comptable
  montant_total DECIMAL(15,2) DEFAULT 0, -- Calculé automatiquement (somme des sous-rubriques)
  created_at TIMESTAMP DEFAULT NOW(),
  FOREIGN KEY (poste_budgetaire_id) REFERENCES poste_budgetaire(id) ON DELETE CASCADE
);
```

#### Table: `sous_rubrique_budgetaire` (Niveau 4 - Saisie)

Sous-rubriques où les montants sont réellement saisis

```sql
CREATE TABLE sous_rubrique_budgetaire (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code VARCHAR(20) NOT NULL,
  designation VARCHAR(255) NOT NULL,
  ligne_budgetaire_id UUID NOT NULL,
  numero_compte VARCHAR(20), -- Liaison au plan comptable
  montant DECIMAL(15,2) DEFAULT 0, -- Montant saisi par l'utilisateur
  created_at TIMESTAMP DEFAULT NOW(),
  FOREIGN KEY (ligne_budgetaire_id) REFERENCES ligne_budgetaire(id) ON DELETE CASCADE
);
```

### Triggers de calcul automatique

Les montants totaux sont calculés automatiquement via des triggers PostgreSQL :

1. **Modification d'une sous-rubrique** → Met à jour `ligne_budgetaire.montant_total`
2. **Modification d'une ligne** → Met à jour `poste_budgetaire.montant_total`
3. **Modification d'un poste** → Met à jour `budget.montant_total`

**Cascade de calcul** : Sous-rubrique → Ligne → Poste → Budget

## 🎨 Design UI

### Palette de couleurs

- **Couleur primaire** : Indigo (#3F51B5)
- **Couleur d'accent** : Blue (#2196F3)
- **Succès** : Green (#4CAF50)
- **Attention** : Orange (#FF9800)
- **Erreur** : Red (#F44336)
- **Arrière-plan** : Gris clair (#F5F5F5)
- **Texte principal** : #212121 (Noir)
- **Texte secondaire** : #757575 (Gris)

### Principes de design moderne

#### Interface utilisateur

- **Material Design 3** avec composants modernisés
- **Sélection par cartes** au lieu de dropdowns traditionnels
- **Avatars avec initiales** pour identifier les utilisateurs
- **Indicateurs visuels** : bordures colorées, icônes de validation, badges
- **Layouts centrés** avec contraintes de largeur (600px max) pour une meilleure lisibilité

#### Composants visuels

- **AppBar** : Indigo avec texte blanc et boutons de retour
- **Cartes** : Blanches avec ombres légères, bordures arrondies (10-12px)
- **Cartes interactives** : Changement de couleur au survol/sélection
  - Fond indigo clair + bordure indigo (2px) quand sélectionné
  - Fond gris clair + bordure grise (1px) par défaut
- **Boutons** :
  - `ElevatedButton` pour actions primaires (fond indigo)
  - `OutlinedButton` pour actions secondaires (bordure grise)
  - Icônes incluses (18-20px) pour meilleure compréhension
- **Gradient backgrounds** : Pour mettre en valeur les informations importantes
- **Badges** : Petites étiquettes colorées pour les statuts ("En cours d'utilisation", etc.)
- **Spacing responsive** : Utilisation de `screenHeight` et `screenWidth` pour s'adapter aux écrans

### Exemples d'interfaces

#### Page Monnaie (Redesign moderne)

- Icône principale centrée (40px) dans cercle coloré
- Titre centré avec sous-titre explicatif
- Carte affichant la monnaie actuelle avec gradient bleu
- Sélection par cartes (4 devises) avec :
  - Boîte symbole 40×40px colorée selon sélection
  - Label complet de la devise
  - Badge vert "En cours d'utilisation" pour la devise active
  - Checkmark (✓) pour la sélection
- Boutons Annuler / Enregistrer en bas

#### Page Autorisations d'accès

- Liste de tous les utilisateurs en cartes (pas de dropdown)
- Chaque carte utilisateur :
  - Avatar circulaire avec initiales
  - Nom complet et email
  - Indicateur de sélection (fond bleu + bordure + checkmark)
- Tableau de permissions (Lecture, Créer, Modifier, Supprimer) par module

#### Hiérarchie budgétaire

- Arborescence expandable (ExpansionTile)
- 4 niveaux visuellement distincts avec indentation
- Affichage des montants calculés automatiquement
- Boutons d'action (Ajouter, Modifier, Supprimer) par élément

## 🚀 Installation et démarrage

### Prérequis

- **Flutter SDK** 3.7.0 ou supérieur ([Installation](https://docs.flutter.dev/get-started/install))
- **Dart** 3.7+ (inclus avec Flutter)
- **Supabase** : Compte et projet configuré ([supabase.com](https://supabase.com))
- Pour Android : Android SDK et émulateur/appareil
- Pour iOS : Xcode et simulateur/appareil (macOS uniquement)
- Pour Windows : Visual Studio avec composants C++

### Configuration Supabase

1. Créer un projet sur [Supabase](https://supabase.com)
2. Configurer l'URL et la clé anonyme dans votre application
3. Exécuter les migrations SQL dans l'éditeur SQL Supabase :
   ```bash
   # Dans l'ordre :
   1. create_bailleur_table.sql
   2. create_projet_tables.sql
   3. create_budget_tables.sql
   ```
4. Activer Row Level Security (RLS) selon vos besoins

### Installation

```bash
# Cloner le projet
git clone <repository-url>
cd sycebnl_accounting

# Installer les dépendances
flutter pub get

# Vérifier la configuration Flutter
flutter doctor

# Lancer l'application (debug)
flutter run

# Build pour production (exemple Windows)
flutter build windows

# Build pour Android
flutter build apk

# Build pour iOS (macOS uniquement)
flutter build ios
```

### Variables d'environnement

Créer un fichier de configuration pour Supabase (à ne pas commiter) :

```dart
// lib/config/supabase_config.dart
class SupabaseConfig {
  static const String supabaseUrl = 'VOTRE_URL_SUPABASE';
  static const String supabaseAnonKey = 'VOTRE_CLE_ANONYME';
}
```

## 📋 Fonctionnement du système budgétaire

### Hiérarchie à 4 niveaux

Le système budgétaire utilise une structure hiérarchique permettant une gestion détaillée et des calculs automatiques :

**Niveau 1 : Budget**

- Lié à un projet spécifique
- Contient deux montants :
  - `montant` : Montant planifié/initial (saisi manuellement)
  - `montant_total` : Calculé automatiquement (somme des postes)
- Statut : En cours / Clôturé

**Niveau 2 : Poste budgétaire**

- Regroupe plusieurs lignes budgétaires
- `montant_total` calculé automatiquement (somme des lignes)

**Niveau 3 : Ligne budgétaire**

- Regroupe plusieurs sous-rubriques
- Lié à un numéro de compte comptable
- `montant_total` calculé automatiquement (somme des sous-rubriques)

**Niveau 4 : Sous-rubrique budgétaire** (niveau de saisie)

- C'est ici que les montants sont réellement saisis
- Lié à un numéro de compte comptable
- La modification déclenche le recalcul en cascade vers le haut

### Calcul automatique en cascade

Les triggers PostgreSQL assurent la mise à jour automatique :

1. Modification d'une **sous-rubrique** → Recalcule la **ligne**
2. Modification d'une **ligne** → Recalcule le **poste**
3. Modification d'un **poste** → Recalcule le **budget**

**Exemple** :

```
Budget "Budget 2024" (Montant planifié: 1 000 000 Fr)
├─ Poste "Fonctionnement" (Total calculé: 300 000 Fr)
│  ├─ Ligne "Salaires" (Total calculé: 200 000 Fr)
│  │  ├─ Sous-rubrique "Salaire Directeur" : 100 000 Fr ← SAISIE
│  │  └─ Sous-rubrique "Salaire Comptable" : 100 000 Fr ← SAISIE
│  └─ Ligne "Fournitures" (Total calculé: 100 000 Fr)
│     └─ Sous-rubrique "Papeterie" : 100 000 Fr ← SAISIE
└─ Budget montant_total = 300 000 Fr (auto-calculé)
```

## 📝 Notes de développement

- L'application utilise **Material Design 3** avec design moderne et épuré
- **Supabase** pour l'authentification et la base de données PostgreSQL
- **Validation côté client** sur tous les formulaires avec messages d'erreur explicites
- **Interface moderne** : cartes interactives au lieu de dropdowns, avatars, badges, gradients
- **Responsive design** : adaptation automatique aux différentes tailles d'écran
- **Triggers PostgreSQL** : calculs budgétaires entièrement automatisés
- **CASCADE DELETE** : suppression en cascade pour maintenir l'intégrité référentielle
- **Row Level Security (RLS)** : sécurité au niveau des lignes Supabase

## 🔐 Sécurité

- **Authentification Supabase** : système d'auth sécurisé intégré
- **Gestion des droits d'accès granulaires** par module et utilisateur
  - Permissions : Lecture, Créer, Modifier, Supprimer
  - Configuration par module : Notre entité, Paramétrages, Traitements, Édition
- **Rôles utilisateurs** : Administrateur vs utilisateur standard
- **Row Level Security (RLS)** : contrôle d'accès au niveau des lignes PostgreSQL
- **Hachage des mots de passe** : géré automatiquement par Supabase
- **Tokens JWT** : authentification sécurisée par jetons
- **Audit automatique** : timestamps created_at/updated_at sur toutes les tables

## 📚 Ressources

- [Documentation Flutter](https://flutter.dev)
- [Material Design 3](https://m3.material.io)
- [Dart Documentation](https://dart.dev)
- [Supabase Documentation](https://supabase.com/docs)
- [Supabase Flutter SDK](https://supabase.com/docs/reference/dart/introduction)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

## 📄 Licence

Ce projet est propriétaire de SYCEBNL.

---

**Version** : 1.0.0  
**Dernière mise à jour** : 24 novembre 2025  
**Stack** : Flutter 3.7+ | Dart 3.7+ | Supabase | PostgreSQL
