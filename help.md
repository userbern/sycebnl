# Aide - Creation et ouverture d'un fichier comptable

Ce document explique concretement ce que fait l'application dans 2 cas:

- quand on clique sur **"Creer un nouveau fichier"**
- quand on clique sur **"Ouvrir un fichier existant"**

## 1) Quand on cree un nouveau fichier

Point d'entree:

- Ecran: `lib/pages/welcome_page.dart`
- Action: bouton **"Creer un nouveau fichier"**
- Effet: ouverture de l'assistant `NewFileWizardPage`

### Etape A - Choix du fichier

Dans `lib/pages/new_file_wizard_page.dart`:

- L'application ouvre un dialogue "Enregistrer sous" via `FilePicker.platform.saveFile(...)`.
- Extension imposee: `.db`.
- Si aucun chemin n'est choisi, on ne peut pas continuer.

### Etape B - Saisie des informations entite

L'assistant collecte les informations metier principales:

- denomination sociale (obligatoire)
- sigle, domaine, forme juridique
- adresse et contacts
- references administratives/fiscales
- devise

Validation immediate:

- si la denomination est vide, l'assistant bloque l'avance et affiche un message d'erreur.

### Etape C - Securite (optionnelle)

Si l'utilisateur active la protection:

- login admin (par defaut: `admin`)
- mot de passe
- confirmation du mot de passe

Validations:

- mot de passe obligatoire si protection activee
- mot de passe et confirmation doivent correspondre

### Etape D - Parametres comptables

L'assistant demande:

- code exercice
- date debut / date fin
- duree (calculee)
- longueur compte general
- longueur compte tiers

Validations finales:

- chemin fichier obligatoire
- dates exercice obligatoires
- duree exercice <= 18 mois

### Etape E - Creation technique en base

Quand on clique **"Creer le fichier"**, `DatabaseService.createDatabase(...)` est appelee.

Ce que l'application fait techniquement:

- initialise SQLite FFI (desktop)
- verifie que le fichier n'existe pas deja
- cree le dossier parent si necessaire
- cree la base SQLite et les tables metier
- insere les modules de permissions de base (`notre_entite`, `parametrages`, `traitements`, `edition`)
- insere l'entite
- insere le premier exercice
- insere la configuration des longueurs de comptes
- si securite activee:
- hash du mot de passe en SHA-256
- creation de l'utilisateur admin
- attribution des droits complets sur les modules

### Etape F - Retour vers l'application

Si la creation reussit:

- l'assistant retourne le chemin du fichier cree a `WelcomePage`
- `WelcomePage` enregistre ce fichier dans les recents (`AppConfigService.addRecentFile`)
- puis redirige vers `HomePage`

En cas d'erreur:

- un `SnackBar` rouge affiche l'erreur
- l'utilisateur reste dans l'assistant

## 2) Quand on ouvre un fichier existant

Point d'entree:

- Ecran: `lib/pages/welcome_page.dart`
- Action: bouton **"Ouvrir un fichier existant"**

### Etape A - Selection du fichier

L'application ouvre un dialogue de selection:

- `FilePicker.platform.pickFiles(...)`
- filtres sur extension `.db`

Si l'utilisateur annule:

- rien ne se passe

### Etape B - Verification du fichier

Dans `_openFile(filePath)`:

- verification que le fichier existe physiquement
- si le fichier est introuvable:
- message "Le fichier n'existe plus"
- suppression de l'entree dans les recents
- rechargement de la liste des recents

### Etape C - Verification de protection par mot de passe

L'application appelle `DatabaseService.requiresPassword(filePath)`:

- elle regarde s'il existe au moins un utilisateur dans la table `utilisateur`
- si oui: le fichier est considere protege
- si non: ouverture directe

### Etape D1 - Cas fichier non protege

Flux:

- `DatabaseService.openDatabase(filePath)`
- ajout/mise a jour dans les recents
- redirection vers `HomePage`

