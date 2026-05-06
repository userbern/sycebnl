# Guide Complet du Projet SYCEBNL Accounting

## 📋 Vue d'ensemble

**SYCEBNL Accounting** est une application de gestion comptable desktop développée en **Flutter/Dart** pour Windows, Linux et macOS. Elle est conçue spécifiquement pour les ONG, associations et entités publiques au Bénin et en Afrique francophone.

### Architecture principale

L'application utilise **SQLite** avec une architecture à **deux bases de données** :

1. **Base de données locale** (`app_config.db`) : stocke la liste des fichiers récemment ouverts
2. **Fichiers utilisateur** (`.db`) : un fichier portable par organisation contenant toutes les données comptables

---

## 🗂️ Structure du projet

```
sycebnl_accounting/
├── lib/
│   ├── main.dart                    # Point d'entrée de l'application
│   ├── config/                      # Configuration globale
│   ├── models/                      # Modèles de données
│   ├── pages/                       # Pages/écrans de l'interface
│   ├── services/                    # Logique métier et base de données
│   └── utils/                       # Utilitaires réutilisables
├── assets/                          # Ressources (images, fichiers .env)
├── database/                        # Scripts de création de données exemple
├── android/, ios/, windows/, etc.   # Configuration des plateformes
└── Fichiers de documentation
```

---

## 📁 Fichiers principaux à la racine

### Documentation

- **`README.md`** : Documentation générale du projet, architecture, fonctionnalités
- **`DATABASE_STRUCTURE.md`** : Structure détaillée de toutes les tables SQLite
- **`TESTING_GUIDE.md`** : Guide pour les tests de l'application
- **`SECURITY.md`** : Politique de sécurité et gestion des vulnérabilités
- **`SUPABASE_INTEGRATION.md`** : Guide d'intégration avec Supabase (cloud)
- **`CHANGER_NOM_APPLICATION.md`** : Instructions pour renommer l'application

### Configuration

- **`pubspec.yaml`** : Dépendances Flutter (sqflite_ffi, crypto, file_picker, pdf, etc.)
- **`analysis_options.yaml`** : Règles de linting Dart
- **`netlify.toml`** : Configuration pour le déploiement web (si applicable)
- **`setup.ps1`** : Script PowerShell d'installation pour Windows
- **`gradle.properties`** : Configuration Android/Gradle

---

## 📦 Dossier `lib/` - Code source principal

### `main.dart` - Point d'entrée

**Rôle** : Initialise l'application Flutter

- Configure SQLite FFI pour les plateformes desktop
- Initialise la base de données de configuration (`AppConfigService`)
- Définit le thème Material Design 3
- Configure la localisation en français (fr_FR)
- Lance la page d'accueil (`WelcomePage`)

**Ce qui est configuré** :

```dart
- Localisation : français par défaut
- Thème : Material 3 avec couleur bleue
- Page de démarrage : WelcomePage
```

---

### `lib/models/` - Modèles de données

Chaque fichier représente une table de la base de données et fournit :

- Une classe Dart avec les propriétés
- Un constructeur `fromMap()` pour créer l'objet depuis SQLite
- Une méthode `toMap()` pour sauvegarder vers SQLite
- Des méthodes de validation si nécessaire

#### Fichiers principaux :

| Fichier                     | Description                                                      |
| --------------------------- | ---------------------------------------------------------------- |
| **`compte.dart`**           | Compte comptable du plan comptable (numéro, intitulé, type)      |
| **`tiers.dart`**            | Tiers (fournisseurs, clients, employés)                          |
| **`journal.dart`**          | Journaux comptables (Banque, Caisse, Achats, Ventes, OD)         |
| **`exercice.dart`**         | Exercice comptable (dates, durée, statut)                        |
| **`entite.dart`**           | Informations de l'organisation (dénomination, adresse, contacts) |
| **`budget.dart`**           | Budget global de l'entité                                        |
| **`poste_budgetaire.dart`** | Poste budgétaire (niveau 2)                                      |
| **`ligne_budgetaire.dart`** | Ligne budgétaire (niveau 3)                                      |
| **`sous_rubrique.dart`**    | Sous-rubrique budgétaire (niveau 4, le plus détaillé)            |
| **`projet.dart`**           | Projet financé                                                   |
| **`bailleur.dart`**         | Bailleur de fonds (donateur)                                     |
| **`saisie_comptable.dart`** | Écriture comptable (journal, date, pièce, lignes débit/crédit)   |
| **`user_session.dart`**     | Session utilisateur (stocke login, role, user_id)                |

