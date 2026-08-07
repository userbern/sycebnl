Saisie d'écriture

## Bugs à corriger

### 1. Enregistrement automatique par touche Entrée sur toutes les lignes
- Sur la 1ère ligne d'un enregistrement (écriture), quand tous les champs obligatoires sont saisis et qu'on appuie sur Entrée, la ligne s'enregistre automatiquement. ✅ Ça fonctionne.
- À partir de la 2è ligne du même enregistrement, l'enregistrement automatique par Entrée ne fonctionne plus (refusé). ❌ À corriger : le même comportement (auto-save sur Entrée une fois les champs obligatoires remplis) doit s'appliquer à toutes les lignes de l'enregistrement, pas seulement la première.

### 2. Ne pas écraser le numéro de compte saisi manuellement + auto-save après équilibrage
- Quand on ajoute une nouvelle ligne de saisie sur un enregistrement, les champs sont pré-remplis par défaut, sauf le montant et le numéro de compte.
- Si l'utilisateur saisit lui-même le numéro de compte avant de cliquer sur "Équilibré", ce numéro de compte ne doit plus être écrasé/effacé par l'action "Équilibré" (qui ne doit alors compléter que le montant, sans toucher au compte déjà renseigné par l'utilisateur).
- Quand on clique sur "Équilibré" et que le montant est renseigné automatiquement, un appui sur Entrée doit enregistrer la ligne immédiatement (même comportement que la saisie manuelle).
