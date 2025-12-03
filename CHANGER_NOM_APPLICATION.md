# 📝 Comment changer le nom de l'application

Voici **TOUS les fichiers** à modifier pour changer le nom de votre application Flutter.

---

## 1️⃣ **lib/main.dart** (Titre de l'application)

**Ligne 29** - Titre affiché dans la barre de tâches Windows

```dart
return MaterialApp(
  title: 'SYCEBNL Accounting',  // ⬅️ CHANGER ICI
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    useMaterial3: true,
  ),
```

---

## 2️⃣ **windows/runner/main.cpp** (Titre de la fenêtre Windows)

**Ligne 33** - Titre de la fenêtre sur Windows

```cpp
if (!window.Create(L"sycebnl_accounting", origin, size))  // ⬅️ CHANGER ICI
{
  return EXIT_FAILURE;
}
```

**Exemple** : Changer en `L"SOFICOM Accounting"` ou `L"Mon Application"`

---

## 3️⃣ **pubspec.yaml** (Nom du package et description)

**Ligne 1-2** - Nom technique du package (utilisé en interne)

```yaml
name: sycebnl_accounting # ⬅️ CHANGER ICI (sans espaces, snake_case)
description: "A new Flutter project." # ⬅️ CHANGER ICI (description libre)
```

**⚠️ ATTENTION** : Changer le nom du package nécessite aussi de :

- Renommer tous les imports dans le code
- Exécuter `flutter clean` puis `flutter pub get`

**Exemple** :

```yaml
name: soficom_accounting
description: "Application de comptabilité pour SOFICOM"
```

---

## 4️⃣ **windows/CMakeLists.txt** (Nom du projet Windows)

Cherchez cette ligne (généralement ligne 1) :

```cmake
project(sycebnl_accounting LANGUAGES CXX)  # ⬅️ CHANGER ICI
```

---

## 5️⃣ **README.md** (Documentation)

Changez le titre et toutes les occurrences du nom :

```markdown
# SYCEBNL Accounting ⬅️ CHANGER ICI

## 📊 À propos du projet

**SYCEBNL Accounting** est une application... ⬅️ CHANGER ICI
```

---

## 📋 **RÉSUMÉ RAPIDE**

Si vous voulez juste changer le **nom affiché** (sans toucher au code) :

1. **`lib/main.dart`** ligne 29 : `title: 'VOTRE NOM'`
2. **`windows/runner/main.cpp`** ligne 33 : `L"votre_nom"`

Si vous voulez tout renommer (package complet) :

1. Tous les fichiers ci-dessus
2. Renommer le dossier du projet
3. Exécuter :
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

---

## ✅ **EXEMPLE COMPLET**

Pour renommer en **"SOFICOM Accounting"** :

### lib/main.dart

```dart
title: 'SOFICOM Accounting',
```

### windows/runner/main.cpp

```cpp
if (!window.Create(L"SOFICOM Accounting", origin, size))
```

### pubspec.yaml

```yaml
name: soficom_accounting
description: "Application de comptabilité SOFICOM"
```

### windows/CMakeLists.txt

```cmake
project(soficom_accounting LANGUAGES CXX)
```

---

## 🔧 **Après les modifications**

1. Fermer l'application si elle est en cours d'exécution
2. Exécuter dans le terminal :
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

Le nouveau nom apparaîtra dans :

- La barre de titre de la fenêtre Windows
- La barre des tâches
- Le gestionnaire de tâches
- Les paramètres de l'application
