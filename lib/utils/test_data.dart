/// Données de test/fixture pour développement et tests
/// À utiliser pour pré-remplir l'application sans saisie manuelle

class TestData {
  /// Données pour la table exercice
  static const List<Map<String, dynamic>> exercices = [
    {
      'code': '2024',
      'date_debut': '2024-01-01',
      'date_fin': '2024-12-31',
      'duree_mois': 12,
      'is_active': 1,
      'is_cloture': 0
    },
    {
      'code': '2025',
      'date_debut': '2025-01-01',
      'date_fin': '2025-12-31',
      'duree_mois': 12,
      'is_active': 1,
      'is_cloture': 0
    },
  ];

   /// Comptes de test
  static const List<Map<String, dynamic>> comptes = [
    // Classe 1 - Actif fixe
    {
      'numero_compte': '10',
      'intitule': 'Dotations',
      'type': 'total',
      'soldeDebit': 2500000,
      'soldeCredit': 0,
      'mouvementDebit': 250000,
      'mouvementCredit': 0,
      'soldeClotureDebit': 2750000,
      'soldeClotureCredit': 0,
    },
    {
      'numero_compte': '11',
      'intitule': 'Installations techniques',
      'type': 'total',
      'soldeDebit': 1200000,
      'soldeCredit': 0,
      'mouvementDebit': 150000,
      'mouvementCredit': 0,
      'soldeClotureDebit': 1350000,
      'soldeClotureCredit': 0,
    },
    {
      'numero_compte': '13',
      'intitule': 'Mobilier et équipement',
      'classe': 1,
      'soldeDebit': 800000,
      'soldeCredit': 0,
      'mouvementDebit': 100000,
      'mouvementCredit': 0,
      'soldeClotureDebit': 900000,
      'soldeClotureCredit': 0,
    },
    {
      'numero_compte': '14',
      'intitule': 'Amortissements',
      'classe': 1,
      'soldeDebit': 0,
      'soldeCredit': 800000,
      'mouvementDebit': 0,
      'mouvementCredit': 120000,
      'soldeClotureDebit': 0,
      'soldeClotureCredit': 920000,
    },
    // Classe 2 - Actif circulant
    {
      'numero_compte': '21',
      'intitule': 'Stocks de matières premières',
      'classe': 2,
      'soldeDebit': 500000,
      'soldeCredit': 0,
      'mouvementDebit': 300000,
      'mouvementCredit': 200000,
      'soldeClotureDebit': 600000,
      'soldeClotureCredit': 0,
    },
    {
      'numero_compte': '220',
      'intitule': 'Créances clients',
      'classe': 2,
      'soldeDebit': 750000,
      'soldeCredit': 0,
      'mouvementDebit': 450000,
      'mouvementCredit': 300000,
      'soldeClotureDebit': 900000,
      'soldeClotureCredit': 0,
    },
    {
      'numero_compte': '230',
      'intitule': 'Banques et caisses',
      'classe': 2,
      'soldeDebit': 2000000,
      'soldeCredit': 0,
      'mouvementDebit': 1500000,
      'mouvementCredit': 1200000,
      'soldeClotureDebit': 2300000,
      'soldeClotureCredit': 0,
    },
    // Classe 3 - Dettes à long terme
    {
      'numero_compte': '310',
      'intitule': 'Dettes financières à long terme',
      'classe': 3,
      'soldeDebit': 0,
      'soldeCredit': 3000000,
      'mouvementDebit': 500000,
      'mouvementCredit': 200000,
      'soldeClotureDebit': 0,
      'soldeClotureCredit': 2700000,
    },
    {
      'numero_compte': '320',
      'intitule': 'Dettes fournisseurs long terme',
      'classe': 3,
      'soldeDebit': 0,
      'soldeCredit': 1200000,
      'mouvementDebit': 0,
      'mouvementCredit': 100000,
      'soldeClotureDebit': 0,
      'soldeClotureCredit': 1300000,
    },
    // Classe 4 - Passif courant
    {
      'numero_compte': '410',
      'intitule': 'Dettes fournisseurs',
      'classe': 4,
      'soldeDebit': 0,
      'soldeCredit': 450000,
      'mouvementDebit': 300000,
      'mouvementCredit': 250000,
      'soldeClotureDebit': 0,
      'soldeClotureCredit': 400000,
    },
    {
      'numero_compte': '420',
      'intitule': 'Dettes fiscales et sociales',
      'classe': 4,
      'soldeDebit': 0,
      'soldeCredit': 280000,
      'mouvementDebit': 150000,
      'mouvementCredit': 120000,
      'soldeClotureDebit': 0,
      'soldeClotureCredit': 250000,
    },
    // Classe 5 - Capitaux propres
    {
      'numero_compte': '510',
      'intitule': 'Capital social',
      'classe': 5,
      'soldeDebit': 0,
      'soldeCredit': 5000000,
      'mouvementDebit': 0,
      'mouvementCredit': 0,
      'soldeClotureDebit': 0,
      'soldeClotureCredit': 5000000,
    },
    {
      'numero_compte': '520',
      'intitule': 'Réserves',
      'classe': 5,
      'soldeDebit': 0,
      'soldeCredit': 1000000,
      'mouvementDebit': 0,
      'mouvementCredit': 0,
      'soldeClotureDebit': 0,
      'soldeClotureCredit': 1000000,
    },
    {
      'numero_compte': '530',
      'intitule': 'Résultat de l\'exercice',
      'classe': 5,
      'soldeDebit': 0,
      'soldeCredit': 500000,
      'mouvementDebit': 0,
      'mouvementCredit': 0,
      'soldeClotureDebit': 0,
      'soldeClotureCredit': 500000,
    },
    // Classe 6 - Charges
    {
      'numero_compte': '610',
      'intitule': 'Achats de matières premières',
      'classe': 6,
      'soldeDebit': 2000000,
      'soldeCredit': 0,
      'mouvementDebit': 1200000,
      'mouvementCredit': 0,
      'soldeClotureDebit': 3200000,
      'soldeClotureCredit': 0,
    },
    {
      'numero_compte': '620',
      'intitule': 'Frais de personnel',
      'classe': 6,
      'soldeDebit': 1500000,
      'soldeCredit': 0,
      'mouvementDebit': 500000,
      'mouvementCredit': 0,
      'soldeClotureDebit': 2000000,
      'soldeClotureCredit': 0,
    },
    {
      'numero_compte': '630',
      'intitule': 'Frais généraux',
      'classe': 6,
      'soldeDebit': 800000,
      'soldeCredit': 0,
      'mouvementDebit': 300000,
      'mouvementCredit': 0,
      'soldeClotureDebit': 1100000,
      'soldeClotureCredit': 0,
    },
    {
      'numero_compte': '640',
      'intitule': 'Amortissements et dépréciations',
      'classe': 6,
      'soldeDebit': 300000,
      'soldeCredit': 0,
      'mouvementDebit': 120000,
      'mouvementCredit': 0,
      'soldeClotureDebit': 420000,
      'soldeClotureCredit': 0,
    },
    // Classe 7 - Produits
    {
      'numero_compte': '710',
      'intitule': 'Ventes de produits',
      'classe': 7,
      'soldeDebit': 0,
      'soldeCredit': 3500000,
      'mouvementDebit': 0,
      'mouvementCredit': 1800000,
      'soldeClotureDebit': 0,
      'soldeClotureCredit': 5300000,
    },
    {
      'numero_compte': '720',
      'intitule': 'Prestations de services',
      'classe': 7,
      'soldeDebit': 0,
      'soldeCredit': 1200000,
      'mouvementDebit': 0,
      'mouvementCredit': 600000,
      'soldeClotureDebit': 0,
      'soldeClotureCredit': 1800000,
    },
    {
      'numero_compte': '730',
      'intitule': 'Produits financiers',
      'classe': 7,
      'soldeDebit': 0,
      'soldeCredit': 150000,
      'mouvementDebit': 0,
      'mouvementCredit': 50000,
      'soldeClotureDebit': 0,
      'soldeClotureCredit': 200000,
    },
  ];


