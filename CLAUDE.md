Implémente un système de fichier comptable professionnel sous Flutter Desktop (Windows).

OBJECTIF

L'utilisateur ne doit jamais manipuler un fichier ".db".

À la place, utiliser une extension personnalisée :

.syca

(ou créer une constante permettant de la modifier facilement).

En interne, le fichier reste une base SQLite valide.

À FAIRE

1. Créer une classe AppDatabase qui ouvre un fichier ".sya" avec sqlite3/sqflite_common_ffi.

2. Toutes les opérations SQLite doivent fonctionner normalement malgré l'extension ".syca".

3. Remplacer partout dans le projet les références ".db" visibles par ".syca".

4. Lors de la création d'un nouveau dossier comptable :

- demander le nom de l'entreprise
- créer automatiquement :

NomEntreprise.syca

5. Lors de l'ouverture d'un dossier :

- filtrer uniquement les fichiers ".syca".

6. Ajouter une constante :

const databaseExtension = ".syca";

afin de pouvoir changer facilement l'extension.

7. Sous Windows :

Configurer le projet afin que l'extension ".syca" soit associée à l'application.

Le double-clic sur un fichier ".syca" doit ouvrir automatiquement l'application puis charger ce dossier comptable.

8. Utiliser le logo officiel de l'application comme icône des fichiers ".syca".

9. Ajouter les fonctions :

- createAccountingFile()
- openAccountingFile()
- isAccountingFile()

10. Le code doit être modulaire, documenté et compatible Flutter Desktop Windows.

Ne modifier que les parties nécessaires sans casser l'architecture existante.