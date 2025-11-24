-- Table bailleur pour la gestion des bailleurs de fonds
CREATE TABLE IF NOT EXISTS bailleur (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sigle VARCHAR(50) NOT NULL UNIQUE,
  designation TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour recherche rapide par sigle
CREATE INDEX idx_bailleur_sigle ON bailleur(sigle);

-- Fonction trigger pour mettre à jour automatiquement updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger pour updated_at sur la table bailleur
CREATE TRIGGER update_bailleur_updated_at 
BEFORE UPDATE ON bailleur
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

-- Activation de la sécurité au niveau des lignes (RLS)
ALTER TABLE bailleur ENABLE ROW LEVEL SECURITY;

-- Politique : Lecture pour les utilisateurs authentifiés
CREATE POLICY "Enable read access for authenticated users" ON bailleur
  FOR SELECT 
  TO authenticated 
  USING (true);

-- Politique : Insertion pour les utilisateurs authentifiés
CREATE POLICY "Enable insert access for authenticated users" ON bailleur
  FOR INSERT 
  TO authenticated 
  WITH CHECK (true);

-- Politique : Mise à jour pour les utilisateurs authentifiés
CREATE POLICY "Enable update access for authenticated users" ON bailleur
  FOR UPDATE 
  TO authenticated 
  USING (true);

-- Politique : Suppression pour les utilisateurs authentifiés
CREATE POLICY "Enable delete access for authenticated users" ON bailleur
  FOR DELETE 
  TO authenticated 
  USING (true);

-- Commentaires sur la table et les colonnes
COMMENT ON TABLE bailleur IS 'Table des bailleurs de fonds';
COMMENT ON COLUMN bailleur.id IS 'Identifiant unique du bailleur';
COMMENT ON COLUMN bailleur.sigle IS 'Sigle ou code court du bailleur (unique)';
COMMENT ON COLUMN bailleur.designation IS 'Nom complet ou désignation du bailleur';
COMMENT ON COLUMN bailleur.created_at IS 'Date de création de l''enregistrement';
COMMENT ON COLUMN bailleur.updated_at IS 'Date de dernière modification';
