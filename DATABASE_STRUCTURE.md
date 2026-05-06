# Structure de la base de données

## Architecture

L'application SYCEBNL Accounting utilise deux types de bases de données SQLite :

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

**Exemple de données** :

```
id: 1
longueur_compte_general: 6
longueur_compte_tiers: 8
```

---

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

**Exemple de données** :

```
id: 1
code: "2024"
date_debut: 2024-01-01T00:00:00.000
date_fin: 2024-12-31T00:00:00.000
duree_mois: 12
statut: CLOTURE
is_current: 0

id: 2
code: "2025"
date_debut: 2025-01-01T00:00:00.000
date_fin: 2025-12-31T00:00:00.000
duree_mois: 12
statut: OUVERT
is_current: 1
```

---

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

**Valeurs possibles** :

- `role` : 'admin' (administrateur avec tous les droits) ou 'user' (utilisateur standard)
- `is_active` : 1 (actif) ou 0 (désactivé)

**Exemple de données** :

```
id: 1
nom: "Administrateur"
prenom: ""
login: "admin"
password_hash: "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8"
email: "admin@example.com"
role: "admin"
is_active: 1

id: 2
nom: "Dupont"
prenom: "Jean"
login: "jdupont"
password_hash: "..."
email: "jdupont@example.com"
role: "user"
is_active: 1
```

**Notes** :

- Mot de passe hashé avec SHA-256
- Un utilisateur admin est créé automatiquement lors de la création du fichier si mot de passe activé
- Les utilisateurs inactifs ne peuvent pas se connecter

---

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

**Exemple de données** :

```
id: 1
denomination_sociale: ONG Développement Communautaire
sigle_usuel: ODC
domaine_intervention: Éducation et santé communautaire
forme_juridique: ONG locale
pays: Bénin
region: Atlantique
ville: Cotonou
quartier: Akpakpa
email: contact@ongexemple.org
telephone: +229 97 00 00 00
fixe_fax: +229 21 30 00 00
numero_fiscal: IFU0123456789
numero_cnss: CNSS987654321
numero_recepisse: REC/2020/001
informations_complementaires: ONG créée en 2020...
currency: FCFA (XOF)
```

---

### Table: compte

Plan comptable de l'entité.

```sql
CREATE TABLE compte (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  numero_compte TEXT NOT NULL UNIQUE,
  intitule TEXT NOT NULL,
  type TEXT NOT NULL,
  nature TEXT NOT NULL,
  liaison_tiers INTEGER DEFAULT 0,
  description TEXT,
  is_active INTEGER DEFAULT 1,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT
);
```

**Types de comptes** :

- Capitaux propres
- Dettes
- Créances
- Trésorerie
- Charges
- Produits
- Immobilisations
- Stocks

**Exemples** :

```
101000 | Capital social | Capitaux propres
401000 | Fournisseurs | Dettes
411000 | Clients | Créances
512000 | Banque | Trésorerie
530000 | Caisse | Trésorerie
601000 | Achats de marchandises | Charges
701000 | Ventes de produits | Produits
```

---

### Table: tiers

Fournisseurs, clients, prestataires.

