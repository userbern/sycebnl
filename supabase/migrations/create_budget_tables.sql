-- Table budget (affecté à un projet)
CREATE TABLE IF NOT EXISTS budget (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) NOT NULL UNIQUE,
  designation TEXT NOT NULL,
  projet_id UUID NOT NULL REFERENCES projet(id) ON DELETE CASCADE,
  montant DECIMAL(15,2) DEFAULT 0, -- Montant initial du budget
  montant_total DECIMAL(15,2) DEFAULT 0, -- Calculé automatiquement (somme des postes)
  statut VARCHAR(20) DEFAULT 'brouillon', -- brouillon, validé, clôturé
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table poste_budgetaire (contient des lignes budgétaires)
CREATE TABLE IF NOT EXISTS poste_budgetaire (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) NOT NULL,
  designation TEXT NOT NULL,
  budget_id UUID NOT NULL REFERENCES budget(id) ON DELETE CASCADE,
  montant_total DECIMAL(15,2) DEFAULT 0, -- Somme des lignes budgétaires
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(budget_id, code)
);

-- Table ligne_budgetaire (contient des sous-rubriques)
CREATE TABLE IF NOT EXISTS ligne_budgetaire (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) NOT NULL,
  designation TEXT NOT NULL,
  poste_budgetaire_id UUID NOT NULL REFERENCES poste_budgetaire(id) ON DELETE CASCADE,
  numero_compte VARCHAR(20), -- N° Compte
  montant_total DECIMAL(15,2) DEFAULT 0, -- Somme des sous-rubriques
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(poste_budgetaire_id, code)
);

-- Table sous_rubrique_budgetaire
CREATE TABLE IF NOT EXISTS sous_rubrique_budgetaire (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) NOT NULL,
  designation TEXT NOT NULL,
  ligne_budgetaire_id UUID NOT NULL REFERENCES ligne_budgetaire(id) ON DELETE CASCADE,
  montant DECIMAL(15,2) NOT NULL DEFAULT 0,
  numero_compte VARCHAR(20), -- N° Compte
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(ligne_budgetaire_id, code)
);

-- Index pour recherche rapide
CREATE INDEX idx_budget_projet ON budget(projet_id);
CREATE INDEX idx_budget_code ON budget(code);
CREATE INDEX idx_poste_budget ON poste_budgetaire(budget_id);
CREATE INDEX idx_ligne_poste ON ligne_budgetaire(poste_budgetaire_id);
CREATE INDEX idx_sous_rubrique_ligne ON sous_rubrique_budgetaire(ligne_budgetaire_id);

-- Fonction pour mettre à jour le montant d'une ligne budgétaire
CREATE OR REPLACE FUNCTION update_ligne_budgetaire_montant()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE ligne_budgetaire
  SET montant_total = (
    SELECT COALESCE(SUM(montant), 0)
    FROM sous_rubrique_budgetaire
    WHERE ligne_budgetaire_id = NEW.ligne_budgetaire_id
  ),
  updated_at = NOW()
  WHERE id = NEW.ligne_budgetaire_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour recalculer le montant de la ligne budgétaire
CREATE TRIGGER trigger_update_ligne_montant
AFTER INSERT OR UPDATE OR DELETE ON sous_rubrique_budgetaire
FOR EACH ROW EXECUTE FUNCTION update_ligne_budgetaire_montant();

-- Fonction pour mettre à jour le montant d'un poste budgétaire
CREATE OR REPLACE FUNCTION update_poste_budgetaire_montant()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE poste_budgetaire
  SET montant_total = (
    SELECT COALESCE(SUM(montant_total), 0)
    FROM ligne_budgetaire
    WHERE poste_budgetaire_id = NEW.poste_budgetaire_id
  ),
  updated_at = NOW()
  WHERE id = NEW.poste_budgetaire_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour recalculer le montant du poste budgétaire
CREATE TRIGGER trigger_update_poste_montant
AFTER INSERT OR UPDATE OR DELETE ON ligne_budgetaire
FOR EACH ROW EXECUTE FUNCTION update_poste_budgetaire_montant();

-- Fonction pour mettre à jour le montant total du budget
CREATE OR REPLACE FUNCTION update_budget_montant()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE budget
  SET montant_total = (
    SELECT COALESCE(SUM(montant_total), 0)
    FROM poste_budgetaire
    WHERE budget_id = NEW.budget_id
  ),
  updated_at = NOW()
  WHERE id = NEW.budget_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour recalculer le montant total du budget
CREATE TRIGGER trigger_update_budget_montant
AFTER INSERT OR UPDATE OR DELETE ON poste_budgetaire
FOR EACH ROW EXECUTE FUNCTION update_budget_montant();

-- Trigger pour updated_at
CREATE TRIGGER update_budget_updated_at 
BEFORE UPDATE ON budget
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_poste_budgetaire_updated_at 
BEFORE UPDATE ON poste_budgetaire
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ligne_budgetaire_updated_at 
BEFORE UPDATE ON ligne_budgetaire
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sous_rubrique_budgetaire_updated_at 
BEFORE UPDATE ON sous_rubrique_budgetaire
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

-- Activation de la sécurité au niveau des lignes (RLS)
ALTER TABLE budget ENABLE ROW LEVEL SECURITY;
ALTER TABLE poste_budgetaire ENABLE ROW LEVEL SECURITY;
ALTER TABLE ligne_budgetaire ENABLE ROW LEVEL SECURITY;
ALTER TABLE sous_rubrique_budgetaire ENABLE ROW LEVEL SECURITY;

-- Politiques pour budget
CREATE POLICY "Enable read access for authenticated users" ON budget
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable insert access for authenticated users" ON budget
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users" ON budget
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Enable delete access for authenticated users" ON budget
  FOR DELETE TO authenticated USING (true);

-- Politiques pour poste_budgetaire
CREATE POLICY "Enable read access for authenticated users" ON poste_budgetaire
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable insert access for authenticated users" ON poste_budgetaire
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users" ON poste_budgetaire
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Enable delete access for authenticated users" ON poste_budgetaire
  FOR DELETE TO authenticated USING (true);

-- Politiques pour ligne_budgetaire
CREATE POLICY "Enable read access for authenticated users" ON ligne_budgetaire
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable insert access for authenticated users" ON ligne_budgetaire
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users" ON ligne_budgetaire
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Enable delete access for authenticated users" ON ligne_budgetaire
  FOR DELETE TO authenticated USING (true);

-- Politiques pour sous_rubrique_budgetaire
CREATE POLICY "Enable read access for authenticated users" ON sous_rubrique_budgetaire
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable insert access for authenticated users" ON sous_rubrique_budgetaire
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users" ON sous_rubrique_budgetaire
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Enable delete access for authenticated users" ON sous_rubrique_budgetaire
  FOR DELETE TO authenticated USING (true);

-- Commentaires
COMMENT ON TABLE budget IS 'Budgets affectés aux projets';
COMMENT ON TABLE poste_budgetaire IS 'Postes budgétaires contenant des lignes budgétaires';
COMMENT ON TABLE ligne_budgetaire IS 'Lignes budgétaires contenant des sous-rubriques';
COMMENT ON TABLE sous_rubrique_budgetaire IS 'Sous-rubriques budgétaires avec montants détaillés';
