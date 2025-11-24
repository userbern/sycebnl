-- ================================================
-- TABLE ENTITE (Identification)
-- ================================================
-- Cette table stocke les informations d'identification des entités
-- (associations, ONG, fondations, etc.)

-- 1. Créer un type ENUM pour les types d'organisations
CREATE TYPE public.ong_type AS ENUM (
  'association',
  'ong_locale',
  'ong_internationale',
  'ordre_professionnel',
  'fondation',
  'congregation_religieuse',
  'club_sportif',
  'club_services',
  'parti_politique'
);

-- 2. Créer la table entite
CREATE TABLE IF NOT EXISTS public.entite (
  -- Identifiants
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Informations principales
  denomination_sociale VARCHAR(255) NOT NULL,
  sigle_usuel VARCHAR(100),
  domaine_intervention VARCHAR(255),
  forme_juridique VARCHAR(100),
  ong_type public.ong_type,
  
  -- Localisation
  pays VARCHAR(100),
  region VARCHAR(100),
  ville VARCHAR(100),
  quartier VARCHAR(100),
  
  -- Contact
  email VARCHAR(255),
  telephone VARCHAR(20),
  fixe_fax VARCHAR(20),
  
  -- Identification administrative
  numero_fiscal VARCHAR(50),
  numero_cnss VARCHAR(50),
  numero_recepisse VARCHAR(50),
  
  -- Complément
  informations_complementaires TEXT,
  
  -- Métadonnées
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES public.utilisateur(id),
  
  -- Soft delete (optionnel)
  is_active BOOLEAN DEFAULT true
);

-- 3. Ajouter un index sur la dénomination sociale pour la recherche
CREATE INDEX IF NOT EXISTS idx_entite_denomination ON public.entite(denomination_sociale);
CREATE INDEX IF NOT EXISTS idx_entite_is_active ON public.entite(is_active);

-- 4. Créer une fonction trigger pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION public.update_entite_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Ajouter le trigger
DROP TRIGGER IF EXISTS trigger_entite_updated_at ON public.entite;
CREATE TRIGGER trigger_entite_updated_at
BEFORE UPDATE ON public.entite
FOR EACH ROW
EXECUTE FUNCTION public.update_entite_timestamp();

-- 6. Activer RLS
ALTER TABLE public.entite ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.entite IS 'Table des entités (organisations, associations, etc.)';
COMMENT ON COLUMN public.entite.denomination_sociale IS 'Nom officiel de l''entité';
COMMENT ON COLUMN public.entite.ong_type IS 'Type d''organisation: association, ONG locale, ONG internationale, etc.';
COMMENT ON COLUMN public.entite.created_by IS 'ID de l''utilisateur qui a créé la fiche';
