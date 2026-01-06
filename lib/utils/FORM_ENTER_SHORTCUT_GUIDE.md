# FormWithEnterShortcut - Guide d'utilisation

## 📋 Vue d'ensemble

L'utilitaire `FormWithEnterShortcut` permet d'activer la soumission de formulaires avec la touche **Entrée** (clavier standard et pavé numérique), avec une validation intelligente des champs obligatoires.

## ✨ Fonctionnalités

- ✅ **Validation automatique** : Vérifie que tous les champs obligatoires sont remplis avant la soumission
- ✅ **Focus sur erreur** : Met automatiquement le focus sur le premier champ invalide
- ✅ **Gestion intelligente** : Entrée insère une nouvelle ligne dans les champs multi-lignes
- ✅ **Sécurité** : Pas de soumission accidentelle si la validation échoue
- ✅ **Compatible Windows** : Supporte à la fois `Enter` et `NumpadEnter`

## 🚀 Intégration dans un formulaire

### Méthode 1 : Avec widget `FormWithEnterShortcut`

```dart
import '../utils/form_enter_shortcut.dart';

class MonFormulaire extends StatefulWidget {
  @override
  State<MonFormulaire> createState() => _MonFormulaireState();
}

class _MonFormulaireState extends State<MonFormulaire> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  Future<void> _save() async {
    // Logique de sauvegarde
  }

  @override
  Widget build(BuildContext context) {
    return FormWithEnterShortcut(
      formKey: _formKey,           // La clé du formulaire pour validation
      onSubmit: _save,             // La fonction appelée sur Entrée
      enabled: !_isSaving,         // Désactive pendant la sauvegarde
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              decoration: InputDecoration(labelText: 'Nom *'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ce champ est requis';
                }
                return null;
              },
            ),
            // ... autres champs
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Méthode 2 : Avec extension (syntaxe courte)

```dart
import '../utils/form_enter_shortcut.dart';

@override
Widget build(BuildContext context) {
  return Form(
    key: _formKey,
    child: Column(
      children: [
        // ... vos champs
      ],
    ),
  ).withEnterToSubmit(
    onSubmit: _save,
    formKey: _formKey,
    enabled: !_isSaving,
  );
}
```

## 📦 Exemples d'intégration réussie

Les pages suivantes ont déjà été intégrées et peuvent servir de référence :

### 1. **JournalDialog** ([journaux_page.dart](../pages/journaux_page.dart#L1209))

- Formulaire de création/modification de journal
- Validation de champs obligatoires (code, intitulé, type)
- Gestion du champ compte trésorerie conditionnel

### 2. **Dialogue de création de compte** ([journaux_page.dart](../pages/journaux_page.dart#L670))

- Formulaire dans un StatefulBuilder
- Validation complexe avec callbacks
- Gestion de la désactivation pendant l'enregistrement

### 3. **LoginPage** ([login_page.dart](../pages/login_page.dart#L79))

- Formulaire d'authentification
- Remplacement de `onFieldSubmitted` par FormWithEnterShortcut
- Gestion du chargement

### 4. **EntiteIdentificationPage** ([entite_identification_page.dart](../pages/entite_identification_page.dart#L166))

- Grand formulaire avec de nombreux champs
- Validation optionnelle et obligatoire
- Sauvegarde asynchrone avec état de chargement

## 🔧 Paramètres

| Paramètre  | Type                  | Requis | Description                                     |
| ---------- | --------------------- | ------ | ----------------------------------------------- |
| `child`    | Widget                | ✅     | Le widget Form à envelopper                     |
| `onSubmit` | VoidCallback          | ✅     | La fonction appelée lors de la soumission       |
| `formKey`  | GlobalKey<FormState>? | ⚠️     | Clé du formulaire (recommandée pour validation) |
| `enabled`  | bool                  | ❌     | Active/désactive le shortcut (défaut: true)     |

## 🎯 Règles de fonctionnement

### Quand Entrée soumet le formulaire :

1. ✅ Tous les champs avec `validator` retournent `null`
2. ✅ Le focus n'est **pas** dans un champ multi-ligne
3. ✅ Le paramètre `enabled` est `true`

### Quand Entrée est ignorée :

1. ❌ Un champ obligatoire est vide → Affiche l'erreur de validation
2. ❌ Le focus est dans un `TextFormField` avec `maxLines > 1`
3. ❌ `enabled = false` (ex: pendant une sauvegarde)

### Comportement après échec de validation :

- 🎯 Le focus est automatiquement placé sur le **premier champ invalide**
- 📝 Les messages de validation s'affichent sous les champs concernés
- ⚠️ Aucune soumission n'est effectuée

## 💡 Bonnes pratiques

### ✅ À faire

```dart
// 1. Désactiver pendant la sauvegarde
FormWithEnterShortcut(
  enabled: !_isSaving,
  onSubmit: _save,
  // ...
)

