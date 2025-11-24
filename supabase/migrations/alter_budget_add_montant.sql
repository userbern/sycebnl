-- Migration pour modifier la table budget
-- Supprimer la colonne exercice
-- Ajouter la colonne montant

-- Vérifier si la colonne exercice existe avant de la supprimer
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'budget' AND column_name = 'exercice') THEN
        ALTER TABLE budget DROP COLUMN exercice;
    END IF;
END $$;

-- Ajouter la colonne montant si elle n'existe pas
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'budget' AND column_name = 'montant') THEN
        ALTER TABLE budget ADD COLUMN montant DECIMAL(15,2) DEFAULT 0;
    END IF;
END $$;

-- Commentaire sur la nouvelle colonne
COMMENT ON COLUMN budget.montant IS 'Montant initial alloué au budget';
COMMENT ON COLUMN budget.montant_total IS 'Montant total calculé automatiquement (somme des postes budgétaires)';
