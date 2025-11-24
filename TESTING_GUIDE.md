# 🧪 Guide de Test - Connexion Supabase

## Prérequis

1. ✅ Fichier `.env` configuré avec vos clés Supabase
2. ✅ Dépendances installées (`flutter pub get`)
3. ✅ Un utilisateur créé dans Supabase Auth

## 📋 Étapes de test

### 1️⃣ Lancer l'application

```bash
flutter run
```

Vous devriez voir :

```
✅ Supabase initialisé avec succès
```

Dans la console.

### 2️⃣ Tester la page de connexion

**Écran attendu :**

- Gradient bleu de haut en bas
- Logo blanc au centre
- Titre "SYCEBNL Accounting"
- Champs Email et Mot de passe
- Bouton "Se connecter"

### 3️⃣ Tester la connexion

**Avec un utilisateur valide :**

```
Email    : admin@sycebnl.org
Mot de   : (le mot de passe défini dans Supabase)
```

**Comportement attendu :**

- Message d'attente avec spinner
- Message ✅ "Connexion réussie !"
- Console affiche :
  ```
  🔐 Tentative de connexion: admin@sycebnl.org
  ✅ Connexion réussie pour: admin@sycebnl.org
  ```

### 4️⃣ Tester avec identifiants invalides

**Email inexistant :**

- Message d'erreur rouge
- Console affiche :
  ```
  🔐 Tentative de connexion: inexistant@test.com
  ❌ Erreur d'authentification: Invalid login credentials
  ```

**Mot de passe incorrect :**

- Message d'erreur rouge
- Console affiche :
  ```
  🔐 Tentative de connexion: admin@sycebnl.org
  ❌ Erreur d'authentification: Invalid login credentials
  ```

### 5️⃣ Tester les validations

**Champs vides :**

- Pas d'appel à Supabase
- Message : "Veuillez remplir tous les champs"

## 🔍 Afficher la console

Pour voir les messages de débogage :

- **Android Studio** : View → Tool Windows → Logcat
- **VS Code** : View → Debug Console

Filtrer par :

```
flutter
```

## ✅ Checklist de test

- [ ] Supabase s'initialise sans erreur
- [ ] La page de login s'affiche correctement
- [ ] Connexion réussie avec un utilisateur valide
- [ ] Erreur affichée avec identifiants invalides
- [ ] Validation des champs vides
- [ ] Les messages s'affichent en temps réel

## 🐛 Troubleshooting

### "Supabase non initialisé"

```
❌ Erreur lors de l'initialisation Supabase
```

**Solution :** Vérifier que `.env` existe et contient les bonnes clés

### "Utilisateur non trouvé"

```
❌ Erreur d'authentification: Invalid login credentials
```

**Solution :** Créer l'utilisateur dans Supabase Dashboard → Auth

### "Erreur de connexion"

```
❌ Erreur de connexion: [détails de l'erreur]
```

**Solution :** Vérifier que Supabase URL et clé sont correctes

## 📊 Logs complets attendus

```
[✅] Supabase initialisé avec succès
[🔐] Tentative de connexion: admin@sycebnl.org
[✅] Connexion réussie pour: admin@sycebnl.org
```

---

**Version** : 1.0  
**Dernière mise à jour** : November 2025


nice82094@gmail.com