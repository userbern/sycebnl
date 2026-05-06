# Synthese du travail realise - SYCEBNL Accounting

Date de mise a jour: 2026-03-10

## 1) Description detaillee du projet

**SYCEBNL Accounting** est une application de gestion comptable destinee aux ONG, associations et entites publiques. Le projet vise a couvrir le cycle comptable complet, depuis la creation d'un fichier comptable jusqu'a la production des etats et exports, en restant simple a deployer (fichiers SQLite portables) et facile a utiliser pour des equipes non techniques.

Le positionnement du projet est clair:

- Outil metier specialise comptabilite associative/ONG.
- Fonctionnement principalement local/offline avec fichiers de donnees transportables.
- Interface desktop prioritaire, tout en conservant la compatibilite Flutter multi-plateforme.

Les besoins metiers adresses:

- Structurer et securiser les donnees d'une entite.
- Organiser la comptabilite par exercices, journaux, comptes et tiers.
- Suivre les projets, bailleurs et budgets de facon coherente.
- Permettre la saisie, la consultation, le lettrage et l'edition des donnees.
- Faciliter les sorties de donnees (PDF/Excel/CSV).

## 2) Objectifs fonctionnels

Objectifs principaux couverts par le code actuel:

- Creation et ouverture de fichiers comptables (`.db`) par entite.
- Gestion d'un historique de fichiers recents via `app_config.db`.
- Parametrage de base de l'entite (identite, contacts, references, devise).
- Gestion des exercices comptables et de l'exercice actif.
- Gestion des referentiels comptables (plan comptable, tiers, journaux).
- Gestion du perimetre projet/bailleurs/budgets.
- Saisie comptable par journal et periode (annee/mois) avec calcul d'equilibre debit/credit.
- Consultation de balances et de modules d'interrogation/lettrage.
- Gestion des autorisations et profils utilisateurs.

## 3) Architecture technique

Architecture generale:

- Framework: Flutter (Dart).
- BDD: SQLite (`sqflite_common_ffi`) avec initialisation FFI desktop.
- Localisation: Francais par defaut, support anglais.
- Theme: Material 3, `ColorScheme.fromSeed(seedColor: Colors.blue)`.

Architecture de donnees a deux niveaux:

- `app_config.db` (local machine): stockage des fichiers recents.
- Fichier metier `.db` (portable): donnees fonctionnelles de l'entite.

Organisation du code:

- `lib/models`: modeles de donnees et mapping SQL <-> Dart.
- `lib/services`: logique metier, acces base, auth, permissions, export.
- `lib/pages`: ecrans UI et workflows utilisateurs.
- `lib/utils`: utilitaires transverses.

## 4) Pile technologique (dependances)

Dependances cle visibles dans `pubspec.yaml`:

- `sqflite_common_ffi`: acces SQLite multi-desktop.
- `path`, `path_provider`: gestion des chemins et emplacements locaux.
- `crypto`: hachage (mot de passe).
- `file_picker`: choix de fichier/repertoire.
- `pdf`: generation de rapports PDF.
- `excel`: export tableur.
- `flutter_localizations`: i18n.
- `window_manager`: ergonomie desktop.

## 5) Modele de donnees metier (vue d'ensemble)

Entites principales manipulees dans le projet:

- Entite (organisation).
- Utilisateur + permissions (lecture/ajout/modification/suppression par module).
- Exercice (dates, actif/cloture selon schema evolutif).
- Compte (plan comptable).
- Tiers.
- Journal.
- Budget et hierarchie budgetaire (poste, ligne, sous-rubrique).
- Projet.
- Bailleur.
- Journaux/periodes de saisie et lignes d'ecritures.

Caracteristiques de gestion des donnees:

- Donnees historisees via colonnes temporelles (`created_at`, `updated_at`, parfois `deleted_at`).
- Migrations progressives executees a l'ouverture (ajouts de colonnes/tables manquantes).
- Contraintes de coherence via cles et relations SQL.

