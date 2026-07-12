Améliorer l'import Excel du plan tiers.

Actuellement, l'import du plan tiers ne récupère que les informations du tiers. Je souhaite qu'il prenne également en compte le compte du plan comptable auquel le tiers est rattaché.

Modifications à apporter
Ajouter dans le modèle Excel une colonne dédiée au compte comptable (par exemple : Compte comptable ou Numéro de compte).
Lors de l'import :
lire cette colonne ;
rechercher le compte correspondant dans le plan comptable à partir de son numéro ;
associer automatiquement ce compte au tiers créé ou mis à jour.
Si le compte indiqué n'existe pas dans le plan comptable :
ne pas créer le tiers concerné ;
afficher une erreur explicite indiquant le numéro de ligne, le compte introuvable et la raison de l'échec.
Vérifier que le compte est bien un compte autorisé à être associé à un tiers (selon les règles métier de l'application). Si ce n'est pas le cas, afficher un message d'erreur explicite.
Si le fichier contient plusieurs lignes en erreur, toutes les erreurs doivent être listées afin que l'utilisateur puisse les corriger en une seule fois.
Mettre à jour le modèle Excel d'import ainsi que la documentation de l'écran pour indiquer que la colonne Compte comptable est désormais obligatoire.

L'objectif est qu'après l'import, chaque tiers soit directement rattaché à son compte du plan comptable, sans qu'une association manuelle soit nécessaire.