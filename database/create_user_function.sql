-- Supprimer la fonction si elle existe
DROP FUNCTION IF EXISTS public.create_user_profile(UUID, VARCHAR, VARCHAR, VARCHAR);

-- Créer la fonction
CREATE OR REPLACE FUNCTION public.create_user_profile(
  user_id UUID,
  user_email VARCHAR,
  user_prenom VARCHAR,
  user_nom VARCHAR
)
RETURNS void AS $$
BEGIN
  INSERT INTO public.utilisateur (id, email, prenom, nom, role)
  VALUES (user_id, user_email, user_prenom, user_nom, 'utilisateur');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Vérifier que la fonction existe
SELECT routine_name FROM information_schema.routines 
WHERE routine_name = 'create_user_profile';