  /// Projets de test
  static const List<Map<String, dynamic>> projets = [
    {
      'code': 'PCB',
      'designation': 'Projet Construction Bâtiment',
      'date_debut': '2025-01-15',
      'date_fin': '2025-12-31'
    },
    {
      'code': 'PER',
      'designation': 'Projet Électrification Rurale',
      'date_debut': '2024-03-01',
      'date_fin': '2026-02-28', 
    },
    {
      'code': 'PIR',
      'designation': 'Projet Infrastructure Routière',
      'date_debut': '2023-06-01',
      'date_fin': '2025-05-31',
    },
    {
      'code': 'PSI',
      'designation': 'Projet Système Informatique',
      'date_debut': '2024-09-01',
      'date_fin': '2025-08-31',
    },
  ];

  

  /// Bailleurs de test
  static const List<Map<String, dynamic>> bailleurs = [
    {
      'id': 1,
      'designation': 'Banque Mondiale',
      'sigle': 'BM',
      'adresse': '1818 H Street NW, Washington',
      'telephone': '+1-202-473-1000',
      'email': 'info@worldbank.org',
      'montantFinance': 15000000,
    },
    {
      'id': 2,
      'designation': 'Fonds Monétaire International',
      'sigle': 'FMI',
      'adresse': '700 19th Street NW, Washington',
      'telephone': '+1-202-623-7000',
      'email': 'publicaffairs@imf.org',
      'montantFinance': 8000000,
    },
    {
      'id': 3,
      'designation': 'Agence Française de Développement',
      'sigle': 'AFD',
      'adresse': '5 rue de Monttessuy, Paris',
      'telephone': '+33-1-53-44-31-31',
      'email': 'contact@afd.fr',
      'montantFinance': 6500000,
    },
    {
      'id': 4,
      'designation': 'Programme des Nations Unies',
      'sigle': 'PNUD',
      'adresse': '1 UN Plaza, New York',
      'telephone': '+1-212-906-5000',
      'email': 'registry@undp.org',
      'montantFinance': 4200000,
    },
    {
      'id': 5,
      'designation': 'Union Européenne',
      'sigle': 'UE',
      'adresse': 'Rue de la Loi 200, Bruxelles',
      'telephone': '+32-2-299-11-11',
      'email': 'info@europa.eu',
      'montantFinance': 5000000,
    },
  ];

 


