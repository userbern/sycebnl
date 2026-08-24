# Contenu de la base de données `exemple.db`

Généré le 2026-08-24 15:23:26

## Table : bailleur

### Schéma
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

### Contenu (3 ligne(s))

| id |       nom        |       type_bailleur        |    pays    |    contact    |      email      |     telephone     |     created_at      |
|----|------------------|----------------------------|------------|---------------|-----------------|-------------------|---------------------|
| 1  | Union Européenne | Institution internationale | Belgique   | Jean Dupont   | eu@example.com  | +32 2 123 45 67   | 2025-11-28 17:10:58 |
| 2  | Banque Mondiale  | Institution financière     | États-Unis | Sarah Johnson | wb@example.com  | +1 202 123 4567   | 2025-11-28 17:10:58 |
| 3  | AFD              | Agence                     | France     | Pierre Martin | afd@example.com | +33 1 23 45 67 89 | 2025-11-28 17:10:58 |


## Table : compte

### Schéma
```sql
CREATE TABLE compte (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          numero_compte TEXT NOT NULL UNIQUE,
          intitule TEXT NOT NULL,
          type_compte TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
```

### Contenu (10 ligne(s))

| id | numero_compte |        intitule        |   type_compte    |     created_at      |
|----|---------------|------------------------|------------------|---------------------|
| 1  | 101000        | Capital social         | Capitaux propres | 2025-11-28 17:10:58 |
| 2  | 120000        | Résultat de l'exercice | Capitaux propres | 2025-11-28 17:10:58 |
| 3  | 401000        | Fournisseurs           | Dettes           | 2025-11-28 17:10:58 |
| 4  | 411000        | Clients                | Créances         | 2025-11-28 17:10:58 |
| 5  | 512000        | Banque                 | Trésorerie       | 2025-11-28 17:10:58 |
| 6  | 530000        | Caisse                 | Trésorerie       | 2025-11-28 17:10:58 |
| 7  | 601000        | Achats de marchandises | Charges          | 2025-11-28 17:10:58 |
| 8  | 606000        | Achats de fournitures  | Charges          | 2025-11-28 17:10:58 |
| 9  | 621000        | Personnel              | Charges          | 2025-11-28 17:10:58 |
| 10 | 701000        | Ventes de produits     | Produits         | 2025-11-28 17:10:58 |


## Table : entite

### Schéma
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

### Contenu (1 ligne(s))

| id |      denomination_sociale       | sigle_usuel |       domaine_intervention       | forme_juridique | pays  |   region   |  ville  | quartier |         email          |    telephone     |     fixe_fax     | numero_fiscal |  numero_cnss  | numero_recepisse |                               informations_complementaires                                |  currency  |     created_at      |
|----|---------------------------------|-------------|----------------------------------|-----------------|-------|------------|---------|----------|------------------------|------------------|------------------|---------------|---------------|------------------|-------------------------------------------------------------------------------------------|------------|---------------------|
| 1  | ONG Développement Communautaire | ODC         | Éducation et santé communautaire | ONG locale      | Bénin | Atlantique | Cotonou | Akpakpa  | contact@ongexemple.org | +229 97 00 00 00 | +229 21 30 00 00 | IFU0123456789 | CNSS987654321 | REC/2020/001     | ONG créée en 2020, spécialisée dans l'éducation et la santé communautaire en zone rurale. | FCFA (XOF) | 2025-11-28 17:10:58 |


## Table : journal

### Schéma
```sql
CREATE TABLE journal (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT NOT NULL UNIQUE,
          libelle TEXT NOT NULL,
          type_journal TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
```

### Contenu (5 ligne(s))

| id | code |       libelle       | type_journal |     created_at      |
|----|------|---------------------|--------------|---------------------|
| 1  | VTE  | Journal des ventes  | Vente        | 2025-11-28 17:10:58 |
| 2  | ACH  | Journal des achats  | Achat        | 2025-11-28 17:10:58 |
| 3  | BQ   | Journal de banque   | Banque       | 2025-11-28 17:10:58 |
| 4  | CAIS | Journal de caisse   | Caisse       | 2025-11-28 17:10:58 |
| 5  | OD   | Opérations diverses | Divers       | 2025-11-28 17:10:58 |


