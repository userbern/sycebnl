/// Types d'organisations possibles
enum OngType {
  association,
  ongLocale,
  ongInternationale,
  ordreProfessionnel,
  fondation,
  congregationReligieuse,
  clubSportif,
  clubServices,
  partiPolitique,
}

/// Extension pour convertir enum en string Supabase
extension OngTypeExtension on OngType {
  String toDbString() {
    switch (this) {
      case OngType.association:
        return 'association';
      case OngType.ongLocale:
        return 'ong_locale';
      case OngType.ongInternationale:
        return 'ong_internationale';
      case OngType.ordreProfessionnel:
        return 'ordre_professionnel';
      case OngType.fondation:
        return 'fondation';
      case OngType.congregationReligieuse:
        return 'congregation_religieuse';
      case OngType.clubSportif:
        return 'club_sportif';
      case OngType.clubServices:
        return 'club_services';
      case OngType.partiPolitique:
        return 'parti_politique';
    }
  }

  /// Label français pour l'affichage
  String toLabel() {
    switch (this) {
      case OngType.association:
        return 'Association';
      case OngType.ongLocale:
        return 'ONG locale';
      case OngType.ongInternationale:
        return 'ONG internationale';
      case OngType.ordreProfessionnel:
        return 'Ordre professionnel';
      case OngType.fondation:
        return 'Fondation';
      case OngType.congregationReligieuse:
        return 'Congrégation religieuse';
      case OngType.clubSportif:
        return 'Club sportif';
      case OngType.clubServices:
        return 'Club services';
      case OngType.partiPolitique:
        return 'Parti politique';
    }
  }
}

/// Convertir string Supabase en enum
OngType stringToOngType(String value) {
  switch (value) {
    case 'association':
      return OngType.association;
    case 'ong_locale':
      return OngType.ongLocale;
    case 'ong_internationale':
      return OngType.ongInternationale;
    case 'ordre_professionnel':
      return OngType.ordreProfessionnel;
    case 'fondation':
      return OngType.fondation;
    case 'congregation_religieuse':
      return OngType.congregationReligieuse;
    case 'club_sportif':
      return OngType.clubSportif;
    case 'club_services':
      return OngType.clubServices;
    case 'parti_politique':
      return OngType.partiPolitique;
    default:
      return OngType.association;
  }
}

/// Modèle pour une Entité (identification)
class Entite {
  final String id;
  final String denominationSociale;
  final String? sigleUsuel;
  final String? domaineIntervention;
  final String? formeJuridique;
  final OngType? ongType;

  // Localisation
  final String? pays;
  final String? region;
  final String? ville;
  final String? quartier;

  // Contact
  final String? email;
  final String? telephone;
  final String? fixeFax;

  // Administration
  final String? numeroFiscal;
  final String? numeroCnss;
  final String? numeroRecepisse;

  // Complément
  final String? informationsComplementaires;

  // Monnaie
  final String? currency;

  // Métadonnées
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final bool isActive;

  Entite({
    required this.id,
    required this.denominationSociale,
    this.sigleUsuel,
    this.domaineIntervention,
    this.formeJuridique,
    this.ongType,
    this.pays,
    this.region,
    this.ville,
    this.quartier,
    this.email,
    this.telephone,
    this.fixeFax,
    this.numeroFiscal,
    this.numeroCnss,
    this.numeroRecepisse,
    this.informationsComplementaires,
    this.currency,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    required this.isActive,
  });