  /// Journaux de test
  static const List<Map<String, dynamic>> journaux = [
    {
      'id': 1,
      'code': 'ACH',
      'designation': 'Journal d\'Achat',
      'description': 'Enregistrement des achats',
    },
    {
      'id': 2,
      'code': 'VEN',
      'designation': 'Journal de Vente',
      'description': 'Enregistrement des ventes',
    },
    {
      'id': 3,
      'code': 'BQ',
      'designation': 'Journal de Banque',
      'description': 'Enregistrement des opérations bancaires',
    },
    {
      'id': 4,
      'code': 'OD',
      'designation': 'Journal d\'Opérations Diverses',
      'description': 'Enregistrement des écritures diverses',
    },
    {
      'id': 5,
      'code': 'PAY',
      'designation': 'Journal de Paie',
      'description': 'Enregistrement des salaires',
    },
  ];

  /// Tiers de test (clients et fournisseurs)
  static const List<Map<String, dynamic>> tiers = [
    {
      'id': 1,
      'designation': 'SARL Industrie Tech',
      'type': 'fournisseur',
      'numeroFiscal': 'TN123456789',
      'adresse': 'Rue Principale 15, Tunis',
      'telephone': '+216-71-123-456',
      'email': 'contact@industech.tn',
      'solde': 450000,
    },
    {
      'id': 2,
      'designation': 'Société Commerce Export',
      'type': 'client',
      'numeroFiscal': 'TN987654321',
      'adresse': 'Avenue Mohamed Ali 42, Sfax',
      'telephone': '+216-74-234-567',
      'email': 'info@comexport.tn',
      'solde': 750000,
    },
    {
      'id': 3,
      'designation': 'Cabinet Conseil Finances',
      'type': 'fournisseur',
      'numeroFiscal': 'TN456789123',
      'adresse': 'Bd de la République 8, Sousse',
      'telephone': '+216-73-345-678',
      'email': 'conseil@finances.tn',
      'solde': 125000,
    },
    {
      'id': 4,
      'designation': 'Entreprise Distribution Global',
      'type': 'client',
      'numeroFiscal': 'TN789123456',
      'adresse': 'Zone Industrielle, Bizerte',
      'telephone': '+216-72-456-789',
      'email': 'distribution@global.tn',
      'solde': 980000,
    },
    {
      'id': 5,
      'designation': 'Services Maintenance Plus',
      'type': 'fournisseur',
      'numeroFiscal': 'TN321654987',
      'adresse': 'Rue du Commerce 25, Gafsa',
      'telephone': '+216-76-567-890',
      'email': 'maintenance@plus.tn',
      'solde': 85000,
    },
  ];