**Exemple - `compte.dart`** :

- Contient `TypeCompte` (détail ou total)
- Contient `NatureCompte` (bilan actif, passif, charges, produits)
- Méthodes pour déterminer le sens normal (débit/crédit)
- Validation du numéro de compte selon la longueur configurée

---

### `lib/services/` - Logique métier

Les services encapsulent toute la logique d'accès aux données et les règles métier.

#### **`app_config_service.dart`**

**Rôle** : Gère la base de données de configuration locale (`app_config.db`)

- Créer/ouvrir la base locale dans `%LOCALAPPDATA%/SYCEBNL/`
- Stocker la liste des fichiers récemment ouverts
- Ajouter/supprimer/mettre à jour les fichiers récents
- Nettoyer les fichiers disparus

**Méthodes clés** :

```dart
initialize() // Créer la base locale si nécessaire
getRecentFiles() // Liste des 10 derniers fichiers
addRecentFile() // Ajouter un fichier à l'historique
removeRecentFile() // Supprimer de l'historique
cleanupMissingFiles() // Nettoyer les fichiers qui n'existent plus
```

#### **`database_service.dart`**

**Rôle** : Gère la connexion au fichier comptable (.db) et toutes les opérations CRUD

**Note** : Le service DB a été fusionné dans un seul fichier pour simplifier la maintenance et éviter les doublons d'API.

**Opérations principales** :

- **Connexion** : `connectToDatabase(path)`, `createNewDatabase(path)`
- **Configuration** : `getConfig()`, `updateConfig()`
- **Entité** : `getEntite()`, `updateEntite()`
- **Exercices** : `getExercices()`, `createExercice()`, `setActiveExercice()`
- **Plan comptable** : `getComptes()`, `createCompte()`, `updateCompte()`, `deleteCompte()`
- **Tiers** : `getTiers()`, `createTiers()`, `updateTiers()`, `deleteTiers()`
- **Journaux** : `getJournaux()`, `createJournal()`, `updateJournal()`, `deleteJournal()`
- **Budgets** : `getBudgets()`, `createBudget()`, hiérarchie complète (poste → ligne → sous-rubrique)
- **Projets/Bailleurs** : `getProjets()`, `getBailleurs()`, etc.
- **Utilisateurs** : `getUsers()`, `createUser()`, `verifyLogin()`

**Méthodes de protection** :

```dart
requiresPassword(path) // Vérifie si le fichier a un mot de passe
verifyLogin(login, password) // Authentification
hashPassword(password) // Hachage SHA-256
```

#### **`saisie_comptable_service.dart`**

**Rôle** : Gère les écritures comptables et les journaux de saisie

- Créer/récupérer une période de journal (mois + année)
- Créer des écritures comptables avec lignes débit/crédit
- Calculer les totaux et vérifier l'équilibre
- Clôturer une période
- Lettrer les comptes

**Workflow de saisie** :

1. Sélectionner un journal + période (année/mois)
2. Créer une `JournalPeriode` si elle n'existe pas
3. Saisir les écritures avec lignes équilibrées (débit = crédit)
4. Mettre à jour les totaux de la période
5. Éventuellement clôturer la période

#### **`auth_service.dart`** et **`auth_service_local.dart`**

**Rôle** : Gestion de l'authentification et des sessions

- Vérifier les identifiants
- Créer/détruire une session utilisateur
- Vérifier les permissions selon le rôle (admin/utilisateur)

#### **`permission_service.dart`**

**Rôle** : Contrôle d'accès basé sur les rôles

- Vérifier si l'utilisateur a les droits pour une action
- Gérer les permissions granulaires (créer, modifier, supprimer, consulter)

