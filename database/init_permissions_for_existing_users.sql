-- Fonction pour initialiser les permissions pour les utilisateurs existants
CREATE OR REPLACE FUNCTION public.init_permissions_for_existing_users()
RETURNS void AS $$
BEGIN
  -- Insérer les permissions par défaut pour tous les utilisateurs qui n'en ont pas
  INSERT INTO public.permissions (utilisateur_id, module_id, lecture, ajout, modification, suppression)
  SELECT u.id, m.id, FALSE, FALSE, FALSE, FALSE
  FROM public.utilisateur u
  CROSS JOIN public.modules m
  WHERE NOT EXISTS (
    SELECT 1 FROM public.permissions p
    WHERE p.utilisateur_id = u.id
    AND p.module_id = m.id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Exécuter la fonction pour initialiser les permissions
SELECT public.init_permissions_for_existing_users();
