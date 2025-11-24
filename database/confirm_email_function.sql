-- Fonction pour confirmer l'email d'un utilisateur
CREATE OR REPLACE FUNCTION public.confirm_user_email(user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE auth.users
  SET email_confirmed_at = NOW()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- Vérifier que la fonction existe
SELECT routine_name FROM information_schema.routines 
WHERE routine_name = 'confirm_user_email';
