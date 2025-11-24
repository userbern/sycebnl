# 🚀 Guide de démarrage rapide

## Pour les nouveaux développeurs

### 1️⃣ Cloner le projet

```bash
git clone <url-du-repository>
cd sycebnl_accounting
```

### 2️⃣ Configurer les variables d'environnement

**Windows PowerShell :**

```powershell
Copy-Item .env.example .env
```

**Linux/Mac :**

```bash
cp .env.example .env
```

### 3️⃣ Ajouter vos clés Supabase

Ouvrir le fichier `.env` et remplacer par vos vraies clés :

```env
SUPABASE_URL=https://votre-projet.supabase.co
SUPABASE_ANON_KEY=votre_cle_anonyme_ici
```

**Où trouver ces clés ?**

1. Aller sur [supabase.com](https://supabase.com)
2. Ouvrir votre projet
3. Settings → API
4. Copier "Project URL" et "anon public"

### 4️⃣ Installer les dépendances

```bash
flutter pub get
```

### 5️⃣ Exécuter les migrations Supabase

Dans votre projet Supabase (SQL Editor), exécuter dans l'ordre :

1. `supabase/migrations/create_bailleur_table.sql`
2. `supabase/migrations/create_projet_tables.sql`
3. `supabase/migrations/create_budget_tables.sql`

### 6️⃣ Lancer l'application

```bash
flutter run
```

## ⚠️ IMPORTANT - Sécurité

- ✅ Le fichier `.env` est dans `.gitignore`
- ❌ **NE JAMAIS** commiter le fichier `.env`
- ❌ **NE JAMAIS** mettre vos clés en dur dans le code
- ✅ Toujours utiliser `EnvConfig.supabaseUrl` et `EnvConfig.supabaseAnonKey`

## 🆘 Problèmes courants

### Erreur "Configuration manquante!"

➡️ Vous n'avez pas créé le fichier `.env` ou il est vide
➡️ Solution : Suivre les étapes 2 et 3

### Erreur de connexion Supabase

➡️ Vérifier que les clés dans `.env` sont correctes
➡️ Vérifier que votre projet Supabase est actif

### L'application ne compile pas

➡️ Exécuter `flutter clean` puis `flutter pub get`
➡️ Vérifier `flutter doctor`

## 📚 Plus d'informations

- **Guide complet** : [README.md](README.md)
- **Sécurité** : [SECURITY.md](SECURITY.md)
- **Documentation Flutter** : [flutter.dev](https://flutter.dev)
- **Documentation Supabase** : [supabase.com/docs](https://supabase.com/docs)
