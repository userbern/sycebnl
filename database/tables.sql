CREATE TABLE utilisateur (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nom VARCHAR(100),
  prenom VARCHAR(100),
  email VARCHAR(100) UNIQUE NOT NULL,
  role role_type DEFAULT 'utilisateur',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_timestamp_trigger
BEFORE UPDATE ON utilisateur
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();



CREATE TABLE modules (
  id SERIAL PRIMARY KEY,
  nom VARCHAR(100) UNIQUE NOT NULL
);

INSERT INTO modules (nom) VALUES
('notre_entite'),
('parametrages'),
('traitements'),
('edition');


CREATE TABLE permissions (
  id SERIAL PRIMARY KEY,
  utilisateur_id UUID REFERENCES utilisateur(id) ON DELETE CASCADE,
  module_id INTEGER REFERENCES modules(id) ON DELETE CASCADE,
  lecture BOOLEAN DEFAULT FALSE,
  ajout BOOLEAN DEFAULT FALSE,
  modification BOOLEAN DEFAULT FALSE,
  suppression BOOLEAN DEFAULT FALSE,
  UNIQUE (utilisateur_id, module_id)
);
