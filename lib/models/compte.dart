/// Types de compte comptable
enum TypeCompte { detail, total }

/// Extension pour convertir enum en string
extension TypeCompteExtension on TypeCompte {
  String toDbString() {
    switch (this) {
      case TypeCompte.detail:
        return 'detail';
      case TypeCompte.total:
        return 'total';
    }
  }

  String toLabel() {
    switch (this) {
      case TypeCompte.detail:
        return 'Détail';
      case TypeCompte.total:
        return 'Total';
    }
  }
}

/// Convertir string en enum
TypeCompte stringToTypeCompte(String value) {
  switch (value) {
    case 'detail':
      return TypeCompte.detail;
    case 'total':
      return TypeCompte.total;
    default:
      return TypeCompte.detail;
  }
}

/// Nature du compte basée sur le numéro du compte
enum NatureCompte {
  // Bilan (ressources durables)
  bilanRessourcesDurables,

  // Bilan (actif immobilisé)
  bilanActifImmobilise,

  // Bilan (stocks)
  bilanStocks,

  // Bilan (Fournisseurs)
  bilanFournisseurs,

  // Bilan (Adhérents - clients usagers)
  bilanAdherentsClientsUsagers,

  // Bilan (Personnel)
  bilanPersonnel,

  // Bilan (Organismes sociaux)
  bilanOrganismesSociaux,

  // Bilan (Etat et collectivités publiques)
  bilanEtatCollectivitesPubliques,

  // Bilan (Autres tiers)
  bilanAutresTiers,

  // Bilan (Banque)
  bilanBanque,

  // Bilan (Caisse)
  bilanCaisse,

  // Bilan (Autres trésoreries)
  bilanAutresTresoreries,

  // Engagements hors bilan
  engagementsHorsBilan,

  // Charges d'activités ordinaires
  chargesAO,

  // Charges hors activités ordinaires
  chargesHAO,

  // Produits d'activités ordinaires
  produitsAO,

  // Produits hors activités ordinaires
  produitsHAO,
}

/// Extension pour convertir enum en string
extension NatureCompteExtension on NatureCompte {
  String toDbString() {
    switch (this) {
      case NatureCompte.bilanRessourcesDurables:
        return 'bilan_ressources_durables';
      case NatureCompte.bilanActifImmobilise:
        return 'bilan_actif_immobilise';
      case NatureCompte.bilanStocks:
        return 'bilan_stocks';
      case NatureCompte.bilanFournisseurs:
        return 'bilan_fournisseurs';
      case NatureCompte.bilanAdherentsClientsUsagers:
        return 'bilan_adherents_clients_usagers';
      case NatureCompte.bilanPersonnel:
        return 'bilan_personnel';
      case NatureCompte.bilanOrganismesSociaux:
        return 'bilan_organismes_sociaux';
      case NatureCompte.bilanEtatCollectivitesPubliques:
        return 'bilan_etat_collectivites_publiques';
      case NatureCompte.bilanAutresTiers:
        return 'bilan_autres_tiers';
      case NatureCompte.bilanBanque:
        return 'bilan_banque';
      case NatureCompte.bilanCaisse:
        return 'bilan_caisse';
      case NatureCompte.bilanAutresTresoreries:
        return 'bilan_autres_tresoreries';
      case NatureCompte.engagementsHorsBilan:
        return 'engagements_hors_bilan';
      case NatureCompte.chargesAO:
        return 'charges_ao';
      case NatureCompte.chargesHAO:
        return 'charges_hao';
      case NatureCompte.produitsAO:
        return 'produits_ao';
      case NatureCompte.produitsHAO:
        return 'produits_hao';
    }
  }

