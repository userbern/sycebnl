/* Activer RLS */
ALTER TABLE utilisateur ENABLE ROW LEVEL SECURITY;

/* Policy : un utilisateur peut voir seulement son propre profil */
CREATE POLICY "Utilisateur lit son propre profil"
ON utilisateur
FOR SELECT
USING (id = auth.uid());


/* Policy : un utilisateur peut mettre à jour seulement son propre profil */
CREATE POLICY "Utilisateur met à jour son propre profil"
ON utilisateur
FOR UPDATE
USING (id = auth.uid());

/* Policy admin : un admin peut lire tout */
CREATE POLICY "Admin lit tous les profils"
ON utilisateur
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM utilisateur u
    WHERE u.id = auth.uid() AND u.role = 'admin'
  )
);

/* Policy admin : un admin peut mettre à jour tout */
CREATE POLICY "Admin met à jour tous les profils"
ON utilisateur
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM utilisateur u
    WHERE u.id = auth.uid() AND u.role = 'admin'
  )
);


SELECT auth.admin.create_user(
  email => 'nice82094@gmail.com',
  password => 'Nice@1234',
  email_confirm => true
) AS admin_user;