```sql
CREATE TABLE tiers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nom TEXT NOT NULL,
  type_tiers TEXT,
  adresse TEXT,
  telephone TEXT,
  email TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

**Types de tiers** :

- Fournisseur
- Client
- Prestataire
- Employé
- Autre

**Exemples** :

```
1 | Fournisseur ABC | Fournisseur | Rue de la Paix, Cotonou | +229 97 11 11 11 | abc@example.com
2 | Client XYZ | Client | Avenue de l'Indépendance, Porto-Novo | +229 97 22 22 22 | xyz@example.com
3 | Consultant Martin | Prestataire | Quartier Agla, Cotonou | +229 97 33 33 33 | martin@example.com
```

---

### Table: journal

Journaux comptables pour la saisie.

```sql
CREATE TABLE journal (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  libelle TEXT NOT NULL,
  type_journal TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

**Types de journaux** :

- Vente
- Achat
- Banque
- Caisse
- Divers

**Exemples** :

```
VTE | Journal des ventes | Vente
ACH | Journal des achats | Achat
BQ | Journal de banque | Banque
CAIS | Journal de caisse | Caisse
OD | Opérations diverses | Divers
```

---

### Table: bailleur

Organismes financeurs.

```sql
CREATE TABLE bailleur (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nom TEXT NOT NULL,
  type_bailleur TEXT,
  pays TEXT,
  contact TEXT,
  email TEXT,
  telephone TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

**Types de bailleurs** :

- Institution internationale
- Institution financière
- Agence
- Fondation privée
- Gouvernement
- Autre

**Exemples** :

```
1 | Union Européenne | Institution internationale | Belgique | Jean Dupont | eu@example.com | +32 2 123 45 67
2 | Banque Mondiale | Institution financière | États-Unis | Sarah Johnson | wb@example.com | +1 202 123 4567
3 | AFD | Agence | France | Pierre Martin | afd@example.com | +33 1 23 45 67 89
```

---

### Table: projet

Projets gérés par l'entité.

```sql
CREATE TABLE projet (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  intitule TEXT NOT NULL,
  date_debut TEXT,
  date_fin TEXT,
  statut TEXT DEFAULT 'Actif',
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

**Statuts possibles** :

- Actif
- Terminé
- En suspens
- Annulé

**Exemples** :

```
PROJ001 | Éducation pour tous | 2025-01-01 | 2027-12-31 | Actif
PROJ002 | Santé communautaire | 2024-06-01 | 2026-05-31 | Actif
PROJ003 | Développement agricole | 2023-01-01 | 2024-12-31 | Terminé
```

---

### Table: budget

Budgets des projets (liés à un exercice comptable).

```sql
CREATE TABLE budget (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL,
  intitule TEXT NOT NULL,
  exercice_id INTEGER NOT NULL,
  montant REAL DEFAULT 0,
  projet_id INTEGER,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (exercice_id) REFERENCES exercice (id),
  FOREIGN KEY (projet_id) REFERENCES projet (id)
);
```

**Exemples** :

```
BUD2025-01 | Budget Éducation 2025 | 1 (exercice 2025) | 50000000.00 | 1
BUD2025-02 | Budget Santé 2025 | 1 (exercice 2025) | 35000000.00 | 2
```

---

### Table: monnaie

Devises disponibles.

```sql
CREATE TABLE monnaie (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  nom TEXT NOT NULL,
  symbole TEXT,
  is_active INTEGER DEFAULT 0,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

**Monnaies supportées** :

```
XOF | Franc CFA | FCFA | 1 (active)
EUR | Euro | € | 0
USD | Dollar américain | $ | 0
GBP | Livre sterling | £ | 0
```

**Note** : `is_active = 1` indique la monnaie de tenue de compte.

---

## Relations entre tables

```
exercice (1) ----< (N) budget
  - Un exercice peut avoir plusieurs budgets
  - Un budget est lié à un exercice spécifique

projet (1) ----< (N) budget
  - Un projet peut avoir plusieurs budgets
  - Un budget est lié à un projet

entite (1) ---- (1) config
  - Une entité a une configuration unique (longueur des comptes)
  - Configuration définie lors de la création du fichier

exercice (N)
  - Un fichier peut contenir plusieurs exercices comptables
  - Un seul exercice peut être marqué comme courant (is_current = 1)

users (0..N)
  - Optionnel : table vide si pas de protection
  - Peut contenir plusieurs utilisateurs (futurs développements)
```

---

## Fichier exemple

Un fichier `database/exemple.db` est fourni avec :

- **Entité** : ONG Développement Communautaire (Bénin)
- **Comptes** : 10 comptes de base (capital, fournisseurs, clients, banque, caisse, charges, produits)
- **Tiers** : 3 tiers (1 fournisseur, 1 client, 1 prestataire)
- **Journaux** : 5 journaux (ventes, achats, banque, caisse, OD)
- **Bailleurs** : 3 bailleurs (UE, Banque Mondiale, AFD)
- **Projets** : 3 projets (2 actifs, 1 terminé)
- **Budgets** : 2 budgets pour 2025
- **Monnaies** : 4 devises (FCFA actif)

**Pas de mot de passe** : le fichier peut être ouvert directement.

---

## Bonnes pratiques

### Sauvegardes

- Copier régulièrement les fichiers .db
- Utiliser le contrôle de version (Git) pour les sauvegardes
- Exporter les données importantes (CSV, Excel)

### Sécurité

- Utiliser un mot de passe fort pour les fichiers sensibles
- Ne pas partager les mots de passe
- Chiffrer les sauvegardes si nécessaire

### Performance

- Indexer les colonnes fréquemment recherchées
- Nettoyer les données obsolètes
- Compacter la base de données (VACUUM) régulièrement

### Migration

- Versionner les schémas de base de données
- Tester les migrations sur des copies
- Documenter les changements de structure
