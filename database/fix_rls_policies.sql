-- Créer une fonction pour insérer un utilisateur (bypass RLS)
CREATE OR REPLACE FUNCTION create_user_profile(
  user_id UUID,
  user_email VARCHAR,
  user_prenom VARCHAR,
  user_nom VARCHAR
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO utilisateur (id, email, prenom, nom, role)
  VALUES (user_id, user_email, user_prenom, user_nom, 'utilisateur');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Désactiver temporairement les RLS pour fix
ALTER TABLE utilisateur DISABLE ROW LEVEL SECURITY;

-- Supprimer les anciennes policies s'il y en a
DROP POLICY IF EXISTS "Enable insert for new users" ON utilisateur;
DROP POLICY IF EXISTS "Enable read for all users" ON utilisateur;
DROP POLICY IF EXISTS "Enable update for users" ON utilisateur;

-- Créer une politique pour permettre la lecture de tous les utilisateurs
CREATE POLICY "Enable read for all users" 
ON utilisateur 
FOR SELECT 
USING (TRUE);

-- Créer une politique pour permettre la modification de ses propres données
CREATE POLICY "Enable update for users" 
ON utilisateur 
FOR UPDATE 
USING (auth.uid() = id);

-- Réactiver les RLS
ALTER TABLE utilisateur ENABLE ROW LEVEL SECURITY;

-- Policy pour permissions table
ALTER TABLE permissions DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read permissions" ON permissions;
DROP POLICY IF EXISTS "Enable manage permissions for admins" ON permissions;

-- Policy pour lire les permissions
CREATE POLICY "Enable read permissions" 
ON permissions 
FOR SELECT 
USING (TRUE);

-- Policy pour créer les permissions (INSERT)
CREATE POLICY "Enable insert permissions" 
ON permissions 
FOR INSERT 
WITH CHECK (TRUE);

-- Policy pour mettre à jour les permissions
CREATE POLICY "Enable update permissions" 
ON permissions 
FOR UPDATE 
USING (TRUE)
WITH CHECK (TRUE);

-- Policy pour supprimer les permissions
CREATE POLICY "Enable delete permissions" 
ON permissions 
FOR DELETE 
USING (TRUE);

ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
