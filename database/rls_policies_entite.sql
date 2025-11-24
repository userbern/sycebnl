-- ================================================
-- RLS POLICIES pour la table ENTITE
-- ================================================
-- Les utilisateurs peuvent LIRE les entités
-- SEULEMENT les admins peuvent CRÉER/MODIFIER/SUPPRIMER

-- 1. Policy SELECT - Tous peuvent lire les entités actives
CREATE POLICY "select_entite_policy" ON public.entite
FOR SELECT
USING (is_active = true);

-- 2. Policy INSERT - Seulement les admins peuvent créer
CREATE POLICY "insert_entite_policy" ON public.entite
FOR INSERT
WITH CHECK (
  (SELECT role FROM public.utilisateur WHERE id = auth.uid()) = 'admin'
);

-- 3. Policy UPDATE - Seulement les admins peuvent modifier
CREATE POLICY "update_entite_policy" ON public.entite
FOR UPDATE
USING (
  (SELECT role FROM public.utilisateur WHERE id = auth.uid()) = 'admin'
)
WITH CHECK (
  (SELECT role FROM public.utilisateur WHERE id = auth.uid()) = 'admin'
);

-- 4. Policy DELETE - Seulement les admins peuvent supprimer (soft delete)
CREATE POLICY "delete_entite_policy" ON public.entite
FOR DELETE
USING (
  (SELECT role FROM public.utilisateur WHERE id = auth.uid()) = 'admin'
);

-- 5. Optionnel: Vérifier que created_by est bien l'utilisateur connecté
-- (automatiquement défini par trigger ou application)
