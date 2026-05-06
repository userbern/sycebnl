# Plan Backend FastAPI pour garder le front Flutter actuel

Ce document te donne une structure complete pour remplacer la logique locale SQLite par une API FastAPI, sans changer l'experience utilisateur Flutter.

Objectif:

- garder les ecrans Flutter existants
- reproduire les comportements actuels (auth, permissions, parametrages, budgets, saisie, exports)
- deplacer la logique dans un backend FastAPI

---

## 1) Architecture cible

### Stack recommandee

- FastAPI
- SQLAlchemy 2.x (ORM)
- Alembic (migrations)
- PostgreSQL (production) ou SQLite (dev)
- Pydantic v2
- JWT (auth)
- Uvicorn/Gunicorn

### Structure de projet conseillee

```text
backend/
	app/
		main.py
		core/
			config.py
			security.py
			dependencies.py
			database.py
		models/
			base.py
			user.py
			module.py
			permission.py
			entite.py
			exercice.py
			config_comptable.py
			compte.py
			tiers.py
			journal.py
			bailleur.py
			projet.py
			projet_bailleur.py
			budget.py
			poste_budgetaire.py
			ligne_budgetaire.py
			sous_rubrique.py
			journal_periode.py
			ecriture.py
			ventilation_analytique.py
		schemas/
			auth.py
			user.py
			permission.py
			entite.py
			exercice.py
			config_comptable.py
			compte.py
			tiers.py
			journal.py
			bailleur.py
			projet.py
			budget.py
			poste_budgetaire.py
			ligne_budgetaire.py
			sous_rubrique.py
			saisie.py
			common.py
		services/
			auth_service.py
			permission_service.py
			entite_service.py
			exercice_service.py
			config_service.py
			compte_service.py
			tiers_service.py
			journal_service.py
			bailleur_service.py
			projet_service.py
			budget_service.py
			saisie_service.py
			export_service.py
		api/
			v1/
				router.py
				endpoints/
					auth.py
					users.py
					permissions.py
					entites.py
					exercices.py
					config_comptable.py
					comptes.py
					tiers.py
					journaux.py
					bailleurs.py
					projets.py
					budgets.py
					saisie.py
					exports.py
	alembic/
	pyproject.toml
```

---

## 2) Base de donnees: schema pour reproduire le comportement actuel

Important:

- garde les noms de tables et champs proches de ce que Flutter consomme deja
- ajoute deleted_at pour soft delete la ou le front attend ce comportement
- ajoute created_at, updated_at partout

### Tables coeur securite

1. utilisateur

- id
- login (unique)
- password (sha256 au debut, puis bcrypt plus tard)
- nom
- prenom
- role
- created_at
- updated_at
- deleted_at

2. modules

- id
- nom (unique): notre_entite, parametrages, traitements, edition

3. permissions

- id
- utilisateur_id (fk utilisateur)
- module_id (fk modules)
- lecture
- ajout
- modification
- suppression
- created_at
- updated_at
- deleted_at
- unique(utilisateur_id, module_id)

### Tables metier principales

4. entite

- id
- denomination_sociale
- sigle_usuel
- domaine_intervention
- forme_juridique
- ong_type
- pays
- region
- ville
- quartier
- email
- telephone
- fixe_fax
- numero_fiscal
- numero_cnss
- numero_recepisse
- informations_complementaires
- currency
- is_active
- created_by
- created_at
- updated_at
- deleted_at

5. config

- id
- longueur_compte_general
- longueur_compte_tiers
- created_at
- updated_at

6. exercice

- id
- code (unique)
- date_debut
- date_fin
- duree_mois
- is_active
- is_cloture
- created_at
- updated_at
- deleted_at

7. compte

- id
- numero_compte (unique)
- intitule
- type_compte
- nature_compte
- rattachement_tiers
- is_active
- created_at
- updated_at
- deleted_at

8. tiers

- id
- numero_tiers (unique)
- intitule
- type_tiers
- compte_collectif
- nif
- adresse
- is_active
- created_at
- updated_at
- deleted_at

9. journal

- id
- code (unique)
- libelle
- type
- numero_compte_tresorerie (fk compte.numero_compte)
- saisie_analytique
- is_active
- created_at
- updated_at

10. bailleur

- id
- sigle
- designation
- is_active
- created_at
- updated_at
- deleted_at