## Table : projet

### Schéma
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

### Contenu (3 ligne(s))

| id |  code   |        intitule        | date_debut |  date_fin  | statut  |     created_at      |
|----|---------|------------------------|------------|------------|---------|---------------------|
| 1  | PROJ001 | Éducation pour tous    | 2025-01-01 | 2027-12-31 | Actif   | 2025-11-28 17:10:58 |
| 2  | PROJ002 | Santé communautaire    | 2024-06-01 | 2026-05-31 | Actif   | 2025-11-28 17:10:58 |
| 3  | PROJ003 | Développement agricole | 2023-01-01 | 2024-12-31 | Terminé | 2025-11-28 17:10:58 |


## Table : users

### Schéma
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
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT,
          CHECK(role IN ('admin', 'user')),
          CHECK(is_active IN (0, 1))
        );
```

### Contenu (0 ligne(s))

_Table vide._


## Table : budget

### Schéma
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

### Contenu (2 ligne(s))

| id |    code    |       intitule        | exercice_id |  montant   | projet_id |     created_at      |
|----|------------|-----------------------|-------------|------------|-----------|---------------------|
| 1  | BUD2025-01 | Budget Éducation 2025 | 1           | 50000000.0 | 1         | 2025-11-28 17:10:58 |
| 2  | BUD2025-02 | Budget Santé 2025     | 1           | 35000000.0 | 2         | 2025-11-28 17:10:58 |


## Table : config

### Schéma
```sql
CREATE TABLE config (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          longueur_compte_general INTEGER DEFAULT 6,
          longueur_compte_tiers INTEGER DEFAULT 8,
          has_password INTEGER DEFAULT 0,
          password_hash TEXT,
          login TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
```

### Contenu (1 ligne(s))

| id | longueur_compte_general | longueur_compte_tiers | has_password | password_hash | login |     created_at      |
|----|-------------------------|-----------------------|--------------|---------------|-------|---------------------|
| 1  | 6                       | 8                     | 0            |               |       | 2025-11-28 17:10:58 |


## Table : exercice

### Schéma
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

### Contenu (1 ligne(s))

| id | code |       date_debut        |        date_fin         | duree_mois | statut | is_current |     created_at      |
|----|------|-------------------------|-------------------------|------------|--------|------------|---------------------|
| 1  | 2025 | 2025-01-01T00:00:00.000 | 2025-12-31T00:00:00.000 | 12         | OUVERT | 1          | 2025-11-28 17:10:58 |


## Table : monnaie

### Schéma
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

### Contenu (4 ligne(s))

| id | code |       nom        | symbole | is_active |     created_at      |
|----|------|------------------|---------|-----------|---------------------|
| 1  | XOF  | Franc CFA        | FCFA    | 1         | 2025-11-28 17:10:58 |
| 2  | EUR  | Euro             | €       | 0         | 2025-11-28 17:10:58 |
| 3  | USD  | Dollar américain | $       | 0         | 2025-11-28 17:10:58 |
| 4  | GBP  | Livre sterling   | £       | 0         | 2025-11-28 17:10:58 |


## Table : tiers

### Schéma
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

### Contenu (3 ligne(s))

| id |        nom        | type_tiers  |               adresse                |    telephone     |       email        |     created_at      |
|----|-------------------|-------------|--------------------------------------|------------------|--------------------|---------------------|
| 1  | Fournisseur ABC   | Fournisseur | Rue de la Paix, Cotonou              | +229 97 11 11 11 | abc@example.com    | 2025-11-28 17:10:58 |
| 2  | Client XYZ        | Client      | Avenue de l'Indépendance, Porto-Novo | +229 97 22 22 22 | xyz@example.com    | 2025-11-28 17:10:58 |
| 3  | Consultant Martin | Prestataire | Quartier Agla, Cotonou               | +229 97 33 33 33 | martin@example.com | 2025-11-28 17:10:58 |