#### **`export_service.dart`**

**Rôle** : Exporter des données (PDF, Excel, CSV)

- Générer des rapports PDF (balance, grand livre)
- Exporter des tableaux au format CSV

---

### `lib/pages/` - Interface utilisateur

Chaque page est un widget Flutter `StatefulWidget` représentant un écran.

#### **Pages de démarrage et configuration**

| Fichier                         | Description                                                                                                        |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **`welcome_page.dart`**         | Page d'accueil : liste des fichiers récents + bouton "Créer nouveau fichier"                                       |
| **`new_file_wizard_page.dart`** | Assistant de création de fichier en 4 étapes (emplacement, identification entité, sécurité, paramètres comptables) |
| **`password_login_page.dart`**  | Page de connexion avec login/mot de passe                                                                          |
| **`database_setup_page.dart`**  | Configuration initiale de la base (ancien, remplacé par le wizard)                                                 |

#### **Page principale**

| Fichier              | Description                                                                                                                                                          |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`home_page.dart`** | Page principale après ouverture d'un fichier : sidebar avec menu, contenu dynamique selon l'onglet, gestion de la navigation. C'est le hub central de l'application. |

**Structure de `home_page.dart`** :

- **Sidebar gauche** : Menu avec sections (Paramètres, Référentiels, Journaux, Budgets, États)
- **Contenu central** : Change selon l'onglet sélectionné
- **Barre d'accès rapide** : Actions fréquentes (Plan comptable, Saisie, Journaux)
- **Gestion d'état** : Exercice actif, entité, périodes de saisie

#### **Pages de paramétrage**

| Fichier                               | Description                                                                                                                   |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| **`entite_identification_page.dart`** | Formulaire pour éditer les informations de l'entité (dénomination, adresse, contacts, etc.) - Utilise `FormWithEnterShortcut` |
| **`nouvel_exercice_page.dart`**       | Créer/gérer les exercices comptables                                                                                          |
| **`permissions_page.dart`**           | Gérer les droits d'accès des utilisateurs                                                                                     |

#### **Pages de référentiels**

| Fichier                         | Description                                                     |
| ------------------------------- | --------------------------------------------------------------- |
| **`plan_comptable_page.dart`**  | Afficher, créer, modifier, supprimer les comptes comptables     |
| **`liste_tiers_page.dart`**     | Gérer les tiers (fournisseurs, clients, prestataires)           |
| **`journaux_page.dart`**        | Gérer les codes journaux (Banque, Caisse, Achats, Ventes, etc.) |
| **`liste_bailleurs_page.dart`** | Gérer les bailleurs de fonds                                    |
| **`liste_projets_page.dart`**   | Gérer les projets financés                                      |

#### **Pages de budgets**

| Fichier                         | Description                                                                         |
| ------------------------------- | ----------------------------------------------------------------------------------- |
| **`gestion_budgets_page.dart`** | Liste des budgets avec hiérarchie complète (Budget → Poste → Ligne → Sous-rubrique) |
| **`budget_details_page.dart`**  | Détails d'un budget (inclus dans gestion_budgets_page.dart)                         |

#### **Pages de saisie comptable**

| Fichier                                   | Description                                                                  |
| ----------------------------------------- | ---------------------------------------------------------------------------- |
| **`journal_periode_selection_page.dart`** | Sélectionner un journal et une période (année/mois) pour commencer la saisie |
| **`saisie_ecriture_page.dart`**           | Formulaire de saisie d'une écriture comptable avec lignes débit/crédit       |
| **`journaux_de_saisie_page.dart`**        | Liste des écritures d'une période donnée (journal + mois)                    |

**Workflow de saisie** :

1. HomePage → "Saisie comptable"
2. `journal_periode_selection_page.dart` : choisir journal + période
3. `journaux_de_saisie_page.dart` : voir les écritures existantes + bouton "Nouvelle écriture"
4. `saisie_ecriture_page.dart` : saisir une nouvelle écriture
5. Retour à la liste des écritures

#### **Pages de consultation/états**

