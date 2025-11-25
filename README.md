# SYCEBNL Accounting

## 📊 À propos du projet

**SYCEBNL Accounting** est une application de gestion comptable et administrative moderne conçue pour les organisations à but non lucratif (ONG) et les entités publiques. Cette application offre une suite d'outils pour gérer efficacement la comptabilité, les budgets, les ressources et les rapports financiers.

### Objectifs principaux $FLUTTER_BASE_HREF

- Centraliser la gestion comptable de l'entité
- Faciliter la saisie et la réconciliation des opérations comptables
- Gérer les budgets hiérarchiques à 4 niveaux (Budget → Poste → Ligne → Sous-rubrique)
- Suivre les projets et leurs bailleurs de fonds
- Administrer les droits d'accès utilisateurs avec gestion granulaire
- Maintenir un plan comptable personnalisé
- Configuration multi-devises (XOF, EUR, USD, GBP)

## 🎯 Fonctionnalités principales

### 1. **Notre entité**

- **Identification** : Gérer les informations de base de l'organisation (dénomination sociale, domaine, contacts)
- **Autorisations d'accès** : Créer et gérer les utilisateurs avec interface moderne (cartes avec avatars)
  - Gestion granulaire des permissions (Lecture, Créer, Modifier, Supprimer) par module
  - Visualisation claire des utilisateurs avec avatars et informations complètes
- **Monnaie** : Interface modernisée pour sélectionner la devise de tenue de compte
  - 4 devises supportées : Franc CFA (XOF), Euro (EUR), Dollar US (USD), Livre Sterling (GBP)
  - Sélection visuelle avec cartes interactives

### 2. **Paramétrages**

- **Plan comptable** : Créer et maintenir le plan comptable personnalisé de l'entité
- **Liste des tiers** : Gérer les fournisseurs, clients et autres tiers
- **Journaux de saisie** : Configurer les journaux comptables (Ventes, Achats, Banque, etc.)
- **Liste des bailleurs** : Gérer les organismes financeurs avec informations complètes
- **Liste des projets** : Référencer et gérer les projets avec multi-bailleurs
  - Liaison dynamique avec plusieurs bailleurs par projet
  - Suivi des dates de début et fin
  - Gestion du statut (Actif, Terminé, En suspens)
- **Budgets hiérarchiques** : Système à 4 niveaux avec calculs automatiques
  - **Budget** : Niveau supérieur lié à un projet (montant planifié vs montant total calculé)
  - **Poste budgétaire** : Regroupement de lignes budgétaires
  - **Ligne budgétaire** : Regroupement de sous-rubriques avec liaison au compte
  - **Sous-rubrique budgétaire** : Niveau de saisie des montants réels
  - Calculs automatiques via triggers PostgreSQL (somme cascade de bas en haut)

### 3. **Traitements**

- **Saisie comptable** : Enregistrer les opérations comptables par journal et période
  - Saisie structurée avec validation des montants
  - Suivi des ventilations (débits/crédits)
  - Gestion des documents associés
- **Interrogations et lettrages** : Consulter et rapprocher les comptes
- **Nouvel exercice** : Initialiser une nouvelle période comptable

### 4. **Édition**

- **Balance des comptes** : Consulter la balance générale
- **Grand livre** : Afficher le détail des mouvements par compte
- **Journal** : Afficher les enregistrements par journal

## 🏗️ Architecture technique

### Stack technologique

- **Framework** : Flutter (Dart 3.7+)
- **Backend** : Supabase (PostgreSQL + Authentication)
- **Plateforme cible** : Windows, iOS, Android, macOS, Linux, Web
- **Design** : Material Design 3 avec interface moderne

### Dépendances principales

```yaml
dependencies:
  flutter: sdk
  cupertino_icons: ^1.0.8
  supabase_flutter: ^2.5.0
```

### Structure du projet

```
lib/
├── main.dart                          # Point d'entrée de l'application
├── models/
│   ├── user_session.dart             # Modèle de session utilisateur
│   └── entite.dart                   # Modèle d'entité
├── services/
│   └── auth_service.dart             # Service d'authentification Supabase
├── pages/
│   ├── home_page.dart                # Page d'accueil avec menu principal
│   ├── entite_list_page.dart         # Liste des entités
│   ├── entite_form_page.dart         # Formulaire entité
│   ├── autorisations_acces_page.dart # Gestion des utilisateurs et permissions
│   ├── monnaie_page.dart             # Configuration de la monnaie
│   ├── plan_comptable_page.dart      # Gestion du plan comptable
│   ├── liste_tiers_page.dart         # Gestion des tiers
│   ├── journaux_page.dart            # Gestion des journaux
│   ├── liste_bailleurs_page.dart     # Gestion des bailleurs
│   ├── liste_projets_page.dart       # Gestion des projets
│   ├── gestion_budgets_page.dart     # Liste et CRUD des budgets
│   └── budget_details_page.dart      # Hiérarchie budgétaire (4 niveaux)

supabase/
└── migrations/
    ├── create_bailleur_table.sql     # Table des bailleurs
    ├── create_projet_tables.sql      # Tables projets et projet_bailleur
    ├── create_budget_tables.sql      # Tables budget (4 niveaux) + triggers
    └── alter_budget_add_montant.sql  # Migration montant pour budgets existants
```

## 💾 Base de données (Supabase / PostgreSQL)

### Schéma de données

#### Table: `entite`

Stocke les informations de l'organisation

```sql
CREATE TABLE entite (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  denomination_sociale VARCHAR(255) NOT NULL,
  sigle VARCHAR(50),
  domaine VARCHAR(255),
  pays VARCHAR(100),
  ville VARCHAR(100),
  region VARCHAR(100),
  quartier VARCHAR(100),
  fixe_fax VARCHAR(20),
  telephone VARCHAR(20),
  email VARCHAR(100),
  numero_fiscal VARCHAR(50),
  n_cnss VARCHAR(50),
  forme_juridique VARCHAR(100),
  n_recipisse VARCHAR(50),
  infos_complementaires TEXT,
  currency VARCHAR(3) DEFAULT 'XOF', -- XOF, EUR, USD, GBP
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

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
