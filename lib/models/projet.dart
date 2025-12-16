class Projet {
  final int id;
  final String code;
  final String nom;
  final int bailleurId;
  final String? description;
  final String? dateDebut;
  final String? dateFin;
  final double? budget;
  final String? devise;
  final String statut;
  final bool actif;
  final String? createdAt;
  final String? updatedAt;

  Projet({
    required this.id,
    required this.code,
    required this.nom,
    required this.bailleurId,
    this.description,
    this.dateDebut,
    this.dateFin,
    this.budget,
    this.devise,
    this.statut = 'EN_COURS',
    this.actif = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Projet.fromMap(Map<String, dynamic> map) {
    return Projet(
      id: map['id'] as int,
      code: map['code'] as String,
      nom: map['nom'] as String? ?? map['designation'] as String? ?? 'Sans nom',
      bailleurId: map['bailleur_id'] as int? ?? 0,
      description: map['description'] as String?,
      dateDebut: map['date_debut'] as String?,
      dateFin: map['date_fin'] as String?,
      budget: map['budget'] != null ? (map['budget'] as num).toDouble() : null,
      devise: map['devise'] as String?,
      statut: map['statut'] as String? ?? 'EN_COURS',
      actif: (map['actif'] ?? map['is_active'] ?? 1) as int == 1,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'nom': nom,
      'bailleur_id': bailleurId,
      'description': description,
      'date_debut': dateDebut,
      'date_fin': dateFin,
      'budget': budget,
      'devise': devise,
      'statut': statut,
      'actif': actif ? 1 : 0,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  Projet copyWith({
    int? id,
    String? code,
    String? nom,
    int? bailleurId,
    String? description,
    String? dateDebut,
    String? dateFin,
    double? budget,
    String? devise,
    String? statut,
    bool? actif,
    String? createdAt,
    String? updatedAt,
  }) {
    return Projet(
      id: id ?? this.id,
      code: code ?? this.code,
      nom: nom ?? this.nom,
      bailleurId: bailleurId ?? this.bailleurId,
      description: description ?? this.description,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFin: dateFin ?? this.dateFin,
      budget: budget ?? this.budget,
      devise: devise ?? this.devise,
      statut: statut ?? this.statut,
      actif: actif ?? this.actif,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
