# 🔐 Intégration Supabase

## ✅ Configuration complète

L'application utilise maintenant **Supabase** pour l'authentification avec les variables d'environnement du fichier `.env`.

### 📁 Fichiers clés

- **`.env`** - Variables de configuration (URL et clés Supabase)
- **`lib/services/supabase_service.dart`** - Service d'authentification
- **`lib/config/env_config.dart`** - Chargement des variables d'environnement
- **`lib/main.dart`** - Initialisation de Supabase au démarrage

### 🚀 Comment ça marche

1. **Au démarrage** :

   - `main()` charge le fichier `.env`
   - Initialise Supabase avec vos clés
   - Lance l'app

2. **À la connexion** :
   - L'email et mot de passe sont envoyés à Supabase
   - Supabase valide et retourne un `User`
   - L'app affiche un message de succès

### 🔑 Variables d'environnement utilisées

```env
SUPABASE_URL=https://bnjbjrsfdrodcqobdqim.supabase.co
SUPABASE_ANON_KEY=votre_clé_anonyme
SUPABASE_SERVICE_ROLE_KEY=votre_clé_service
```

### 💻 Utiliser le service Supabase

```dart
// Connexion
final response = await SupabaseService().signIn(
  email: 'user@example.com',
  password: 'password123',
);

// Inscription
await SupabaseService().signUp(
  email: 'user@example.com',
  password: 'password123',
  nom: 'Dupont',
  prenom: 'Jean',
);

// Déconnexion
await SupabaseService().signOut();

// Vérifier si connecté
if (SupabaseService().isLoggedIn()) {
  print('Utilisateur connecté');
}
```

### 🛡️ Sécurité

- ⚠️ **Ne jamais committer le `.env`** dans Git
- Ajouter `.env` au `.gitignore`
- Les clés sont chargées à runtime depuis le fichier assets

### 📱 Tester l'authentification

1. Créer un utilisateur dans Supabase Dashboard → Auth
2. Utiliser cet email/password dans l'app
3. Vérifier les messages de succès/erreur

### 🔗 Ressources

- [Documentation Supabase Flutter](https://supabase.com/docs/reference/flutter/introduction)
- [Authentification Supabase](https://supabase.com/docs/guides/auth)