// 2. Valider les champs obligatoires
TextFormField(
  validator: (value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ce champ est requis';
    }
    return null;
  },
)

// 3. Utiliser formKey pour validation automatique
FormWithEnterShortcut(
  formKey: _formKey,
  onSubmit: _save,
  // ...
)
```

### ❌ À éviter

```dart
// ❌ Ne pas oublier le formKey pour les champs avec validator
FormWithEnterShortcut(
  // formKey: _formKey,  ← MANQUANT !
  onSubmit: _save,
  child: Form(
    key: _formKey,
    child: TextFormField(
      validator: (v) => v!.isEmpty ? 'Requis' : null,
    ),
  ),
)

// ❌ Ne pas dupliquer onFieldSubmitted
TextFormField(
  onFieldSubmitted: (_) => _save(),  // ← PAS NÉCESSAIRE
  // FormWithEnterShortcut s'en occupe déjà
)
```

## 📋 Pages à intégrer

Liste des pages utilisant `GlobalKey<FormState>` qui peuvent bénéficier de cette fonctionnalité :

- [ ] `entite_list_page.dart` (ligne 132)
- [ ] `database_setup_page.dart` (ligne 17)
- [ ] `balance_comptes_page.dart` (ligne 26)
- [ ] `plan_comptable_page.dart` (ligne 120)
- [ ] `liste_tiers_page.dart` (ligne 562)
- [ ] `liste_projets_page.dart` (lignes 728, 1203)
- [ ] `liste_bailleurs_page.dart` (ligne 606)

## 🔍 Détection de champs multi-lignes

Le système détecte automatiquement les champs multi-lignes :

```dart
// Entrée = nouvelle ligne (pas de soumission)
TextFormField(
  maxLines: null,  // ou maxLines > 1
  decoration: InputDecoration(labelText: 'Description'),
)

// Entrée = soumission du formulaire
TextFormField(
  maxLines: 1,  // ou non spécifié
  decoration: InputDecoration(labelText: 'Nom'),
)
```

## 🐛 Dépannage

### Le formulaire ne se soumet pas avec Entrée

1. Vérifiez que `enabled: true` (ou non spécifié)
2. Vérifiez que tous les champs avec `validator` sont valides
3. Vérifiez que le focus n'est pas dans un champ multi-ligne
4. Vérifiez que `formKey` est bien passé à `FormWithEnterShortcut`

### Le focus ne va pas sur le champ invalide

- Assurez-vous que chaque `TextFormField` a un `validator`
- Le délai de 100ms permet l'affichage des erreurs avant le focus

### Erreur "formKey.currentState is null"

- Vérifiez que le `formKey` passé correspond bien au `Form` enfant
- Assurez-vous que le `Form` est construit avant l'appel

## 📞 Support

Pour toute question ou amélioration, consultez le code source dans :

- `lib/utils/form_enter_shortcut.dart`
- Exemples d'implémentation dans `lib/pages/journaux_page.dart`

## 📄 Licence

Ce code fait partie du projet SYCEBNL Accounting.