## 6) Workflows utilisateurs (de bout en bout)

Workflow 1: demarrage et acces aux donnees

- Arrivee sur `welcome_page.dart`.
- Choix entre ouvrir un fichier recent/existant ou creer un nouveau fichier.
- Si le fichier est protege: passage par l'ecran d'authentification.
- Entree dans `home_page.dart` une fois la base connectee.

Workflow 2: creation d'un nouveau fichier comptable

- Assistant (`new_file_wizard_page.dart`) avec etapes de configuration.
- Saisie des informations de l'entite.
- Option de securisation par login/mot de passe.
- Creation du premier exercice + parametrage comptable.
- Initialisation des tables et des droits de base.

Workflow 3: saisie comptable

- Choix du journal et de la periode (`journal_periode_selection_page.dart`).
- Consultation des ecritures de la periode (`journaux_de_saisie_page.dart`).
- Ajout/modification/suppression de ligne(s) (`saisie_ecriture_page.dart`).
- Recalcul des totaux debit/credit et controle d'equilibre.

Workflow 4: consultation et edition

- Etats de synthese: balance des comptes, balance resultat.
- Interrogations et lettrages pour analyse fine.
- Export des resultats au format PDF/Excel/CSV selon cas.

## 7) Etat actuel des interfaces (inventaire complet)

Ecrans detectes dans `lib/pages/`:

- `welcome_page.dart`: accueil, fichiers recents, creation.
- `new_file_wizard_page.dart`: assistant de creation multi-etapes.
- `password_login_page.dart`: login mot de passe.
- `login_page.dart`: variante/flux connexe de connexion.
- `home_page.dart`: shell principal (menus, raccourcis, pages dynamiques).
- `database_setup_page.dart`: setup base (flux historique).
- `entite_identification_page.dart`: identification complete entite.
- `entite_form_page.dart`: formulaire entite.
- `entite_list_page.dart`: liste/gestion entites.
- `nouvel_exercice_page.dart`: gestion exercices.
- `permissions_page.dart`: gestion permissions.
- `plan_comptable_page.dart`: plan comptable.
- `liste_tiers_page.dart`: tiers.
- `journaux_page.dart`: journaux.
- `liste_bailleurs_page.dart`: bailleurs.
- `liste_projets_page.dart`: projets.
- `gestion_budgets_page.dart`: budget global.
- `budget_details_page.dart`: detail budget.
- `journal_periode_selection_page.dart`: choix periode de saisie.
- `journaux_de_saisie_page.dart`: liste ecritures de periode.
- `saisie_ecriture_page.dart`: formulaire de saisie.
- `lettrages_page.dart`: lettrages.
- `interrogations_page.dart`: interrogations comptables.
- `interrogations_lettrages_page.dart`: interrogation orientee lettrage.
- `balance_comptes_page.dart`: balance des comptes.
- `balance_resultat_page.dart`: balance de resultat.

## 8) Navigation et ergonomie

Points structurants de l'UX:

- `HomePage` centralise la navigation metier.
- Sidebar repliable avec menus par domaines.
- Raccourcis vers ecrans frequents.
- Barre haute avec contexte actif (fichier, entite, exercice).
- Dialogues utilitaires (infos base, copie chemin, changement exercice).

## 9) Securite et controle d'acces

Elements deja presents:

- Protection optionnelle des fichiers par mot de passe.
- Hachage des mots de passe avec `SHA-256` (via `crypto`).
- Gestion des utilisateurs et des roles.
- Table de permissions modulees (lecture/ajout/modification/suppression).
- Verification des droits cote application.

## 10) Couleurs utilisees (UI Flutter)

Source analysee: `lib/pages/*.dart` + `lib/main.dart`.

Palette dominante:

