# ✅ Checklist avant de pousser sur GitHub

## Fichiers de sécurité créés

- [x] `.env.example` - Template sans clés (À INCLURE sur GitHub)
- [x] `.env` - Fichier avec vraies clés (EXCLU de GitHub via .gitignore)
- [x] `lib/config/env_config.dart` - Classe pour charger les variables d'environnement
- [x] `.gitignore` - Mis à jour pour exclure `.env`
- [x] `SECURITY.md` - Guide de sécurité complet
- [x] `GETTING_STARTED.md` - Guide de démarrage rapide
- [x] `setup.ps1` - Script d'installation automatique

## Modifications du code

- [x] `lib/main.dart` - Utilise maintenant `EnvConfig` au lieu de clés en dur
- [x] `pubspec.yaml` - Ajout de `flutter_dotenv: ^5.1.0`
- [x] `pubspec.yaml` - Ajout de `.env` dans les assets

## ⚠️ AVANT de faire `git push`

### 1. Vérifier que .env n'est PAS tracé

```powershell
git status
```

👉 Le fichier `.env` **NE DOIT PAS** apparaître dans "Changes to be committed"

Si `.env` apparaît, le retirer avec :

```powershell
git rm --cached .env
```

### 2. Vérifier le .gitignore

```powershell
cat .gitignore | Select-String ".env"
```

👉 Devrait afficher : `.env`

### 3. Tester que l'application fonctionne

```powershell
flutter run
```

👉 L'application doit démarrer sans erreur

## 📤 Commandes Git recommandées

```powershell
# 1. Initialiser le repository (si pas déjà fait)
git init

# 2. Ajouter tous les fichiers SAUF .env
git add .

# 3. Vérifier ce qui sera commité
git status
# ⚠️ Vérifier que .env n'apparaît PAS !

# 4. Premier commit
git commit -m "Initial commit - SYCEBNL Accounting avec sécurité Supabase"

# 5. Ajouter le remote GitHub
git remote add origin https://github.com/votre-username/sycebnl_accounting.git

# 6. Pousser sur GitHub
git branch -M main
git push -u origin main
```

## ✅ Vérification post-push

Après avoir poussé sur GitHub :

1. Aller sur GitHub et vérifier que `.env` n'est **PAS** présent
2. Vérifier que `.env.example` **EST** présent
3. Vérifier que `SECURITY.md` et `GETTING_STARTED.md` sont visibles
4. Cloner dans un nouveau dossier pour tester l'expérience d'un nouveau développeur :
   ```powershell
   cd ..
   git clone https://github.com/votre-username/sycebnl_accounting.git test-clone
   cd test-clone
   # Suivre les instructions dans GETTING_STARTED.md
   ```

## 🆘 Si vous avez accidentellement commité .env

**IMMÉDIATEMENT :**

1. **Révoquer les clés Supabase**

   - Aller sur Supabase → Settings → API
   - Générer de nouvelles clés

2. **Nettoyer l'historique Git**

   ```powershell
   git filter-branch --force --index-filter `
   "git rm --cached --ignore-unmatch .env" `
   --prune-empty --tag-name-filter cat -- --all

   git push origin --force --all
   ```

3. **Mettre à jour .env avec les nouvelles clés**

4. **Informer les collaborateurs**

## 📋 Template pour le README GitHub

Ajouter en haut du README.md :

```markdown
## 🔐 Configuration requise

Ce projet utilise des variables d'environnement pour protéger les clés Supabase.

**Pour commencer :**

1. Cloner le projet
2. Copier `.env.example` vers `.env`
3. Remplir `.env` avec vos clés Supabase
4. Lancer `flutter pub get`

📖 Consultez [GETTING_STARTED.md](GETTING_STARTED.md) pour le guide complet.
```

## ✅ Liste de contrôle finale

- [ ] `.env` est dans `.gitignore`
- [ ] `.env` n'est pas dans `git status`
- [ ] `.env.example` existe et est vide de clés
- [ ] `SECURITY.md` est créé
- [ ] `GETTING_STARTED.md` est créé
- [ ] L'application fonctionne avec le fichier `.env`
- [ ] `pubspec.yaml` contient `flutter_dotenv`
- [ ] `pubspec.yaml` contient `.env` dans les assets
- [ ] Le code utilise `EnvConfig` et pas de clés en dur

## 🎉 Prêt pour GitHub !

Une fois toutes les cases cochées, vous pouvez pousser en toute sécurité !
