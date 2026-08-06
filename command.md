# Workflow Git de l'équipe

## 1. Travailler sur sa branche

Bernice :

```bash
git checkout bernice
```

Mounir :

```bash
git checkout mounir
```

---

## 2. Enregistrer les modifications

```bash
git add .
git commit -m "Description des modifications"
git push origin <nom-de-la-branche>
```

Exemple :

```bash
git push origin bernice
```

ou

```bash
git push origin mounir
```

---

## 3. Envoyer les modifications vers `develop`

Une fois la fonctionnalité terminée, créer un **Pull Request** sur GitHub :

```
bernice  →  develop
```

ou

```
mounir  →  develop
```

Après validation, fusionner le Pull Request.

git pull origin develop/main en local

> Il est aussi possible de faire le merge en local, mais le Pull Request est recommandé pour garder un historique clair et détecter les conflits avant la fusion.

---

## 4. Récupérer les mises à jour de `develop`

Après chaque fusion dans `develop`, chaque développeur met à jour sa branche :

```bash
git checkout bernice
git fetch origin
git merge origin/develop
git push origin bernice
```

ou

```bash
git checkout mounir
git fetch origin
git merge origin/develop
git push origin mounir
```

---

## 5. Envoyer `develop` vers `main`

Lorsque les fonctionnalités ont été testées et validées, créer un **Pull Request** :

```
develop  →  main
```

Après validation, fusionner le Pull Request.

Le code de `main` devient alors la version stable du projet.
