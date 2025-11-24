-- RLS Policy : Seuls les admins peuvent voir TOUS les utilisateurs
-- Les utilisateurs normaux ne voient que leur propre profil

-- Désactiver les policies existantes sur la table utilisateur d'abord
DROP POLICY IF EXISTS "select_utilisateur" ON public.utilisateur;
DROP POLICY IF EXISTS "update_utilisateur" ON public.utilisateur;
DROP POLICY IF EXISTS "insert_utilisateur" ON public.utilisateur;

-- 1. Policy SELECT - Les admins voient tout, les autres ne voient qu'eux-mêmes
CREATE POLICY "select_utilisateur_policy" ON public.utilisateur
FOR SELECT
USING (
  -- L'utilisateur est admin OU il demande son propre profil
  (SELECT role FROM public.utilisateur WHERE id = auth.uid()) = 'admin'
  OR id = auth.uid()
);

-- 2. Policy UPDATE - Les admins peuvent modifier tous les utilisateurs
CREATE POLICY "update_utilisateur_policy" ON public.utilisateur
FOR UPDATE
USING (
  (SELECT role FROM public.utilisateur WHERE id = auth.uid()) = 'admin'
);

-- 3. Policy INSERT - Seulement via la fonction create_user_profile (SECURITY DEFINER)
-- Les utilisateurs normaux ne peuvent pas insérer
CREATE POLICY "insert_utilisateur_policy" ON public.utilisateur
FOR INSERT
WITH CHECK (false);

-- 4. Policy DELETE - Seulement les admins peuvent supprimer des utilisateurs
CREATE POLICY "delete_utilisateur_policy" ON public.utilisateur
FOR DELETE
USING (
  (SELECT role FROM public.utilisateur WHERE id = auth.uid()) = 'admin'
);

-- RLS Policy pour la table permissions : Les admins gèrent les permissions
DROP POLICY IF EXISTS "select_permissions" ON public.permissions;
DROP POLICY IF EXISTS "insert_permissions" ON public.permissions;
DROP POLICY IF EXISTS "update_permissions" ON public.permissions;
DROP POLICY IF EXISTS "delete_permissions" ON public.permissions;

-- 1. Policy SELECT - Tous les utilisateurs voient les permissions de TOUS (utile pour affichage)
CREATE POLICY "select_permissions_policy" ON public.permissions
FOR SELECT
USING (true);

-- 2. Policy INSERT - Seulement les admins peuvent créer des permissions
CREATE POLICY "insert_permissions_policy" ON public.permissions
FOR INSERT
WITH CHECK (
  (SELECT role FROM public.utilisateur WHERE id = auth.uid()) = 'admin'
);

-- 3. Policy UPDATE - Seulement les admins peuvent modifier les permissions
CREATE POLICY "update_permissions_policy" ON public.permissions
FOR UPDATE
USING (
  (SELECT role FROM public.utilisateur WHERE id = auth.uid()) = 'admin'
);

-- 4. Policy DELETE - Seulement les admins peuvent supprimer les permissions
CREATE POLICY "delete_permissions_policy" ON public.permissions
FOR DELETE
USING (
  (SELECT role FROM public.utilisateur WHERE id = auth.uid()) = 'admin'
);
