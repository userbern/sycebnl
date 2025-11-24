# Système de Gestion Budgétaire

## Vue d'ensemble

Le système de gestion budgétaire permet de structurer et suivre les budgets par projet avec une hiérarchie à 4 niveaux.

## Hiérarchie budgétaire

```
Budget
  └─ Poste budgétaire
      └─ Ligne budgétaire
          └─ Sous-rubrique budgétaire
```

### 1. Budget (Niveau supérieur)

- **Affecté à un projet** : Chaque budget est lié à un projet spécifique
- **Champs** :
  - Code (unique)
  - Désignation
  - Projet (référence)
  - Exercice (année budgétaire)
  - Statut (brouillon, validé, clôturé)
  - Montant total (calculé automatiquement)

### 2. Poste budgétaire

- **Contient** : Des lignes budgétaires
- **Champs** :
  - Code
  - Désignation
  - Montant total (somme des lignes budgétaires)

### 3. Ligne budgétaire

- **Contient** : Des sous-rubriques budgétaires
- **Champs** :
  - Code
  - Désignation
  - N° Compte
  - Montant total (somme des sous-rubriques)

### 4. Sous-rubrique budgétaire (Niveau de détail)

- **Niveau le plus détaillé** avec montants réels
- **Champs** :
  - Code
  - Désignation
  - Montant (valeur saisie)
  - N° Compte

## Calcul automatique des montants

Le système utilise des **triggers PostgreSQL** pour calculer automatiquement les montants :

1. **Sous-rubrique → Ligne** : Quand une sous-rubrique est ajoutée/modifiée/supprimée, le montant de la ligne budgétaire parent est recalculé
2. **Ligne → Poste** : Quand une ligne change, le montant du poste budgétaire parent est recalculé
3. **Poste → Budget** : Quand un poste change, le montant total du budget est recalculé

### Exemple :

```
Budget "BUDGET-2025" (Montant: 150 000 $)
  ├─ Poste "RESSOURCES HUMAINES" (Montant: 100 000 $)
  │   ├─ Ligne "SALAIRES" (Montant: 80 000 $)
  │   │   ├─ Sous-rubrique "Salaire Directeur" : 30 000 $
  │   │   └─ Sous-rubrique "Salaire Comptable" : 50 000 $
  │   └─ Ligne "FORMATIONS" (Montant: 20 000 $)
  │       └─ Sous-rubrique "Formation technique" : 20 000 $
  └─ Poste "EQUIPEMENTS" (Montant: 50 000 $)
      └─ Ligne "INFORMATIQUE" (Montant: 50 000 $)
          ├─ Sous-rubrique "Ordinateurs" : 30 000 $
          └─ Sous-rubrique "Licences" : 20 000 $
```

## Fichiers créés

### 1. Migration SQL

**Fichier** : `supabase/migrations/create_budget_tables.sql`

- Crée les 4 tables avec relations CASCADE
- Crée les triggers de calcul automatique
- Configure les politiques RLS
- Ajoute les index pour performances

### 2. Page de gestion des budgets

**Fichier** : `lib/pages/gestion_budgets_page.dart`

- Liste tous les budgets
- CRUD pour les budgets
- Affichage du projet associé
- Gestion des permissions (création, modification, suppression)
- Navigation vers la page de détails

### 3. Page de détails du budget

**Fichier** : `lib/pages/budget_details_page.dart`

- Vue hiérarchique complète (postes → lignes → sous-rubriques)
- CRUD pour chaque niveau
- Interface expansible/collapsible
- Affichage des montants calculés à chaque niveau
- Gestion des permissions

## Utilisation

### 1. Exécuter la migration SQL

```sql
-- Dans Supabase SQL Editor
-- Copier et exécuter le contenu de create_budget_tables.sql
```

### 2. Créer un budget

1. Aller dans **PARAMETRAGES → Gestion des budgets**
2. Cliquer sur **Nouveau Budget** (ou Ctrl+N)
3. Remplir :
   - Code
   - Désignation
   - Sélectionner un projet
   - Exercice (année)
   - Statut

### 3. Structurer le budget

1. Cliquer sur l'icône **👁️ Voir détails** d'un budget
2. Créer des **postes budgétaires**
3. Pour chaque poste, créer des **lignes budgétaires**
4. Pour chaque ligne, créer des **sous-rubriques** avec montants

### 4. Suivi des montants

Les montants sont calculés automatiquement :

- Ajoutez/modifiez une sous-rubrique → la ligne se met à jour
- Ajoutez/modifiez une ligne → le poste se met à jour
- Ajoutez/modifiez un poste → le budget se met à jour

## Permissions

Le système respecte les permissions de l'utilisateur :

- **création** : Peut créer des budgets et éléments
- **modification** : Peut modifier les données
- **suppression** : Peut supprimer (avec confirmation)

Si aucune permission n'est définie, l'accès total est autorisé (default-allow).

## Statuts du budget

- **brouillon** : Budget en cours d'élaboration
- **validé** : Budget approuvé, prêt à être utilisé
- **clôturé** : Budget finalisé, généralement non modifiable

## Affichage

### Page principale (Liste des budgets)

```
[Code] - [Désignation]
Projet: [Code projet] - [Nom projet]
Exercice: [Année] | Statut: [Statut] | Montant: [Total] $
```

### Page de détails (Vue hiérarchique)

```
📦 POSTE [Code] - [Désignation]
   Montant: [Total calculé] | [X] lignes

   └─ 📄 LIGNE [Code] - [Désignation]
      Compte: [N°] | Montant: [Total calculé] | [X] sous-rubriques

      └─ 📌 SOUS-RUBRIQUE [Code] - [Désignation]
         Compte: [N°] | Montant: [Valeur saisie] $
```

## Intégration avec le menu

Le nouveau sous-menu est disponible dans :

```
PARAMETRAGES
  ├─ Plan comptable
  ├─ Liste des tiers
  ├─ Journaux de saisie
  ├─ Liste des bailleurs
  ├─ Liste des projets
  └─ Gestion des budgets  ← NOUVEAU
```

## Notes techniques

1. **CASCADE DELETE** : La suppression d'un niveau supérieur supprime automatiquement tous les niveaux inférieurs
2. **Contraintes UNIQUE** : Les codes doivent être uniques dans leur contexte (ex: code de poste unique par budget)
3. **Triggers automatiques** : Les montants sont toujours à jour, pas besoin de recalcul manuel
4. **RLS activé** : Sécurité au niveau des lignes pour tous les utilisateurs authentifiés