11. projet

- id
- code (unique)
- designation
- date_debut
- date_fin
- is_active
- created_at
- updated_at
- deleted_at

12. projet_bailleur (many-to-many)

- id
- projet_id
- bailleur_id
- unique(projet_id, bailleur_id)

13. budget

- id
- projet_id
- bailleur_id
- exercice_id
- is_active
- created_at
- updated_at
- deleted_at
- unique(projet_id, bailleur_id, exercice_id)

14. poste_budgetaire

- id
- budget_id
- intitule
- is_active
- created_at
- updated_at
- deleted_at

15. ligne_budgetaire

- id
- poste_budgetaire_id
- code
- intitule
- is_active
- created_at
- updated_at
- deleted_at

16. sous_rubrique

- id
- ligne_budgetaire_id
- intitule
- montant
- numero_compte
- is_active
- created_at
- updated_at
- deleted_at

### Tables saisie comptable

17. journaux_periodes

- id
- code_journal
- annee
- mois
- exercice_id
- nombre_ecritures
- total_debit
- total_credit
- solde_final
- is_equilibre
- is_closed
- created_at
- updated_at
- unique(code_journal, annee, mois, exercice_id)

18. ecritures

- id
- journal_periode_id
- numero_enregistrement
- jour
- date_comptable
- numero_document
- reference
- numero_compte
- numero_tiers
- libelle
- montant_debit
- montant_credit
- is_ventilee
- created_at
- updated_at

19. ventilations_analytiques

- id
- ecriture_id
- type
- id_projet
- volet
- id_bailleur
- id_poste_budgetaire
- id_ligne_budgetaire
- montant_ventile
- created_at
- updated_at
- deleted_at

---

## 3) Models SQLAlchemy a creer

Dans app/models, cree un fichier par modele (liste ci-dessus) avec:

- table name
- colonnes
- contraintes uniques
- index utiles (code, numero_compte, numero_tiers, dates)
- relations ORM

Exemples de relations obligatoires:

- Utilisateur -> Permission (1:N)
- Module -> Permission (1:N)
- Projet <-> Bailleur via ProjetBailleur (N:N)
- Budget -> Projet, Bailleur, Exercice
- PosteBudgetaire -> Budget
- LigneBudgetaire -> PosteBudgetaire
- SousRubrique -> LigneBudgetaire
- JournalPeriode -> Ecritures
- Ecriture -> VentilationAnalytique

Bonnes pratiques model:

- Base commune avec id, created_at, updated_at
- timezone UTC
- soft delete pour les objets administres dans le front

---

## 4) Schemas Pydantic a creer

Pour chaque domaine, prevois au minimum:

- Create schema
- Update schema
- Read schema
- List response schema paginee (optionnel)

Schemas indispensables:

1. auth.py

- LoginRequest
- LoginResponse (token, user, permissions)

2. user.py

- UserCreate, UserUpdate, UserRead

3. permission.py

- PermissionUpdate
- PermissionByModuleRead

4. entite.py

- EntiteCreate, EntiteUpdate, EntiteRead

5. exercice.py

- ExerciceCreate, ExerciceUpdate, ExerciceRead, ExerciceActivateRequest

6. compte.py

- CompteCreate, CompteUpdate, CompteRead

7. tiers.py

- TiersCreate, TiersUpdate, TiersRead

8. journal.py

- JournalCreate, JournalUpdate, JournalRead

9. bailleur.py

- BailleurCreate, BailleurUpdate, BailleurRead

10. projet.py

- ProjetCreate, ProjetUpdate, ProjetRead
- ProjetBailleursUpdate

11. budget.py

- BudgetCreate, BudgetRead
- PosteBudgetaireCreate/Update/Read
- LigneBudgetaireCreate/Update/Read
- SousRubriqueCreate/Update/Read

12. saisie.py

- JournalPeriodeCreate, JournalPeriodeRead
- EcritureCreate, EcritureUpdate, EcritureRead
- VentilationCreate, VentilationRead
- TotauxSaisieRead

13. common.py

- ApiResponse
- PaginatedResponse

---

## 5) Services metier a creer

Principe:

- Les routes sont fines
- Toute la logique metier est dans services/

### auth_service.py

- login(login, password)
- verify_password
- create_access_token
- get_current_user

Comportement a reproduire:

