### 1. Page de saisie des comptes

* Lorsqu’une écriture est fermée sans avoir été ventilée, **toutes les lignes de l’écriture doivent être considérées comme « Non ventilées »**, même si l’écriture comporte deux enregistrements.
* Le fait qu’une ligne soit équilibrée ne signifie pas que l’écriture est ventilée. **Une écriture équilibrée ne doit donc pas automatiquement être considérée comme ventilée.**
* Lorsqu’un utilisateur souhaite quitter la page alors que certaines écritures ne sont pas ventilées, afficher un message d’alerte :

> **« Certaines écritures ne sont pas ventilées. Voulez-vous quand même quitter la page ? »**

* L’utilisateur doit pouvoir choisir d’**ignorer l’alerte et quitter la page** s’il le souhaite.

### 2. Page de consultation des balances

* Lorsqu’il existe des écritures non ventilées, afficher un **bouton permettant de consulter directement ces écritures**.
* Ce bouton doit permettre à l’utilisateur d’identifier les écritures concernées et d’y accéder afin de les ventiler avant de consulter les balances.

### 3. Bouton « Équilibrer » – Journaux de banque

* Dans les journaux de banque, lorsqu’on clique sur **« Équilibrer »**, la ligne concernée doit être **enregistrée automatiquement**.
* L’utilisateur ne doit pas avoir besoin de revenir ensuite cliquer sur un autre bouton pour valider ou enregistrer la ligne.

### 4. Bouton « Équilibrer » – Journaux autres que banque

* Pour les journaux qui ne sont pas des journaux de banque, si l’utilisateur a déjà renseigné le **numéro de compte** avant de cliquer sur « Équilibrer », la ligne doit également être **enregistrée automatiquement**.
* Il ne doit donc pas être nécessaire de revenir cliquer sur **« Ajouter »** pour enregistrer cette ligne.

### 5. Modification du libellé du bouton

* Sur la page de saisie des écritures, si le bouton **« Ajouter »** est toujours présent, remplacer son libellé par **« Valider »**.
