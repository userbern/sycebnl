-- Table projet pour la gestion des projets
CREATE TABLE IF NOT EXISTS projet (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) NOT NULL UNIQUE,
  designation TEXT NOT NULL,
  date_debut DATE,
  date_fin DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table de liaison entre projets et bailleurs (relation many-to-many)
CREATE TABLE IF NOT EXISTS projet_bailleur (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  projet_id UUID NOT NULL REFERENCES projet(id) ON DELETE CASCADE,
  bailleur_id UUID NOT NULL REFERENCES bailleur(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(projet_id, bailleur_id)
);

-- Index pour recherche rapide
CREATE INDEX idx_projet_code ON projet(code);
CREATE INDEX idx_projet_bailleur_projet ON projet_bailleur(projet_id);
CREATE INDEX idx_projet_bailleur_bailleur ON projet_bailleur(bailleur_id);

-- Trigger pour updated_at sur la table projet
CREATE TRIGGER update_projet_updated_at 
BEFORE UPDATE ON projet
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

-- Activation de la sécurité au niveau des lignes (RLS)
ALTER TABLE projet ENABLE ROW LEVEL SECURITY;
ALTER TABLE projet_bailleur ENABLE ROW LEVEL SECURITY;

-- Politiques pour la table projet
CREATE POLICY "Enable read access for authenticated users" ON projet
  FOR SELECT 
  TO authenticated 
  USING (true);

CREATE POLICY "Enable insert access for authenticated users" ON projet
  FOR INSERT 
  TO authenticated 
  WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users" ON projet
  FOR UPDATE 
  TO authenticated 
  USING (true);

CREATE POLICY "Enable delete access for authenticated users" ON projet
  FOR DELETE 
  TO authenticated 
  USING (true);

-- Politiques pour la table projet_bailleur
CREATE POLICY "Enable read access for authenticated users" ON projet_bailleur
  FOR SELECT 
  TO authenticated 
  USING (true);

CREATE POLICY "Enable insert access for authenticated users" ON projet_bailleur
  FOR INSERT 
  TO authenticated 
  WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users" ON projet_bailleur
  FOR UPDATE 
  TO authenticated 
  USING (true);

CREATE POLICY "Enable delete access for authenticated users" ON projet_bailleur
  FOR DELETE 
  TO authenticated 
  USING (true);

-- Commentaires sur les tables et colonnes
COMMENT ON TABLE projet IS 'Table des projets';
COMMENT ON COLUMN projet.id IS 'Identifiant unique du projet';
COMMENT ON COLUMN projet.code IS 'Code unique du projet';
COMMENT ON COLUMN projet.designation IS 'Nom complet ou désignation du projet';
COMMENT ON COLUMN projet.date_debut IS 'Date de début du projet';
COMMENT ON COLUMN projet.date_fin IS 'Date de fin du projet';
COMMENT ON COLUMN projet.created_at IS 'Date de création de l''enregistrement';
COMMENT ON COLUMN projet.updated_at IS 'Date de dernière modification';

COMMENT ON TABLE projet_bailleur IS 'Table de liaison entre projets et bailleurs (relation many-to-many)';
COMMENT ON COLUMN projet_bailleur.id IS 'Identifiant unique de la relation';
COMMENT ON COLUMN projet_bailleur.projet_id IS 'Référence au projet';
COMMENT ON COLUMN projet_bailleur.bailleur_id IS 'Référence au bailleur';
COMMENT ON COLUMN projet_bailleur.created_at IS 'Date de création de la relation';
