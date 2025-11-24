# Guide de Sécurité - GitHub

## ⚠️ IMPORTANT : Protéger vos clés Supabase

Ce projet utilise des variables d'environnement pour sécuriser les clés d'API Supabase. Suivez ces étapes **AVANT** de pousser sur GitHub.

## 📋 Checklist avant de pousser sur GitHub

- [ ] Vérifier que `.env` est dans `.gitignore`
- [ ] Vérifier que `.env.example` existe (sans vraies clés)
- [ ] Installer les dépendances : `flutter pub get`
- [ ] Tester que l'application fonctionne avec le fichier `.env`
- [ ] **NE JAMAIS** commiter le fichier `.env`

## 🔧 Configuration pour un nouveau développeur

Si quelqu'un clone votre projet, voici les étapes :

### 1. Cloner le repository
```bash
git clone <url-du-repo>
cd sycebnl_accounting
```

### 2. Installer les dépendances
```bash
flutter pub get
```

### 3. Créer le fichier `.env`
Copier `.env.example` vers `.env` :
```bash
# Windows PowerShell
Copy-Item .env.example .env

# Linux/Mac
cp .env.example .env
```

### 4. Remplir les vraies valeurs dans `.env`
Ouvrir `.env` et remplacer par vos vraies clés Supabase :
```env
SUPABASE_URL=https://votre-projet.supabase.co
SUPABASE_ANON_KEY=votre_vraie_cle_anonyme
```

### 5. Lancer l'application
```bash
flutter run
```

## 🚨 En cas d'exposition accidentelle des clés

Si vous avez **déjà commité** vos clés par erreur :

1. **Révoquer immédiatement** les clés dans Supabase
2. Générer de nouvelles clés
3. Nettoyer l'historique Git :
   ```bash
   # Supprimer le fichier de l'historique Git
   git filter-branch --force --index-filter \
   "git rm --cached --ignore-unmatch .env" \
   --prune-empty --tag-name-filter cat -- --all
   
   # Force push (ATTENTION : destructif)
   git push origin --force --all
   ```

4. Informer tous les collaborateurs de mettre à jour

## 📁 Fichiers importants

- **`.env`** : Contient vos vraies clés (JAMAIS sur GitHub)
- **`.env.example`** : Template sans vraies valeurs (SUR GitHub)
- **`.gitignore`** : Assure que `.env` n'est pas tracé
- **`lib/config/env_config.dart`** : Classe pour accéder aux variables d'environnement

## ✅ Vérification avant commit

Avant chaque commit, vérifier :
```bash
# Voir les fichiers qui seront commités
git status

# Si .env apparaît, NE PAS COMMITER !
```

Si `.env` apparaît :
```bash
# L'enlever du staging
git reset .env

# Vérifier que .gitignore contient bien .env
```

## 🔒 Bonnes pratiques

1. **Ne jamais** partager votre fichier `.env`
2. **Ne jamais** mettre de clés en dur dans le code
3. **Toujours** utiliser `EnvConfig` pour accéder aux clés
4. Utiliser des clés différentes pour dev/prod
5. Activer Row Level Security (RLS) dans Supabase

## 📞 Support

En cas de problème avec la configuration, contacter l'administrateur du projet.