  /// Créer à partir d'une réponse Supabase
  factory Entite.fromJson(Map<String, dynamic> json) {
    return Entite(
      id: json['id'] as String,
      denominationSociale: json['denomination_sociale'] as String,
      sigleUsuel: json['sigle_usuel'] as String?,
      domaineIntervention: json['domaine_intervention'] as String?,
      formeJuridique: json['forme_juridique'] as String?,
      ongType:
          json['ong_type'] != null ? stringToOngType(json['ong_type']) : null,
      pays: json['pays'] as String?,
      region: json['region'] as String?,
      ville: json['ville'] as String?,
      quartier: json['quartier'] as String?,
      email: json['email'] as String?,
      telephone: json['telephone'] as String?,
      fixeFax: json['fixe_fax'] as String?,
      numeroFiscal: json['numero_fiscal'] as String?,
      numeroCnss: json['numero_cnss'] as String?,
      numeroRecepisse: json['numero_recepisse'] as String?,
      informationsComplementaires:
          json['informations_complementaires'] as String?,
      currency: json['currency'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// Créer à partir d'une Map SQLite
  factory Entite.fromMap(Map<String, dynamic> map) {
    return Entite(
      id: map['id'].toString(),
      denominationSociale: map['denomination_sociale'] as String,
      sigleUsuel: map['sigle_usuel'] as String?,
      domaineIntervention: map['domaine_intervention'] as String?,
      formeJuridique: map['forme_juridique'] as String?,
      ongType:
          map['ong_type'] != null ? stringToOngType(map['ong_type']) : null,
      pays: map['pays'] as String?,
      region: map['region'] as String?,
      ville: map['ville'] as String?,
      quartier: map['quartier'] as String?,
      email: map['email'] as String?,
      telephone: map['telephone'] as String?,
      fixeFax: map['fixe_fax'] as String?,
      numeroFiscal: map['numero_fiscal'] as String?,
      numeroCnss: map['numero_cnss'] as String?,
      numeroRecepisse: map['numero_recepisse'] as String?,
      informationsComplementaires:
          map['informations_complementaires'] as String?,
      currency: map['currency'] as String?,
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'] as String)
              : DateTime.now(),
      updatedAt:
          map['updated_at'] != null
              ? DateTime.parse(map['updated_at'] as String)
              : DateTime.now(),
      createdBy: map['created_by'] as String?,
      isActive: (map['actif'] as int?) == 1,
    );
  }

  /// Convertir en JSON pour envoyer à Supabase
  Map<String, dynamic> toJson() {
    return {
      'denomination_sociale': denominationSociale,
      'sigle_usuel': sigleUsuel,
      'domaine_intervention': domaineIntervention,
      'forme_juridique': formeJuridique,
      'ong_type': ongType?.toDbString(),
      'pays': pays,
      'region': region,
      'ville': ville,
      'quartier': quartier,
      'email': email,
      'telephone': telephone,
      'fixe_fax': fixeFax,
      'numero_fiscal': numeroFiscal,
      'numero_cnss': numeroCnss,
      'numero_recepisse': numeroRecepisse,
      'informations_complementaires': informationsComplementaires,
      'currency': currency,
      'is_active': isActive,
    };
  }

  /// Copier avec modifications
  Entite copyWith({
    String? denominationSociale,
    String? sigleUsuel,
    String? domaineIntervention,
    String? formeJuridique,
    OngType? ongType,
    String? pays,
    String? region,
    String? ville,
    String? quartier,
    String? email,
    String? telephone,
    String? fixeFax,
    String? numeroFiscal,
    String? numeroCnss,
    String? numeroRecepisse,
    String? informationsComplementaires,
    String? currency,
    bool? isActive,
  }) {
    return Entite(
      id: id,
      denominationSociale: denominationSociale ?? this.denominationSociale,
      sigleUsuel: sigleUsuel ?? this.sigleUsuel,
      domaineIntervention: domaineIntervention ?? this.domaineIntervention,
      formeJuridique: formeJuridique ?? this.formeJuridique,
      ongType: ongType ?? this.ongType,
      pays: pays ?? this.pays,
      region: region ?? this.region,
      ville: ville ?? this.ville,
      quartier: quartier ?? this.quartier,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      fixeFax: fixeFax ?? this.fixeFax,
      numeroFiscal: numeroFiscal ?? this.numeroFiscal,
      numeroCnss: numeroCnss ?? this.numeroCnss,
      numeroRecepisse: numeroRecepisse ?? this.numeroRecepisse,
      informationsComplementaires:
          informationsComplementaires ?? this.informationsComplementaires,
      currency: currency ?? this.currency,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      createdBy: createdBy,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Format la date de création (format: 2025-11-20 15:30)
  String get formattedCreatedAt {
    return createdAt.toString().substring(0, 19);
  }

  /// Format la date de modification
  String get formattedUpdatedAt {
    return updatedAt.toString().substring(0, 19);
  }
}