  String toLabel() {
    switch (this) {
      case NatureCompte.bilanRessourcesDurables:
        return 'Bilan (ressources durables)';
      case NatureCompte.bilanActifImmobilise:
        return 'Bilan (Actif immobilisé)';
      case NatureCompte.bilanStocks:
        return 'Bilan (stocks)';
      case NatureCompte.bilanFournisseurs:
        return 'Bilan (Fournisseurs)';
      case NatureCompte.bilanAdherentsClientsUsagers:
        return 'Bilan (Adhérents - clients usagers)';
      case NatureCompte.bilanPersonnel:
        return 'Bilan (Personnel)';
      case NatureCompte.bilanOrganismesSociaux:
        return 'Bilan (Organismes sociaux)';
      case NatureCompte.bilanEtatCollectivitesPubliques:
        return 'Bilan (Etat et collectivités publiques)';
      case NatureCompte.bilanAutresTiers:
        return 'Bilan (Autres tiers)';
      case NatureCompte.bilanBanque:
        return 'Bilan (Banque)';
      case NatureCompte.bilanCaisse:
        return 'Bilan (Caisse)';
      case NatureCompte.bilanAutresTresoreries:
        return 'Bilan (Autres trésoreries)';
      case NatureCompte.engagementsHorsBilan:
        return 'Engagements hors bilan';
      case NatureCompte.chargesAO:
        return 'Charges A.O.';
      case NatureCompte.chargesHAO:
        return 'Charges H.A.O.';
      case NatureCompte.produitsAO:
        return 'Produits A.O.';
      case NatureCompte.produitsHAO:
        return 'Produits H.A.O.';
    }
  }
}

/// Convertir string en enum
NatureCompte stringToNatureCompte(String value) {
  switch (value) {
    case 'bilan_ressources_durables':
      return NatureCompte.bilanRessourcesDurables;
    case 'bilan_actif_immobilise':
      return NatureCompte.bilanActifImmobilise;
    case 'bilan_stocks':
      return NatureCompte.bilanStocks;
    case 'bilan_fournisseurs':
      return NatureCompte.bilanFournisseurs;
    case 'bilan_adherents_clients_usagers':
      return NatureCompte.bilanAdherentsClientsUsagers;
    case 'bilan_personnel':
      return NatureCompte.bilanPersonnel;
    case 'bilan_organismes_sociaux':
      return NatureCompte.bilanOrganismesSociaux;
    case 'bilan_etat_collectivites_publiques':
      return NatureCompte.bilanEtatCollectivitesPubliques;
    case 'bilan_autres_tiers':
      return NatureCompte.bilanAutresTiers;
    case 'bilan_banque':
      return NatureCompte.bilanBanque;
    case 'bilan_caisse':
      return NatureCompte.bilanCaisse;
    case 'bilan_autres_tresoreries':
      return NatureCompte.bilanAutresTresoreries;
    case 'engagements_hors_bilan':
      return NatureCompte.engagementsHorsBilan;
    case 'charges_ao':
      return NatureCompte.chargesAO;
    case 'charges_hao':
      return NatureCompte.chargesHAO;
    case 'produits_ao':
      return NatureCompte.produitsAO;
    case 'produits_hao':
      return NatureCompte.produitsHAO;
    default:
      return NatureCompte.bilanRessourcesDurables;
  }
}

/// Calculer la nature automatiquement basée sur le numéro de compte
/// Règles:
/// 1 -> Bilan (ressources durables)
/// 2 -> Bilan (Actif immobilisé)
/// 3 -> Bilan (stocks)
/// 40 -> Bilan (Fournisseurs)
/// 41 -> Bilan (Adhérents - clients usagers)
/// 42 -> Bilan (Personnel)
/// 43 -> Bilan (Organismes sociaux)
/// 44 -> Bilan (Etat et collectivités publiques)
/// (45, 46, 47, 48, 49) -> Bilan (Autres tiers)
/// 52 -> Bilan (Banque)
/// 57 -> Bilan (Caisse)
/// (50, 51, 53, 55, 56, 58, 59) -> Bilan (Autres trésoreries)
/// 6 -> Charges d'activités ordinaires
/// 7 -> Produits d'activités ordinaires
/// 8 impair (81, 83, 85, 87, 89) -> Charges hors activités ordinaires
/// 8 pair (80, 82, 84, 86, 88) -> Produits hors activités ordinaires
/// 9 -> Engagements hors bilan
NatureCompte? calculateNatureFromNumeroCompte(String numeroCompte) {
  if (numeroCompte.isEmpty ) return null;

  final firstDigit = int.tryParse(numeroCompte[0]);
  if (firstDigit == null) return null;

  // Cas des 2 premiers chiffres pour plus de précision
  if (numeroCompte.length >= 2) {
    final firstTwoDigits = numeroCompte.substring(0, 2);

    switch (firstTwoDigits) {
      case '40':
        return NatureCompte.bilanFournisseurs;
      case '41':
        return NatureCompte.bilanAdherentsClientsUsagers;
      case '42':
        return NatureCompte.bilanPersonnel;
      case '43':
        return NatureCompte.bilanOrganismesSociaux;
      case '44':
        return NatureCompte.bilanEtatCollectivitesPubliques;
      case '45':
      case '46':
      case '47':
      case '48':
      case '49':
        return NatureCompte.bilanAutresTiers;
      case '50':
      case '51':
      case '53':
      case '55':
      case '56':
      case '58':
      case '59':
        return NatureCompte.bilanAutresTresoreries;
      case '52':
        return NatureCompte.bilanBanque;
      case '57':
        return NatureCompte.bilanCaisse;
      // Cas pour 8X (charge ou produit hors activités ordinaires)
      case '80':
      case '82':
      case '84':
      case '86':
      case '88':
        return NatureCompte.produitsHAO;
      case '81':
      case '83':
      case '85':
      case '87':
      case '89':
        return NatureCompte.chargesHAO;
    }
  }

  // Cas du premier chiffre uniquement
  switch (firstDigit) {
    case 1:
      return NatureCompte.bilanRessourcesDurables;
    case 2:
      return NatureCompte.bilanActifImmobilise;
    case 3:
      return NatureCompte.bilanStocks;
    case 6:
      return NatureCompte.chargesAO;
    case 7:
      return NatureCompte.produitsAO;
    case 8:
      // Vérifier le 2e chiffre pour déterminer si c'est charge ou produit
      if (numeroCompte.length >= 2) {
        final secondDigit = int.tryParse(numeroCompte[1]);
        if (secondDigit != null) {
          return (secondDigit % 2 == 0)
              ? NatureCompte.produitsHAO
              : NatureCompte.chargesHAO;
        }
      }
      return null;
    case 9:
      return NatureCompte.engagementsHorsBilan;
    default:
      return null;
  }
}

