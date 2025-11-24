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

/// Nature du compte basée sur le premier chiffre du numéro
enum NatureCompte {
  bilan1_5, // 1 à 5: Bilan
  charge_6_impaire, // 6 impaire: Charge
  produit_7_paire, // 7 paire: Produit
  charge_8_impaire, // 8 impaire: Charge
  produit_8_paire, // 8 paire: Produit
  horsBilan_9, // 9: Hors bilan
}

/// Extension pour convertir enum en string
extension NatureCompteExtension on NatureCompte {
  String toDbString() {
    switch (this) {
      case NatureCompte.bilan1_5:
        return 'bilan_1_5';
      case NatureCompte.charge_6_impaire:
        return 'charge_6_impaire';
      case NatureCompte.produit_7_paire:
        return 'produit_7_paire';
      case NatureCompte.charge_8_impaire:
        return 'charge_8_impaire';
      case NatureCompte.produit_8_paire:
        return 'produit_8_paire';
      case NatureCompte.horsBilan_9:
        return 'hors_bilan_9';
    }
  }

  String toLabel() {
    switch (this) {
      case NatureCompte.bilan1_5:
        return 'Bilan (1-5)';
      case NatureCompte.charge_6_impaire:
        return 'Charge (6 impaire)';
      case NatureCompte.produit_7_paire:
        return 'Produit (7 paire)';
      case NatureCompte.charge_8_impaire:
        return 'Charge (8 impaire)';
      case NatureCompte.produit_8_paire:
        return 'Produit (8 paire)';
      case NatureCompte.horsBilan_9:
        return 'Hors bilan (9)';
    }
  }
}

/// Convertir string en enum
NatureCompte stringToNatureCompte(String value) {
  switch (value) {
    case 'bilan_1_5':
      return NatureCompte.bilan1_5;
    case 'charge_6_impaire':
      return NatureCompte.charge_6_impaire;
    case 'produit_7_paire':
      return NatureCompte.produit_7_paire;
    case 'charge_8_impaire':
      return NatureCompte.charge_8_impaire;
    case 'produit_8_paire':
      return NatureCompte.produit_8_paire;
    case 'hors_bilan_9':
      return NatureCompte.horsBilan_9;
    default:
      return NatureCompte.bilan1_5;
  }
}

/// Calculer la nature automatiquement basée sur le premier chiffre du numéro de compte
/// Règles:
/// - 1 à 5: Bilan
/// - 6 impaire: Charge
/// - 7 paire: Produit
/// - 8 impaire: Charge
/// - 8 paire: Produit
/// - 9: Hors bilan
NatureCompte? calculateNatureFromNumeroCompte(String numeroCompte) {
  if (numeroCompte.isEmpty) return null;

  final firstChar = numeroCompte[0];
  if (!RegExp(r'^[0-9]$').hasMatch(firstChar)) return null;

  final firstDigit = int.parse(firstChar);

  switch (firstDigit) {
    case 1:
    case 2:
    case 3:
    case 4:
    case 5:
      return NatureCompte.bilan1_5;
    case 6:
      // 6 impaire (chaîne de caractères, donc on regarde si c'est impair en valeur numérique)
      if (numeroCompte.length > 1) {
        try {
          final secondDigit = int.parse(numeroCompte[1]);
          return secondDigit % 2 != 0
              ? NatureCompte.charge_6_impaire
              : NatureCompte.charge_6_impaire; // Par défaut charge pour 6
        } catch (e) {
          return NatureCompte.charge_6_impaire;
        }
      }
      return NatureCompte.charge_6_impaire;
    case 7:
      // 7 paire
      if (numeroCompte.length > 1) {
        try {
          final secondDigit = int.parse(numeroCompte[1]);
          return secondDigit % 2 == 0
              ? NatureCompte.produit_7_paire
              : NatureCompte.produit_7_paire; // Par défaut produit pour 7
        } catch (e) {
          return NatureCompte.produit_7_paire;
        }
      }
      return NatureCompte.produit_7_paire;
    case 8:
      if (numeroCompte.length > 1) {
        try {
          final secondDigit = int.parse(numeroCompte[1]);
          return secondDigit % 2 != 0
              ? NatureCompte.charge_8_impaire
              : NatureCompte.produit_8_paire;
        } catch (e) {
          return NatureCompte.charge_8_impaire;
        }
      }
      return NatureCompte.charge_8_impaire;
    case 9:
      return NatureCompte.horsBilan_9;
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
