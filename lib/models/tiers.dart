/// Types de tiers comptable
enum TypeTiers { client, fournisseur, employe, autre }

/// Extension pour convertir enum en string
extension TypeTiersExtension on TypeTiers {
  String toDbString() {
    switch (this) {
      case TypeTiers.client:
        return 'client';
      case TypeTiers.fournisseur:
        return 'fournisseur';
      case TypeTiers.employe:
        return 'employe';
      case TypeTiers.autre:
        return 'autre';
    }
  }

  String toLabel() {
    switch (this) {
      case TypeTiers.client:
        return 'Client';
      case TypeTiers.fournisseur:
        return 'Fournisseur';
      case TypeTiers.employe:
        return 'Employé';
      case TypeTiers.autre:
        return 'Autre';
    }
  }
}

/// Convertir string en enum
TypeTiers stringToTypeTiers(String value) {
  switch (value) {
    case 'client':
      return TypeTiers.client;
    case 'fournisseur':
      return TypeTiers.fournisseur;
    case 'employe':
      return TypeTiers.employe;
    case 'autre':
      return TypeTiers.autre;
    default:
      return TypeTiers.client;
  }
}

/// Modèle pour un Tiers comptable
class Tiers {
  final String id;
  final String numeroCompte;
  final String intitule;
  final TypeTiers type;
  final String compteCollectif; // Numéro du compte collectif
  final String? nif; // Numéro d'identification fiscale
  final String? adresse;
  final bool isActive;

  // Métadonnées
  final DateTime createdAt;
  final DateTime updatedAt;

  Tiers({
    required this.id,
    required this.numeroCompte,
    required this.intitule,
    required this.type,
    required this.compteCollectif,
    this.nif,
    this.adresse,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Créer à partir d'une réponse Supabase
  factory Tiers.fromJson(Map<String, dynamic> json) {
    return Tiers(
      id: json['id'] as String,
      numeroCompte: json['numero_compte'] as String,
      intitule: json['intitule'] as String,
      type: stringToTypeTiers(json['type'] as String),
      compteCollectif: json['compte_collectif'] as String,
      nif: json['nif'] as String?,
      adresse: json['adresse'] as String?,
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
      'compte_collectif': compteCollectif,
      'nif': nif,
      'adresse': adresse,
      'is_active': isActive,
    };
  }

  /// Copier avec modifications
  Tiers copyWith({
    String? numeroCompte,
    String? intitule,
    TypeTiers? type,
    String? compteCollectif,
    String? nif,
    String? adresse,
    bool? isActive,
  }) {
    return Tiers(
      id: id,
      numeroCompte: numeroCompte ?? this.numeroCompte,
      intitule: intitule ?? this.intitule,
      type: type ?? this.type,
      compteCollectif: compteCollectif ?? this.compteCollectif,
      nif: nif ?? this.nif,
      adresse: adresse ?? this.adresse,
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