/// Modèle pour un Compte comptable
class Compte {
  final String id;
  final String numeroCompte;
  final String intitule;
  final TypeCompte type;
  final NatureCompte nature;
  final bool liaisonTiers;
  final String? description;
  final bool isActive;

  // Métadonnées
  final DateTime createdAt;
  final DateTime updatedAt;

  Compte({
    required this.id,
    required this.numeroCompte,
    required this.intitule,
    required this.type,
    required this.nature,
    required this.liaisonTiers,
    this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Créer à partir d'une réponse Supabase
  factory Compte.fromJson(Map<String, dynamic> json) {
    return Compte(
      id: json['id'] as String,
      numeroCompte: json['numero_compte'] as String,
      intitule: json['intitule'] as String,
      type: stringToTypeCompte(json['type'] as String),
      nature: stringToNatureCompte(json['nature'] as String),
      liaisonTiers: json['liaison_tiers'] as bool? ?? false,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Créer à partir d'une Map SQLite
  factory Compte.fromMap(Map<String, dynamic> map) {
    return Compte(
      id: map['id'].toString(),
      numeroCompte: (map['numero_compte'] ?? '') as String,
      intitule: (map['intitule'] ?? '') as String,
      type: stringToTypeCompte((map['type'] ?? 'detail') as String),
      nature: stringToNatureCompte((map['nature'] ?? '') as String),
      liaisonTiers: ((map['liaison_tiers'] ?? 0) as int) == 1,
      description: map['description'] as String?,
      isActive: ((map['is_active'] ?? 1) as int) == 1,
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'] as String)
              : DateTime.now(),
      updatedAt:
          map['updated_at'] != null
              ? DateTime.parse(map['updated_at'] as String)
              : DateTime.now(),
    );
  }

  /// Convertir en JSON pour envoyer à Supabase
  Map<String, dynamic> toJson() {
    return {
      'numero_compte': numeroCompte,
      'intitule': intitule,
      'type': type.toDbString(),
      'nature': nature.toDbString(),
      'liaison_tiers': liaisonTiers,
      'description': description,
      'is_active': isActive,
    };
  }

  /// Copier avec modifications
  Compte copyWith({
    String? numeroCompte,
    String? intitule,
    TypeCompte? type,
    NatureCompte? nature,
    bool? liaisonTiers,
    String? description,
    bool? isActive,
  }) {
    return Compte(
      id: id,
      numeroCompte: numeroCompte ?? this.numeroCompte,
      intitule: intitule ?? this.intitule,
      type: type ?? this.type,
      nature: nature ?? this.nature,
      liaisonTiers: liaisonTiers ?? this.liaisonTiers,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Format la date de création
  String get formattedCreatedAt {
    return createdAt.toString().substring(0, 19);
  }

  /// Format la date de modification
  String get formattedUpdatedAt {
    return updatedAt.toString().substring(0, 19);
  }
}