| Fichier                                  | Description                                 |
| ---------------------------------------- | ------------------------------------------- |
| **`balance_comptes_page.dart`**          | Balance des comptes (débits/crédits/soldes) |
| **`balance_resultat_page.dart`**         | Balance résultat (charges/produits)         |
| **`interrogations_page.dart`**           | Interrogations diverses                     |
| **`interrogations_lettrages_page.dart`** | Interrogations et lettrages                 |
| **`lettrages_page.dart`**                | Lettrage des comptes (rapprochement)        |

#### **Pages diverses**

| Fichier                     | Description                                                                   |
| --------------------------- | ----------------------------------------------------------------------------- |
| **`demo_data_page.dart`**   | Générer des données de démonstration pour tester                              |
| **`entite_form_page.dart`** | Formulaire d'entité (ancien, remplacé par entite_identification_page)         |
| **`entite_list_page.dart`** | Liste des entités (pas utilisé dans l'architecture actuelle à fichier unique) |
| **`login_page.dart`**       | Page de login (ancienne version)                                              |

---

### `lib/utils/` - Utilitaires

| Fichier                            | Description                                                                                                                 |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| **`form_enter_shortcut.dart`**     | Widget `FormWithEnterShortcut` qui permet de soumettre un formulaire avec la touche Entrée (ignore les champs multi-lignes) |
| **`FORM_ENTER_SHORTCUT_GUIDE.md`** | Documentation détaillée du widget                                                                                           |
| **`test_data.dart`**               | Données de test pour le développement                                                                                       |

**Utilisation de `FormWithEnterShortcut`** :

```dart
FormWithEnterShortcut(
  formKey: _formKey,
  onSubmit: _saveData,
  enabled: !_isSaving,
  child: Form(
    key: _formKey,
    child: Column(children: [...])
  ),
)
```

Permet de valider et soumettre le formulaire avec Entrée, améliore l'ergonomie pour la saisie rapide.

---

## 🗄️ Architecture de la base de données

### Base locale - `app_config.db`

**Emplacement** : `%LOCALAPPDATA%/SYCEBNL/app_config.db` (Windows)

**Table : `recent_files`**

```sql
CREATE TABLE recent_files (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_path TEXT NOT NULL UNIQUE,
  file_name TEXT NOT NULL,
  last_opened TEXT NOT NULL,
  has_password INTEGER DEFAULT 0
);
```

### Fichiers comptables - `*.db`

**Emplacement** : Choisi par l'utilisateur (portable)

**Tables principales** :

#### **Configuration et paramètres**

- `config` : Longueur des comptes (général, tiers)
- `exercice` : Exercices comptables (dates, durée, statut actif/clôturé)
- `utilisateur` : Utilisateurs avec login, password (hashé SHA-256), role (admin/utilisateur)
- `entite` : Informations de l'organisation (dénomination, adresse, contacts, devise)

#### **Référentiels**

- `compte` : Plan comptable (numéro, intitulé, type)
- `tiers` : Fournisseurs, clients, prestataires (nom, type, contact)
- `journal` : Journaux comptables (code, libellé, compte de trésorerie associé)
- `bailleur` : Bailleurs de fonds
- `projet` : Projets financés avec bailleur associé

#### **Budgets (hiérarchie à 4 niveaux)**

- `budget` : Budget global (nom, montant, exercice)
- `poste_budgetaire` : Poste de niveau 2 (code, libellé, budget parent)
- `ligne_budgetaire` : Ligne de niveau 3 (code, libellé, poste parent)
- `sous_rubrique` : Sous-rubrique de niveau 4 (code, libellé, ligne parent, compte associé)

#### **Comptabilité**

- `journaux_periodes` : Période de journal (journal + année + mois)
- `saisie_comptable` : En-tête d'écriture (journal, date, pièce, libellé)
- `ligne_saisie` : Lignes d'écriture (compte, montant débit/crédit, libellé)

**Relations importantes** :

- Une écriture (`saisie_comptable`) a plusieurs lignes (`ligne_saisie`)
- Une ligne référence un compte du plan comptable
- Une période (`journaux_periodes`) regroupe toutes les écritures d'un mois
- Un budget est découpé en postes → lignes → sous-rubriques

---

## 🔐 Sécurité

### Protection par mot de passe

- Optionnelle lors de la création du fichier
- Mot de passe hashé avec **SHA-256**
- Stocké dans la table `utilisateur`
- Vérification à l'ouverture du fichier

### Gestion des droits

- **Admin** : tous les droits (créer exercices, utilisateurs, modifier config)
- **Utilisateur** : saisie comptable, consultation des états
- Service `permission_service.dart` centralise les vérifications

### Soft delete

- Les suppressions ne détruisent pas les données
- Champ `deleted_at` marqué avec la date de suppression
- Permet de garder l'historique et de restaurer si nécessaire

---

## 🎯 Flux utilisateur principal

### 1. Démarrage de l'application

```
main.dart → Initialize SQLite FFI → AppConfigService.initialize() → WelcomePage
```

### 2. Ouverture d'un fichier existant

```
WelcomePage → Clic sur fichier récent ou "Ouvrir"
  → Si mot de passe → PasswordLoginPage
  → DatabaseService.connectToDatabase()
  → HomePage
```

### 3. Création d'un nouveau fichier

```
WelcomePage → "Créer nouveau fichier" → NewFileWizardPage
  Étape 1: Choisir emplacement (.db)
  Étape 2: Remplir identification entité
  Étape 3: [Optionnel] Activer mot de passe
  Étape 4: Paramètres comptables (exercice, longueur comptes)
  → DatabaseService.createNewDatabase()
  → HomePage
```

### 4. Navigation dans l'application

```
HomePage (menu sidebar)
  ├── Paramètres
  │   ├── Configuration entité
  │   ├── Nouvel exercice
  │   └── Gestion des droits
  ├── Référentiels
  │   ├── Plan comptable
  │   ├── Tiers
  │   ├── Codes journaux
  │   ├── Bailleurs
  │   └── Projets
  ├── Budgets
  │   └── Gestion des budgets
  ├── Journaux
  │   └── Saisie comptable → Période → Écritures → Nouvelle écriture
  └── États
      ├── Balance des comptes
      ├── Journaux de saisie
      └── Interrogations & Lettrages
```

### 5. Cycle de saisie comptable

```
1. Home → "Saisie comptable"
2. Sélectionner journal + période (année/mois)
3. Voir liste des écritures existantes
4. Cliquer "Nouvelle écriture"
5. Remplir formulaire:
   - Date opération
   - N° pièce
   - Libellé
   - Lignes débit/crédit (au moins 2)
   - Total débit = Total crédit (obligatoire)
6. Soumettre avec Entrée ou bouton "Enregistrer"
7. Retour à la liste des écritures
```

---

## 🛠️ Technologies utilisées

### Framework et langage

- **Flutter 3.7+** : Framework UI multi-plateforme
- **Dart 3.7+** : Langage de programmation

### Dépendances principales (pubspec.yaml)

```yaml
- flutter: SDK Flutter
- sqflite_common_ffi: SQLite pour desktop (Windows, Linux, macOS)
- path_provider: Accès aux répertoires système
- crypto: Hachage SHA-256 pour mots de passe
- file_picker: Sélection de fichiers
- window_manager: Gestion des fenêtres desktop
- pdf: Génération de PDF pour les rapports
```

### Base de données

- **SQLite** : Base de données embarquée, légère, portable
- **sqflite_common_ffi** : Version FFI de SQLite pour desktop

---

## 📝 Conventions de code

### Nommage

- **Classes** : PascalCase (`HomePage`, `DatabaseService`)
- **Fichiers** : snake_case (`home_page.dart`, `database_service.dart`)
- **Variables/méthodes** : camelCase (`_isLoading`, `getComptes()`)
- **Constantes** : camelCase avec `const` (`const maxExercices = 5`)

### Structure des pages

```dart
class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  // Variables d'état
  bool _isLoading = true;

  // Controllers
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Logique de chargement
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(...);
  }

  // Méthodes privées (_methode)
  Widget _buildWidget() { ... }
}
```

### Gestion d'état

- **setState()** : Pour l'état local à une page
- **Callbacks** : `onDataUpdated()` pour remonter des événements
- **Seed/refresh** : Incrémenter un compteur pour forcer le rebuild

---

## 🧪 Tests et débogage

### Données de démonstration

- `demo_data_page.dart` : Génère un jeu de données complet
- `test_data.dart` : Constantes pour les tests

### Debug

- Logs avec `print()` préfixés par des émojis :
  ```dart
  print('🔍 DEBUG: Chargement...');
  print('✅ DEBUG: Succès');
  print('❌ DEBUG: Erreur');
  print('⚠️ DEBUG: Attention');
  ```

### Testing Guide

- Voir `TESTING_GUIDE.md` pour la stratégie de tests

---

## 🚀 Déploiement

### Compilation Windows

```powershell
flutter build windows --release
```

Le `.exe` se trouve dans `build/windows/x64/runner/Release/`

### Compilation Linux

```bash
flutter build linux --release
```

### Compilation macOS

```bash
flutter build macos --release
```

---

## 📚 Pour aller plus loin

### Ajouter une nouvelle page

1. Créer `lib/pages/ma_nouvelle_page.dart`

```dart
import 'package:flutter/material.dart';

class MaNouvellePage extends StatefulWidget {
  const MaNouvellePage({super.key});

  @override
  State<MaNouvellePage> createState() => _MaNouvellePageState();
}

class _MaNouvellePageState extends State<MaNouvellePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ma nouvelle page')),
      body: const Center(child: Text('Contenu')),
    );
  }
}
```

2. Importer dans `home_page.dart`

```dart
import 'ma_nouvelle_page.dart';
```

3. Ajouter au menu sidebar dans `_buildMenuItem()`

```dart
_buildMenuItem('Ma page', Icons.my_icon, 99),
```

4. Gérer l'affichage dans `_getPageContent()`

```dart
case 99:
  return const MaNouvellePage();
```

### Ajouter une table à la base de données

1. Créer le modèle dans `lib/models/mon_modele.dart`
2. Ajouter la table dans `DatabaseService.createTableSchema()`
3. Ajouter les méthodes CRUD dans `DatabaseService`
4. Créer une page pour gérer les données

### Ajouter un champ à une table existante

1. Modifier le modèle (`lib/models/`)
2. Ajouter une migration dans `DatabaseService`

```dart
if (version < 2) {
  await db.execute('ALTER TABLE ma_table ADD COLUMN nouveau_champ TEXT');
}
```

3. Incrémenter le numéro de version de la base

---

## 💡 Conseils pour continuer le projet

### Points d'attention

1. **Toujours vérifier que la base est ouverte** avant d'exécuter une requête (`ensureDatabaseOpen()`)
2. **Utiliser le soft delete** : ne jamais supprimer physiquement, marquer `deleted_at`
3. **Valider les formulaires** avant l'enregistrement
4. **Gérer les erreurs** avec try-catch et afficher des messages utilisateur
5. **Tester avec des données réelles** et des cas limites

### Améliorations possibles

- [ ] Ajouter l'export Excel pour tous les états
- [ ] Implémenter l'impression directe des rapports
- [ ] Ajouter des graphiques (charts) pour les budgets
- [ ] Créer un système de sauvegarde automatique
- [ ] Implémenter la synchronisation cloud avec Supabase
- [ ] Ajouter un système d'audit trail (log toutes les modifications)
- [ ] Créer des rôles personnalisés (au-delà d'admin/utilisateur)
- [ ] Ajouter la gestion multi-devises
- [ ] Implémenter l'import/export au format standard (FEC, etc.)

### Ressources utiles

- Documentation Flutter : https://flutter.dev/docs
- Documentation Dart : https://dart.dev/guides
- SQLite : https://www.sqlite.org/docs.html
- Material Design 3 : https://m3.material.io/

---

## 📞 Support

Pour toute question ou problème :

1. Consulter la documentation dans le dossier racine
2. Vérifier les commentaires dans le code
3. Chercher dans les issues GitHub (si le projet est versionné)
4. Contacter l'équipe de développement

---

**Bonne continuation sur le projet SYCEBNL Accounting ! 🚀**
