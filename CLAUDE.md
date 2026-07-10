Règles générales

- Modifier uniquement les fichiers nécessaires.
- Éviter les refactorings globaux sauf s'ils sont explicitement demandés.
- Ne jamais casser les fonctionnalités existantes.
- Conserver les noms des classes, méthodes et variables lorsqu'il n'est pas nécessaire de les modifier.
- Réutiliser les widgets, services et composants existants avant d'en créer de nouveaux.
- Respecter l'architecture actuelle.
- Éviter les duplications de code.
- Préférer une solution simple et maintenable.
- Toujours vérifier les impacts des modifications sur le reste du projet.

Architecture

Avant de créer un nouveau fichier ou une nouvelle classe :

- rechercher si un composant similaire existe déjà ;
- privilégier la réutilisation ;
- respecter l'organisation actuelle des dossiers.

Ne pas déplacer des fichiers sans demande explicite.

Avant de coder

Commencer par comprendre le problème.

S'il manque des informations importantes, les demander avant de proposer une solution.

Ne jamais faire d'hypothèses sur le fonctionnement métier.

Quand une modification est demandée :

. Identifier les fichiers concernés.
. Expliquer brièvement la solution.
. Modifier uniquement ce qui est nécessaire.
. Ne pas modifier d'autres parties du projet.

 À éviter

- Refactoring massif.
- Renommage inutile.
- Création de nouveaux dossiers sans raison.
- Duplication de logique.
- Modification de plusieurs modules alors qu'un seul est demandé.
- Ajout de dépendances inutiles.

TAF:
Implémente un module **Sécurité du dossier comptable** en Flutter Desktop.

### Fonctionnement

* Lors de la création d'un dossier comptable, l'utilisateur choisit un mot de passe.
* Les données du dossier doivent être chiffrées (AES-256-GCM).
* Le mot de passe ne doit jamais être stocké en clair (utiliser Argon2id ou PBKDF2).
* Générer un **ID unique du dossier** (UUID).
* Générer une **clé de récupération unique** au format lisible (ex. XXXX-XXXX-XXXX-XXXX).
* Afficher cette clé une seule fois après la création du dossier avec les options Copier, Imprimer et Exporter en PDF.
* Ajouter un bouton **« Mot de passe oublié »** sur l'écran d'ouverture.

### Récupération

Si l'utilisateur possède sa clé de récupération :

* vérifier la clé ;
* autoriser immédiatement la création d'un nouveau mot de passe ;
* conserver toutes les données.

### Assistance par l'éditeur

Prévoir une architecture permettant à l'éditeur de déverrouiller **un seul dossier à la fois** à l'aide d'un code de récupération généré à partir de l'ID du dossier. **Ne pas intégrer de login ou de mot de passe maître universel dans l'application**, ni de clé permettant d'ouvrir tous les dossiers.

### Interface

Ajouter une section **Sécurité** contenant :

* Modifier le mot de passe.
* Afficher l'ID du dossier.
* Afficher ou régénérer la clé de récupération.
* Exporter la clé en PDF.
* Copier la clé.

Le code doit être modulaire, propre, documenté, compatible Flutter Desktop et facilement réutilisable.
 on peut implémenter ça en fonction de l'avancement de notre projet actuel sans casser les autres fonctionnement?