  /// Données synthétisées pour un rapport rapide
  static Map<String, dynamic> getDataSynthese() {
    return {
      'totalActif': 9150000,
      'totalPassif': 9150000,
      'totalCharges': 6620000,
      'totalProduits': 7300000,
      'resultat': 680000,
      'tauxRendement': 9.3,
    };
  }

  /// Retourne des données aléatoires de test pour chaque appel
  static Map<String, dynamic> getRandomTestData() {
    final projet = projets[DateTime.now().millisecond % projets.length];
    final bailleur = bailleurs[DateTime.now().millisecond % bailleurs.length];

    return {
      'projet': projet,
      'bailleur': bailleur,
      'comptes': comptes,
      'tiers': tiers,
    };
  }

  /// Retourne une copie d'une liste avec des IDs décalés pour éviter les collisions BDD
  static List<Map<String, dynamic>> withIdOffset(
    List<Map<String, dynamic>> source, {
    int startId = 10000,
  }) {
    return List.generate(
      source.length,
      (index) => {...source[index], 'id': startId + index},
    );
  }

  static List<Map<String, dynamic>> projetsWithIds({int startId = 10000}) =>
      withIdOffset(projets, startId: startId);

  static List<Map<String, dynamic>> bailleursWithIds({int startId = 11000}) =>
      withIdOffset(bailleurs, startId: startId);

  static List<Map<String, dynamic>> tiersWithIds({int startId = 12000}) =>
      withIdOffset(tiers, startId: startId);

  static List<Map<String, dynamic>> journauxWithIds({int startId = 13000}) =>
      withIdOffset(journaux, startId: startId);

  static List<Map<String, dynamic>> exercicesWithIds({int startId = 14000}) =>
      withIdOffset(exercices, startId: startId);

  /// Ajoute un champ id aux comptes pour rester cohérent
  static List<Map<String, dynamic>> comptesWithIds({int startId = 15000}) =>
      withIdOffset(comptes, startId: startId);

  /// Fournit tous les jeux de données avec IDs décalés prêts à insérer
  static Map<String, dynamic> fixturesWithIds({int startId = 10000}) {
    return {
      'projets': projetsWithIds(startId: startId),
      'bailleurs': bailleursWithIds(startId: startId + 1000),
      'tiers': tiersWithIds(startId: startId + 2000),
      'journaux': journauxWithIds(startId: startId + 3000),
      'exercices': exercicesWithIds(startId: startId + 4000),
      'comptes': comptesWithIds(startId: startId + 5000),
    };
  }
}