- login incorrect -> message identique a Flutter
- retour user + permissions

### permission_service.py

- get_module_permissions(user_id, module_name)
- can_read/can_create/can_edit/can_delete
- update_permissions(user_id, module_id, flags)

### entite_service.py

- get_entite_unique()
- update_entite()

### exercice_service.py

- list_exercices()
- create_exercice()
- set_active_exercice()
- cloturer_exercice()

Regles:

- maximum 5 exercices
- code unique
- un seul exercice actif

### compte_service.py

- list_comptes(filters)
- create_compte()
- update_compte()
- delete_compte()

Regles:

- numero unique
- verifier references avant suppression

### tiers_service.py

- list_tiers(filters)
- create_tiers()
- update_tiers()
- delete_tiers()

Regles:

- type tiers derive possible selon prefixe compte
- coherence compte collectif

### journal_service.py

- list_journaux(filters)
- create_journal()
- update_journal()
- delete_journal()

Regles:

- si journal financier -> compte tresorerie obligatoire
- suppression interdite si ecritures existantes

### bailleur_service.py

- list_bailleurs(filters)
- create_bailleur()
- update_bailleur()
- delete_bailleur()

### projet_service.py

- list_projets(filters)
- get_projets_with_bailleurs()
- create_projet()
- update_projet()
- delete_projet()
- set_projet_bailleurs(projet_id, bailleur_ids)

### budget_service.py

- list_budgets(exercice_id, search)
- create_budget(projet_id, bailleur_id, exercice_id)
- delete_budget(budget_id)
- list_postes(budget_id)
- create/update/delete_poste
- list_lignes(poste_id)
- create/update/delete_ligne
- list_sous_rubriques(ligne_id)
- create/update/delete_sous_rubrique
- get_montants_agreges(poste/ligne/budget)

### saisie_service.py

- create_or_get_journal_periode(code_journal, annee, mois, exercice_id)
- get_ecritures(journal_periode_id)
- get_ecritures_by_journal_year_month(...)
- add_ecriture()
- update_ecriture()
- delete_ecriture()
- calculate_totaux(ecritures)
- update_periode_totaux(journal_periode_id)
- add/get/delete_ventilations(ecriture_id)

Regles:

- solde = debit - credit
- is_equilibre = abs(solde) < 0.01
- nombre_ecritures = count distinct numero_enregistrement

### export_service.py

- generate_balance_pdf(payload)
- generate_balance_excel(payload)

Option:

- soit generation backend (retour file stream)
- soit generation conservee dans Flutter (plus simple)

---

## 6) Routes FastAPI a creer

Prefixe global: /api/v1

### Auth

- POST /auth/login
- POST /auth/refresh
- GET /auth/me

### Utilisateurs + permissions

- GET /users
- POST /users
- PATCH /users/{id}
- DELETE /users/{id}
- GET /users/{id}/permissions
- PUT /users/{id}/permissions
- GET /modules

### Entite + config + exercice

- GET /entite
- PATCH /entite
- GET /config
- PATCH /config
- GET /exercices
- POST /exercices
- PATCH /exercices/{id}
- POST /exercices/{id}/activate
- POST /exercices/{id}/close

### Parametrages

- GET /comptes
- POST /comptes
- PATCH /comptes/{id}
- DELETE /comptes/{id}

- GET /tiers
- POST /tiers
- PATCH /tiers/{id}
- DELETE /tiers/{id}

- GET /journaux
- POST /journaux
- PATCH /journaux/{id}
- DELETE /journaux/{id}

- GET /bailleurs
- POST /bailleurs
- PATCH /bailleurs/{id}
- DELETE /bailleurs/{id}

- GET /projets
- GET /projets/with-bailleurs
- POST /projets
- PATCH /projets/{id}
- DELETE /projets/{id}
- PUT /projets/{id}/bailleurs

### Budgets

- GET /budgets?exercice_id=...&q=...
- POST /budgets
- DELETE /budgets/{id}

- GET /budgets/{id}/postes
- POST /budgets/{id}/postes
- PATCH /postes/{id}
- DELETE /postes/{id}

- GET /postes/{id}/lignes
- POST /postes/{id}/lignes
- PATCH /lignes/{id}
- DELETE /lignes/{id}

