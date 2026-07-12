# Commandes Codex

Ces commandes servent de raccourcis conceptuels pour lancer les workflows du système.

## `/plan`

- Rôle: transformer une demande en plan de travail.
- Agents: Orchestrateur, Architecte, agents spécialisés selon le sujet.
- Résultat attendu: découpage, ordre d'exécution, validations.

## `/new-module`

- Rôle: créer un nouveau module fonctionnel.
- Agents: Orchestrateur, Architecte, Développeur Flutter, Expert Riverpod, Expert SQLite si nécessaire.
- Résultat attendu: structure du module, intégration, validation.

## `/new-feature`

- Rôle: ajouter une fonctionnalité existante ou nouvelle.
- Agents: Orchestrateur, expert du domaine, Développeur Flutter, Expert Riverpod, Expert SQLite si nécessaire, QA.
- Résultat attendu: implémentation validée et documentée.

## `/refactor`

- Rôle: améliorer la structure sans changer le comportement.
- Agents: Orchestrateur, Architecte, agent de la couche concernée, Reviewer.
- Résultat attendu: code plus lisible et moins dupliqué.

## `/review`

- Rôle: produire une revue de code.
- Agents: Reviewer, éventuellement Architecte ou QA.
- Résultat attendu: findings, risques, verdict.

## `/qa`

- Rôle: préparer ou exécuter la validation fonctionnelle.
- Agents: QA, Orchestrateur, agent du domaine concerné.
- Résultat attendu: scénarios, cas limites, verdict.

## `/report`

- Rôle: produire un compte-rendu synthétique.
- Agents: Orchestrateur.
- Résultat attendu: rapport final ou rapport de statut.

## `/context`

- Rôle: rappeler le contexte utile à une tâche.
- Agents: Orchestrateur.
- Résultat attendu: contexte pertinent et compact.

## `/status`

- Rôle: afficher l'état d'avancement du système ou d'une mission.
- Agents: Orchestrateur.
- Résultat attendu: avancement, blocages, prochaines actions.

## `/continue`

- Rôle: reprendre une mission déjà commencée.
- Agents: Orchestrateur et agents déjà engagés.
- Résultat attendu: suite logique sans répéter le contexte complet.

## `/finish`

- Rôle: clôturer une mission.
- Agents: Orchestrateur.
- Résultat attendu: rapport final et mémoire mise à jour.
