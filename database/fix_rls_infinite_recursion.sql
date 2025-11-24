-- Fix pour la boucle infinie dans les RLS policies
-- Exécutez ce script dans Supabase SQL Editor

-- 1. Désactiver RLS temporairement
ALTER TABLE utilisateur DISABLE ROW LEVEL SECURITY;

-- 2. Supprimer les anciennes policies problématiques
DROP POLICY IF EXISTS "Utilisateur lit son propre profil" ON utilisateur;
DROP POLICY IF EXISTS "Utilisateur met à jour son propre profil" ON utilisateur;
DROP POLICY IF EXISTS "Admin lit tous les profils" ON utilisateur;
DROP POLICY IF EXISTS "Admin met à jour tous les profils" ON utilisateur;

-- 3. Réactiver RLS
ALTER TABLE utilisateur ENABLE ROW LEVEL SECURITY;

-- 4. Créer les nouvelles policies (sans boucle infinie)

-- Policy: Tout le monde peut lire les utilisateurs (nécessaire pour la liste de login)
CREATE POLICY "Utilisateurs lisibles publiquement"
ON utilisateur
FOR SELECT
USING (true);

-- Policy: Un utilisateur peut mettre à jour son propre profil
CREATE POLICY "Utilisateur met à jour son profil"
ON utilisateur
FOR UPDATE
USING (id = auth.uid());

-- Policy: Un utilisateur admin peut mettre à jour n'importe quel profil
CREATE POLICY "Admin met à jour tous les profils"
ON utilisateur
FOR UPDATE
USING (auth.jwt() ->> 'role' = 'admin');

-- 5. RLS pour les permissions
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Utilisateur lit ses permissions" ON permissions;
DROP POLICY IF EXISTS "Admin lit toutes les permissions" ON permissions;

-- Policy: Un utilisateur peut lire ses propres permissions
CREATE POLICY "Utilisateur lit ses permissions"
ON permissions
FOR SELECT
USING (utilisateur_id = auth.uid());

-- Policy: Un admin peut lire toutes les permissions
CREATE POLICY "Admin lit toutes les permissions"
ON permissions
FOR SELECT
USING (auth.jwt() ->> 'role' = 'admin');

-- Policy: Un admin peut modifier les permissions
CREATE POLICY "Admin modifie les permissions"
ON permissions
FOR ALL
USING (auth.jwt() ->> 'role' = 'admin');