- GET /lignes/{id}/sous-rubriques
- POST /lignes/{id}/sous-rubriques
- PATCH /sous-rubriques/{id}
- DELETE /sous-rubriques/{id}

### Saisie comptable

- POST /saisie/journaux-periodes
- GET /saisie/journaux-periodes
- GET /saisie/journaux-periodes/{id}/ecritures
- GET /saisie/ecritures/by-journal
- POST /saisie/ecritures
- PATCH /saisie/ecritures/{id}
- DELETE /saisie/ecritures/{id}
- GET /saisie/journaux-periodes/{id}/totaux

- GET /saisie/ecritures/{id}/ventilations
- POST /saisie/ecritures/{id}/ventilations
- DELETE /saisie/ecritures/{id}/ventilations

### Exports

- POST /exports/balance/pdf
- POST /exports/balance/excel

---

## 7) Comment garder le front Flutter actuel

Tu ne changes pas les pages. Tu changes seulement la couche services Flutter:

1. Creer api_client.dart (Dio ou http)
2. Remplacer progressivement les appels SQL locaux dans services Flutter par appels HTTP
3. Conserver les memes modeles Dart pour eviter de casser l'UI
4. Mapper reponses API -> modeles existants

Exemple de mapping:

- AuthService.login -> POST /auth/login
- AuthService.getComptes -> GET /comptes
- AuthService.createProjet -> POST /projets
- SaisieComptableService.addLigneEcriture -> POST /saisie/ecritures

Suggestion pratique:

- garde temporairement les signatures actuelles des services Flutter
- a l'interieur, remplace seulement l'implementation locale par HTTP

---

## 8) Contrats API importants pour reproduire le comportement exact

1. Format erreurs

- 400 pour validation metier
- 401 pour non authentifie
- 403 pour manque de permission
- 404 si ressource absente
- 409 pour conflit (ex: code deja utilise)

Corps standard:

```json
{
  "message": "Texte metier lisible",
  "code": "BUSINESS_RULE_ERROR",
  "details": {}
}
```

2. Permissions par module

- chaque route sensible verifie lecture/ajout/modification/suppression
- le front garde son comportement de masquage des boutons

3. Dates et montants

- dates en ISO 8601
- montants decimal (pas float binaire en DB, utiliser Numeric)

4. Transactions

- create budget + details en transaction
- ecriture + ventilation en transaction

---

## 9) Plan d'implementation par phases

Phase 1 - Infra

- setup FastAPI + SQLAlchemy + Alembic + JWT
- migrations initiales

Phase 2 - Auth + permissions

- routes auth/users/permissions/modules
- tests auth

Phase 3 - Parametrages

- entite/config/exercices/comptes/tiers/journaux/bailleurs/projets

Phase 4 - Budgets

- budget + poste + ligne + sous-rubrique + agregats

Phase 5 - Saisie comptable

- journaux_periodes + ecritures + ventilations + totaux

Phase 6 - Flutter integration

- remplacement progressif des services locaux par API
- QA fonctionnelle ecran par ecran

Phase 7 - Exports et hardening

- exports PDF/Excel
- logs, monitoring, rate limit, backup

---

## 10) Minimum de fichiers a creer en premier

Priorite immediate:

1. core/database.py
2. core/security.py
3. models: utilisateur, modules, permissions, entite, exercice, compte
4. schemas: auth, user, permission, entite, exercice, compte
5. services: auth_service, permission_service, exercice_service, compte_service
6. routes: auth, users, permissions, exercices, comptes

Ensuite seulement: tiers, journaux, projets, budgets, saisie.

---

## 11) Notes de compatibilite avec l'existant

- Le projet actuel utilise beaucoup de soft delete via deleted_at: garde ce principe.
- Le hash actuel est SHA-256: pour migration douce, accepte SHA-256 au debut puis migre vers bcrypt au prochain changement de mot de passe.
- Le front actuel filtre beaucoup en local: deplace progressivement le filtrage vers l'API pour de meilleures performances.
- Si tu veux rester tres proche des comportements actuels, garde les memes noms de champs JSON que le front attend deja.

---

## 12) Resultat attendu

Avec cette organisation:

- Flutter garde ses ecrans et UX actuelle
- la logique devient centralisee et securisee dans FastAPI
- tu peux brancher plusieurs postes clients sur la meme base
- tu prepares facilement une evolution vers web/admin et reporting avance