- Bleu: identite visuelle principale (navigation, actions primaires, accents).
- Gris: surfaces neutres, textes secondaires, separateurs.
- Vert: succes/validation/statut positif.
- Rouge: erreurs/suppression/alertes.
- Orange: avertissements.

Tokens detectes:

- `Colors.blue`
- `Colors.blue.shade50`
- `Colors.blue.shade100`
- `Colors.blue.shade200`
- `Colors.blue.shade300`
- `Colors.blue.shade400`
- `Colors.blue.shade500`
- `Colors.blue.shade600`
- `Colors.blue.shade700`
- `Colors.blue.shade800`
- `Colors.blue.shade900`
- `Colors.blue[900]`
- `Colors.grey`
- `Colors.grey.shade50`
- `Colors.grey.shade100`
- `Colors.grey.shade200`
- `Colors.grey.shade300`
- `Colors.grey.shade400`
- `Colors.grey.shade500`
- `Colors.grey.shade600`
- `Colors.grey.shade700`
- `Colors.grey.shade800`
- `Colors.grey[100]`
- `Colors.grey[600]`
- `Colors.grey[800]`
- `Colors.green`
- `Colors.green.shade50`
- `Colors.green.shade100`
- `Colors.green.shade200`
- `Colors.green.shade400`
- `Colors.green.shade500`
- `Colors.green.shade600`
- `Colors.green.shade700`
- `Colors.green.shade800`
- `Colors.green.shade900`
- `Colors.red`
- `Colors.red.shade50`
- `Colors.red.shade100`
- `Colors.red.shade200`
- `Colors.red.shade400`
- `Colors.red.shade500`
- `Colors.red.shade600`
- `Colors.red.shade700`
- `Colors.orange`
- `Colors.orange.shade50`
- `Colors.orange.shade100`
- `Colors.orange.shade500`
- `Colors.orange.shade700`
- `Colors.orange.shade800`
- `Colors.orange[300]`
- `Colors.indigo`
- `Colors.indigo.shade50`
- `Colors.indigo.shade100`
- `Colors.indigo.shade400`
- `Colors.indigo.shade500`
- `Colors.indigo.shade600`
- `Colors.indigo.shade700`
- `Colors.indigo.shade800`
- `Colors.indigo.shade900`
- `Colors.teal`
- `Colors.teal.shade700`
- `Colors.amber`
- `Colors.amber.shade50`
- `Colors.amber.shade700`
- `Colors.cyan`
- `Colors.cyan.shade700`
- `Colors.purple`
- `Colors.purple.shade700`
- `Colors.pink.shade700`
- `Colors.deepOrange`
- `Colors.blueGrey`
- `Colors.brown`
- `Colors.greenAccent`
- `Colors.redAccent`
- `Colors.black`
- `Colors.white`
- `Colors.transparent`

## 11) Couleurs utilisees dans les exports PDF

Source analysee: `lib/services/export_service.dart`.

- `PdfColors.black`
- `PdfColors.blue100`
- `PdfColors.blue700`
- `PdfColors.blue800`
- `PdfColors.green700`
- `PdfColors.red700`
- `PdfColors.grey300`

## 12) Qualite, maintenance et limites

Points positifs:

- Separation claire `pages` / `services` / `models`.
- Migrations de schema integrees a l'ouverture de base.
- Bonne couverture des flux metiers centraux.

Limites observees a ce stade:

- Presence de logique historique/dupliquee a rationaliser, maintenant regroupee dans `database_service.dart`.
- Certaines sections UI peuvent encore etre harmonisees (coherence des composants et validations).
- La documentation metier est riche mais dispersee entre plusieurs fichiers.

## 13) Conclusion

Le projet est deja substantiel et operationnel sur ses briques principales: gestion des donnees comptables, workflows de saisie, parametres metiers, etats et exports. La base technique est saine pour evoluer vers une version plus industrialisee (harmonisation UX, renforcement validation metier, nettoyage technique progressif) sans remise en cause de l'architecture actuelle.
