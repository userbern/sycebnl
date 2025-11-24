-- Insérer toutes les permissions pour l'utilisateur f01ac0ea-da4f-4c67-8fbd-e3c6d38aa8d5
INSERT INTO permissions (utilisateur_id, module_id, lecture, ajout, modification, suppression)
VALUES
  ('f01ac0ea-da4f-4c67-8fbd-e3c6d38aa8d5', 1, TRUE, TRUE, TRUE, TRUE),
  ('f01ac0ea-da4f-4c67-8fbd-e3c6d38aa8d5', 2, TRUE, TRUE, TRUE, TRUE),
  ('f01ac0ea-da4f-4c67-8fbd-e3c6d38aa8d5', 3, TRUE, TRUE, TRUE, TRUE),
  ('f01ac0ea-da4f-4c67-8fbd-e3c6d38aa8d5', 4, TRUE, TRUE, TRUE, TRUE)
ON CONFLICT (utilisateur_id, module_id) DO UPDATE
SET lecture = TRUE, ajout = TRUE, modification = TRUE, suppression = TRUE;
