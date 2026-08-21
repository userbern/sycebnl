Parfait. On peut passer à **l'étape 3 : le client réseau**.

Pour Claude, je lui donnerais cette consigne précise :

* créer `RemoteRepository`
* écran **« Se connecter à une base réseau »**
* IP + port + identifiant + mot de passe
* login → réception du token
* conserver le token uniquement en mémoire
* utiliser les endpoints existants
* basculer l'application entre `LocalRepository` et `RemoteRepository`
* **aucune copie de la base distante**
* si le serveur tombe → état **« Base réseau indisponible »**
* ne pas encore implémenter les WebSockets ; on les fera à l'étape 4
* ne pas casser le mode local

Le point le plus important : **Claude ne doit pas réécrire les pages comptables pour le réseau**. Elles doivent continuer à utiliser `IAccountingRepository`, et c'est l'implémentation qui change.

Si tu veux, je peux te donner maintenant **le prompt complet de l'étape 3 prêt à copier dans Claude**.
