-- Fonction pour créer les permissions par défaut pour un utilisateur
CREATE OR REPLACE FUNCTION public.create_default_permissions(user_id UUID)
RETURNS void AS $$
BEGIN
  -- Insérer les permissions par défaut (toutes à FALSE) pour chaque module
  INSERT INTO public.permissions (utilisateur_id, module_id, lecture, ajout, modification, suppression)
  SELECT user_id, id, FALSE, FALSE, FALSE, FALSE
  FROM public.modules
  WHERE NOT EXISTS (
    SELECT 1 FROM public.permissions 
    WHERE permissions.utilisateur_id = user_id 
    AND permissions.module_id = modules.id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