### Etape D2 - Cas fichier protege

Flux:

- ouverture de `PasswordLoginPage(filePath)`
- saisie login + mot de passe
- ouverture du fichier via `DatabaseService.openDatabase(filePath)`
- appel `AuthService.login(login, password)` (service d'authentification)
- verification du hash mot de passe + chargement des permissions utilisateur

Si authentification OK:

- retour d'une `UserSession` a `WelcomePage`
- ajout/mise a jour dans les recents
- redirection vers `HomePage`

Si authentification KO:

- message "Login ou mot de passe incorrect"
- effacement du champ mot de passe
- l'utilisateur reste sur l'ecran de connexion

### Etape D3 - Note technique importante

Etat actuel du code (a harmoniser):

- `requiresPassword(filePath)` verifie la table `utilisateur`
- `PasswordLoginPage` charge la liste des logins depuis la table `users`

Consequence:

- le flux fonctionnel reste correct dans la plupart des cas
- mais il existe une incoherence technique entre les tables utilisateurs consultees selon l'etape

## 3) Gestion des fichiers recents (commune aux 2 cas)

Service utilise: `lib/services/app_config_service.dart`

Comportement:

- stockage dans `app_config.db` local
- table `recent_files`
- garde les 10 derniers fichiers (tri date d'ouverture)
- nettoyage automatique des chemins qui n'existent plus
- memorise si le fichier est protege (`has_password`)

## 4) Resume simple

- **Creer un fichier**: assistant -> validations -> creation SQLite + donnees initiales -> ajout recents -> ouverture `HomePage`.
- **Ouvrir un fichier**: selection `.db` -> verification existence -> check mot de passe -> (login si necessaire) -> ajout recents -> ouverture `HomePage`.

## 5) Comment sont faites les pages du menu Parametrages

Le menu **PARAMETRAGES** est defini dans `lib/pages/home_page.dart` et pointe vers les index suivants:

- index `4`: `PlanComptablePage`
- index `5`: `ListeTiersPage`
- index `6`: `JournauxPage`
- index `7`: `ListeBailleursPage`
- index `8`: `ListeProjetsPage`
- index `9`: `GestionBudgetsPage`

Dans `_buildContentPage()` de `HomePage`, ces index chargent directement les widgets correspondants dans la zone centrale (sans changer de route principale).

### 5.1 Structure commune des pages Parametrages

Ces pages suivent globalement le meme schema:

- `StatefulWidget` + `initState()` pour charger les donnees initiales.
- Appels aux services (`DatabaseService` ou `AuthService`) pour recuperer/modifier les donnees.
- Zone de recherche/filtres/tri en haut.
- Liste ou tableau des enregistrements.
- Actions CRUD via boutons et boites de dialogue (`showDialog`).
- Notifications utilisateur via `SnackBar` (succes/erreur).

### 5.2 Plan comptable (`plan_comptable_page.dart`)

Comment c'est fait:

- Charge la configuration du fichier (`longueur_compte_general`) puis la liste des comptes.
- Gere des filtres metier:
- recherche texte
- filtre par `NatureCompte`
- filtre par `TypeCompte`
- pagination locale (`_itemsPerPage`, `_currentPage`).
- Creation/modification dans un dialogue avec formulaire valide.
- Le numero de compte est complete automatiquement selon la longueur configuree (pour les comptes detail).
- Les erreurs de validation ou de persistence sont affichees en `SnackBar`.

### 5.3 Liste des tiers (`liste_tiers_page.dart`)

Comment c'est fait:

- Charge simultanement la liste des tiers et la liste des comptes.
- Filtrage par:
- texte (numero/intitule)
- type de tiers
- tri (numero ou intitule)
- Dans le dialogue de creation, le type de tiers est propose automatiquement selon le prefixe du compte:
- `41` client
- `40` fournisseur
- `52` banque
- `57` caisse
- `47` autre
- `42` salarie
- Le compte collectif est aussi derive quand possible a partir du numero saisi.

### 5.4 Codes journaux (`journaux_page.dart`)

Comment c'est fait:

- Charge journaux + comptes au demarrage.
- Filtres disponibles:
- recherche code/intitule
- type de journal (financier/non financier)
- statut (actif/inactif)
- Ajout/modification via `JournalDialog`.
- Raccourci clavier `Ctrl+N` pour ouvrir le formulaire de creation.
- Suppression avec confirmation, puis message metier adapte si journal deja utilise par des ecritures.

### 5.5 Liste des bailleurs (`liste_bailleurs_page.dart`)

Comment c'est fait:

- Charge la liste des bailleurs via `AuthService.getBailleurs()`.
- Recherche et tri par `sigle`/`designation`.
- Filtre actif/inactif prevu dans l'ecran.
- Gestion des droits (creation/modification/suppression) selon la session utilisateur quand disponible.
- Raccourci `Ctrl+N` pour creation rapide.

### 5.6 Liste des projets (`liste_projets_page.dart`)

Comment c'est fait:

- Charge les projets avec bailleurs associes (`getProjetsWithBailleur`) + referentiel bailleurs.
- Recherche sur code/designation.
- Filtrage actif/inactif + tri par code/designation.
- Dialogue de creation/modification avec selection des bailleurs.
- Suppression avec confirmation et rechargement de la liste apres succes.
- Controle des permissions create/update/delete selon `userSession`.

### 5.7 Gestion des budgets (`gestion_budgets_page.dart`)

Comment c'est fait:

- Depend de l'exercice actif passe depuis `HomePage` (`exerciceId`).
- Si aucun exercice n'est selectionne, l'ecran bloque et affiche une erreur.
- Charge les budgets detaillees de l'exercice + la liste des projets.
- Barre de recherche (code projet, designation, sigle bailleur).
- Creation via dialogue dedie (`_CreateBudgetDialog`).
- Acces au detail budget en cliquant une ligne (navigation interne vers details).
- Suppression avec confirmation, puis rechargement des donnees.
- Permissions appliquees (creation/modification/suppression) si session utilisateur fournie.

### 5.8 En resume architecture Parametrages

- `HomePage` orchestre l'affichage.
- Chaque page encapsule son propre etat (filtres, tri, chargement).
- Les services centralisent les acces base et la logique metier.
- Les formulaires de creation/modification sont principalement geres dans des dialogues.
- Les retours utilisateur sont immediats via `SnackBar` et rafraichissement des listes.

## 6) Guide detaille, ecran par ecran (comme en utilisation reelle)

Cette section decrit exactement ce que l'utilisateur fait et ce qu'il voit.

### 6.1 Plan comptable - creer, afficher, modifier, supprimer

Ouverture de l'ecran:

- Menu `PARAMETRAGES` -> `Plan comptable`.

Creation d'un compte:

- Cliquer sur `Nouveau compte (Ctrl+N)` ou utiliser `Ctrl+N`.
- Un dialogue `Nouveau compte` s'ouvre.
- Champs affiches dans le formulaire:
- `N° Compte *`
- `Intitule *`
- `Type`
- `Nature *` (auto-detectee depuis le numero, mais ajustable)
- `Description`
- case `Rattachement de tiers`
- Validation obligatoire des champs marqués `*`.
- En creation rapide, la touche `Entree` permet d'ajouter et enchainer la saisie.

Affichage (tableau):

- Colonnes du tableau:
- `N° Compte`
- `Intitule`
- `Type`
- `Nature`
- `Actions`
- Outils en haut:
- recherche (`Rechercher`)
- filtre `Nature`
- filtre `Type`
- pagination (`Page`, `Par page`)

Actions par ligne:

- `Modifier` (icone crayon): ouvre `Modifier le compte` avec les champs pre-remplis.
- `Supprimer` (icone poubelle): demande confirmation puis suppression.
- Si le compte est utilise ailleurs, la suppression est bloquee avec message explicite.

### 6.2 Liste des tiers - creer, afficher, modifier, supprimer

Ouverture de l'ecran:

- Menu `PARAMETRAGES` -> `Liste des tiers`.

Creation d'un tiers:

- Cliquer sur `Nouveau tiers (Ctrl+N)` ou `Ctrl+N`.
- Le dialogue `Nouveau tiers` s'ouvre.
- Champs du formulaire:
- `N° compte *`
- `Intitule *`
- `Type *`
- `Compte collectif *`
- `NIF`
- `Adresse`
- Bouton `+` pour creer un nouveau compte collectif sans quitter le dialogue.
- A la saisie du numero de compte:
- le type de tiers est propose automatiquement selon le prefixe (`40`, `41`, `42`, `47`, `52`, `57`)
- un compte collectif peut etre propose automatiquement

Affichage (tableau):

- Colonnes:
- `N° Compte`
- `Intitule`
- `Type`
- `Compte Collectif`
- `Actions`
- Outils en haut:
- recherche `Rechercher un tiers`
- filtre `Type de tiers`
- tri `Trier par`

Actions par ligne:

- `Modifier`: ouvre le dialogue avec les donnees du tiers.
- `Supprimer`: confirmation puis suppression.

### 6.3 Codes journaux - creer, afficher, modifier, supprimer

Ouverture de l'ecran:

- Menu `PARAMETRAGES` -> `Codes journaux`.

Creation d'un journal:

- Cliquer sur `Nouveau (Ctrl+N)` ou `Ctrl+N`.
- Le dialogue `Nouveau journal` s'ouvre.
- Champs du formulaire:
- `Code *`
- `Intitule *`
- `Type *` (financier ou non financier)
- `Compte de Tresorerie *` (obligatoire si journal financier)
- Le compte de tresorerie est choisi via champ autocomplete (numero + intitule).

Affichage (tableau):

- Colonnes:
- `Code`
- `Intitule`
- `Type`
- `Saisie Analytique`
- `Actions`
- Outils en haut:
- recherche code/intitule
- filtre `Type de journal`
- filtre `Statut`

Actions par ligne:

- `Modifier` dans le menu d'actions.
- `Supprimer` dans le menu d'actions.
- Si le journal contient deja des ecritures, suppression refusee avec message metier.

### 6.4 Liste des bailleurs - creer, afficher, modifier, supprimer

Ouverture de l'ecran:

- Menu `PARAMETRAGES` -> `Liste des bailleurs`.

Creation d'un bailleur:

- Cliquer sur `Nouveau bailleur (Ctrl+N)` ou `Ctrl+N`.
- Le dialogue `Nouveau bailleur` s'ouvre.
- Champs du formulaire:
- `Sigle *`
- `Designation *`
- Bouton de validation `Creer`.

Affichage (tableau style liste):

- Colonnes:
- `Sigle`
- `Designation`
- `Actions`
- Outils en haut:
- recherche `Rechercher un bailleur`
- tri `Trier`
- filtre de statut `Afficher` (actifs/inactifs/tous)

Actions par ligne:

- `Modifier` (icone crayon): ouvre `Modifier le bailleur`.
- `Supprimer` (icone poubelle): confirmation puis suppression.

### 6.5 Liste des projets - creer, afficher, modifier, supprimer

Ouverture de l'ecran:

- Menu `PARAMETRAGES` -> `Liste des projets`.

Creation d'un projet:

- Cliquer sur `Nouveau projet` ou utiliser `Ctrl+N`.
- Le dialogue `Nouveau projet` s'ouvre.
- Champs du formulaire:
- `Code *`
- `Designation *`
- `Date debut *`
- `Date fin *`
- section `Bailleurs *` avec:
- selection d'un ou plusieurs bailleurs
- bouton `Nouveau` pour creer un bailleur a la volee

Affichage (tableau style liste):

- Colonnes:
- `Code`
- `Designation`
- `Bailleurs`
- `Actions`
- Outils en haut:
- recherche projet
- tri `Trier par`
- filtre `Statut`

Actions par ligne:

- `Modifier`.
- `Supprimer` avec confirmation.

### 6.6 Gestion des budgets - creer budget, afficher tableau, modifier/supprimer

Ouverture de l'ecran:

- Menu `PARAMETRAGES` -> `Gestion des budgets`.
- Necessite un exercice actif (`exerciceId`).

Creation d'un budget:

- Cliquer sur `Nouveau budget` ou `Ctrl+N`.
- Le dialogue `Creer un nouveau budget` s'ouvre.
- Champs du formulaire:
- `Projet *`
- `Bailleur *` (charge selon le projet choisi)
- Bouton `Creer` active seulement quand les 2 champs sont renseignes.

Affichage (tableau principal):

- Colonnes:
- `PROJET`
- `BAILLEUR`
- `ACTIONS`
- Outils en haut:
- recherche `Rechercher un budget...`
- bouton `Rafraichir`

Actions par ligne:

- `Modifier` ouvre le detail du budget (`BudgetDetailsPage`).
- `Supprimer` demande confirmation puis supprime.

Dans le detail budget (`BudgetDetailsPage`):

- gestion hierarchique avec actions `Modifier` / `Supprimer` sur:
- postes budgetaires
- lignes budgetaires
- sous-rubriques
- formulaires dedies pour creation/modification:
- poste: `Intitule *`
- ligne: `Code *`, `Intitule *`
- sous-rubrique: `Intitule *`, `Montant`, `Compte`

## 7) Roles detailles des fichiers `lib/services`

Cette section explique le role precis de chaque service, ce qu'il centralise, et dans quels cas il doit etre utilise.

### 7.1 `app_config_service.dart` (configuration locale application)

Role principal:

- Gere une base locale technique `app_config.db` (separee du fichier comptable `.db`).
- Memorise les fichiers recents ouverts/crees.

Responsabilites:

- Initialisation de la base de config dans le dossier applicatif (`ApplicationSupportDirectory/SYCEBNL`).
- Creation et maintenance de la table `recent_files`.
- Ajout/mise a jour d'entrees recents (`addRecentFile`) avec horodatage.
- Lecture des 10 derniers fichiers (`getRecentFiles`).
- Nettoyage automatique des chemins inexistants (`cleanupMissingFiles`).

Quand l'utiliser:

- Au demarrage de l'application pour charger l'ecran d'accueil.
- Apres creation/ouverture d'un fichier comptable pour actualiser l'historique.

### 7.2 `database_service.dart` (coeur infrastructure SQLite)

Role principal:

- C'est le service de base de donnees de reference (connexion, creation schema, migrations).

Responsabilites:

- Initialisation SQLite FFI pour desktop.
- Creation d'un nouveau fichier comptable (`createDatabase`) avec:
- creation complete des tables metier
- insertion modules de permissions de base
- insertion entite/exercice/config de depart
- creation optionnelle du compte admin + droits complets
- Ouverture/connexion d'un fichier existant (`connectToDatabase`).
- Exposition de l'instance DB singleton (`database`) et etat de connexion (`isConnected`).
- Migrations automatiques a l'ouverture (evolution schema existant):
- ajout/ajustement colonnes et tables
- tables de saisie comptable (`journaux_periodes`, `ecritures`, `ventilations_analytiques`)
- normalisation de `date_comptable`
- Fonctions utilitaires de securite (`hashPassword`, `verifyPassword`).

Quand l'utiliser:

- Dans toute logique qui a besoin d'une connexion DB fiable.
- Pour les operations systeme de cycle de vie du fichier comptable (creer, ouvrir, fermer, migrer).

### 7.3 `database_service.dart` (service DB fusionne)

Role principal:

- Fournit une API metier orientee application et centralise désormais toute la logique DB.

Responsabilites:

- Verification login et besoin de mot de passe (`verifyLogin`, `requiresPassword`).
- Methodes metier de haut niveau: entite, exercices, utilisateurs, etc.
- `ensureDatabaseOpen()` pour tenter une reouverture si la connexion est perdue.
- Point unique pour le code applicatif qui attend les signatures historiques compatibles.

Quand l'utiliser:

- Dans les ecrans/fonctions qui consomment les operations DB de l'application.
- Comme couche unique pour eviter les doublons d'implémentation.

### 7.4 `auth_service.dart` (alias de compatibilite)

Role principal:

- Ne contient pas de logique: il re-exporte `auth_service_local.dart`.

Responsabilites:

- Maintenir la compatibilite des imports existants (`import 'auth_service.dart'`).
- Eviter de casser le code lors du renommage/migration du service d'authentification.

Quand l'utiliser:

- Dans le code existant qui importe deja `auth_service.dart`.
- Si vous voulez limiter les changements massifs d'imports.

### 7.5 `auth_service_local.dart` (service metier principal: auth + CRUD)

Role principal:

- C'est le service metier central cote donnees pour une grande partie des ecrans.

Responsabilites (par domaine):

- Authentification/session:
- login, verification mot de passe hash
- determination admin (premier utilisateur)
- logout, lecture permissions
- Utilisateurs:
- creation, lecture, mise a jour, suppression logique
- Entites:
- CRUD complet entite
- Parametrages comptables:
- CRUD comptes
- CRUD tiers
- CRUD journaux
- Referentiels projet:
- CRUD bailleurs
- CRUD projets + association projets/bailleurs
- Budgets:
- creation/suppression budgets
- lecture budgets enrichis
- gestion postes budgetaires, lignes budgetaires, sous-rubriques
- calculs de montants agreges (ligne, poste, budget)
- Permissions:
- lecture modules
- lecture permissions utilisateur
- mise a jour fine des droits CRUD par module
- Exercice actif:
- recuperation de l'exercice courant

Quand l'utiliser:

- Dans les pages `PARAMETRAGES` et ecrans de gestion qui manipulent les entites metier.
- Comme service principal applicatif pour encapsuler les requetes SQL et regles metier.

### 7.6 `permission_service.dart` (helpers de droits)

Role principal:

- Traduit les permissions utilisateur en verifications simples pour l'UI et les actions.

Responsabilites:

- Charger les droits d'un module pour un utilisateur (`getModulePermissions`).
- Fournir des helpers de decision:
- `canRead`, `canCreate`, `canEdit`, `canDelete`
- `hasAnyPermission`

Quand l'utiliser:

- Dans les pages pour afficher/masquer boutons et actions selon les droits.
- Pour centraliser la logique d'autorisation cote interface.

### 7.7 `saisie_comptable_service.dart` (journalisation comptable et ventilations)

Role principal:

- Encapsule toute la logique de saisie des ecritures comptables par journal/periode.

Responsabilites:

- Creation/recuperation des periodes de journal (`journaux_periodes`).
- Lecture des ecritures par periode et par couple (journal, annee, mois, exercice).
- CRUD ecritures (`addLigneEcriture`, `updateEcriture`, `deleteEcriture`).
- Calcul des totaux de saisie (debit, credit, solde, equilibre).
- Calcul du prochain numero d'enregistrement.
- Gestion des ventilations analytiques:
- ajout/sauvegarde
- lecture avec jointures enrichies (projet, bailleur, poste, ligne)
- suppression + mise a jour du flag `is_ventilee`
- Synchronisation des cumuls de periode (`updatePeriodeTotaux`).

Quand l'utiliser:

- Dans les ecrans de saisie comptable et de ventilation analytique.
- Pour garantir la coherence des totaux et de l'etat d'equilibre des journaux.

### 7.8 `export_service.dart` (exports documentaires PDF/Excel)

Role principal:

- Genere les sorties bureautiques a partir des donnees affichees (etats comptables).

Responsabilites:

- Generation PDF mise en page (`pdf/widgets`) avec sections metier (entite, periode, tableau).
- Preview + sauvegarde PDF locale avec feedback utilisateur (`SnackBar`).
- Generation de fichiers Excel (`excel`) avec structure formatee et donnees de balance.
- Formatting des valeurs et metadonnees d'export.

Quand l'utiliser:

- Depuis les ecrans de consultation/edition qui proposent telechargement ou impression d'etats.
- Pour standardiser le rendu des exports entre pages.

### 7.9 Vue d'ensemble (qui fait quoi rapidement)

- Infrastructure DB: `database_service.dart`
- Metier applicatif principal (auth + CRUD): `auth_service_local.dart`
- Alias de compatibilite Auth: `auth_service.dart`
- Gestion des droits UI: `permission_service.dart`
- Saisie comptable detaillee: `saisie_comptable_service.dart`
- Exports PDF/Excel: `export_service.dart`
- Config locale (recents): `app_config_service.dart`

## 7) Raccourcis clavier utiles (Parametrages)

- `Ctrl+N` fonctionne sur:
- plan comptable
- liste des tiers
- codes journaux
- liste des bailleurs
- liste des projets
- gestion des budgets
- `Echap` ferme certains dialogues (selon l'ecran).

## 8) Regle detaillee de choix de la nature (Plan comptable)

Tu as raison: la nature n'est pas seulement "choisie a la main", elle est aussi calculee automatiquement depuis le numero de compte.

Ou c'est code:

- `lib/models/compte.dart`
- fonction: `calculateNatureFromNumeroCompte(String numeroCompte)`

Logique appliquee (priorite aux 2 premiers chiffres, puis au 1er chiffre):

- `40` -> `Bilan (Fournisseurs)`
- `41` -> `Bilan (Adherents - clients usagers)`
- `42` -> `Bilan (Personnel)`
- `43` -> `Bilan (Organismes sociaux)`
- `44` -> `Bilan (Etat et collectivites publiques)`
- `45`, `46`, `47`, `48`, `49` -> `Bilan (Autres tiers)`
- `52` -> `Bilan (Banque)`
- `57` -> `Bilan (Caisse)`
- `50`, `51`, `53`, `55`, `56`, `58`, `59` -> `Bilan (Autres tresoreries)`
- `80`, `82`, `84`, `86`, `88` -> `Produits H.A.O.`
- `81`, `83`, `85`, `87`, `89` -> `Charges H.A.O.`

Si aucune regle a 2 chiffres ne match:

- commence par `1` -> `Bilan (ressources durables)`
- commence par `2` -> `Bilan (Actif immobilise)`
- commence par `3` -> `Bilan (stocks)`
- commence par `6` -> `Charges A.O.`
- commence par `7` -> `Produits A.O.`
- commence par `8` -> pair = `Produits H.A.O.`, impair = `Charges H.A.O.`
- commence par `9` -> `Engagements hors bilan`

Comportement dans le formulaire de creation/modification de compte:

- quand on saisit le numero, la nature est pre-remplie automatiquement.
- l'utilisateur peut ensuite ajuster la nature via la liste deroulante si besoin.

## 9) Les autres menus (hors Parametrages), en mode detail utilisateur

### 9.1 Notre entite

`Identification` (`entite_identification_page.dart`):

- ecran formulaire d'identification de l'entite.
- champs de type `TextFormField` (denomination, contacts, references, etc.).
- bouton principal de sauvegarde en bas (`ElevatedButton.icon`).
- objectif: mettre a jour les informations institutionnelles de l'entite active.

`Autorisations d'acces` (`permissions_page.dart`):

- panneau gauche: liste des utilisateurs.
- panneau droit: tableau des modules avec cases de permissions.
- permissions gerees par module:
- `lecture`
- `ajout`
- `modification`
- `suppression`
- bouton flottant `Enregistrer` pour sauvegarder les droits.

### 9.2 Traitements

`Saisie comptable` (`journal_periode_selection_page.dart`):

- formulaire de preparation avec 2 listes:
- `Journal`
- `Mois de saisie`
- bouton principal pour creer/ouvrir la periode de saisie.
- si la periode n'existe pas, elle est creee automatiquement avant ouverture.

`Journaux de saisie` (`journaux_de_saisie_page.dart`):

- ecran tableau avec filtres:
- recherche code journal
- recherche intitule journal
- filtre `Mois de saisie`
- filtre `Annee`
- tableau (`DataTable`) des lignes journal/periode.
- clic sur une ligne: ouvre la saisie de la periode correspondante.

`Interrogations & Lettrages`:

- actuellement routee vers un placeholder depuis `HomePage` (ecran de transition).

### 9.3 Exercices

`Nouvel exercice` (`nouvel_exercice_page.dart`):

- formulaire avec champs:
- `Annee de l'exercice *`
- `Date de debut *`
- `Date de fin *`
- option `Reporter les soldes de l'exercice precedent`
- dates choisies via boites de dialogue jour/mois/annee
- bouton `Creer l'exercice` avec validation et confirmation

Ce que les exercices ont en commun (donnees conservees et partagees):

- `entite` (identite de l'organisation)
- `config` (longueur comptes)
- `compte` (plan comptable)
- `tiers`
- `journal` (codes journaux)
- `projet`
- `bailleur`
- `projet_bailleur`
- utilisateurs/permissions

Ce qui est propre a un exercice (donnees cloisonnees):

- `budget` est lie a `exercice_id`
- toute la hierarchie budgetaire depend du budget de cet exercice:
- `poste_budgetaire` -> `ligne_budgetaire` -> `sous_rubrique`
- `journaux_periodes` est lie a `exercice_id` (journal + mois + annee + exercice)
- `ecritures` sont liees a `journaux_periodes`
- `ventilations_analytiques` sont liees aux `ecritures`

Consequence metier importante:

- un journal de saisie d'un exercice N ne se retrouve pas dans l'exercice N+1
- les ecritures d'un exercice restent dans cet exercice
- en revanche, les referentiels (plan comptable, tiers, projets, bailleurs, codes journaux) sont reutilises d'un exercice a l'autre

Option `Reporter les soldes de l'exercice precedent`:

- cette option sert a repartir de l'exercice precedent lors de la creation du nouveau
- l'idee metier est de transferer les soldes de cloture vers l'ouverture du nouvel exercice

### 9.4 Edition

`Balance des comptes` (`balance_comptes_page.dart`):

- ecran de preparation de la balance avec plusieurs filtres:
- type d'etat: `General`, `Tiers`, `Analytique`, `Tiers & Analytique`
- periode: `Date debut` / `Date fin`
- filtre comptes: `Compte debut` / `Compte fin`
- option: inclure ou non les comptes sans mouvement
- en mode analytique: selection `Projet` puis `Bailleur(s)`
- bouton d'action `Afficher la balance`

Ce que la balance prend en compte:

- l'exercice actif (ou celui passe par `exerciceId`)
- les dates doivent etre dans les bornes de cet exercice
- les filtres de comptes, et eventuellement projet/bailleurs

Ce que la balance ne melange pas:

- elle ne doit pas consolider des ecritures d'autres exercices
- les periodes journaux et ecritures etant rattachees a `exercice_id`, le calcul reste dans le perimetre de l'exercice cible

Sortie:

- apres validation, la page ouvre `BalanceResultatPage` avec tous les parametres choisis
- acces possible ensuite a la `Balance resultat` (lecture analytique du resultat)

`Grand livre`:

- actuellement placeholder dans `HomePage`.

`Journal`:

- actuellement placeholder dans `HomePage`.
