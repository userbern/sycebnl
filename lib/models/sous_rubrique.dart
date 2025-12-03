class SousRubrique {
  final int? id;
  final int ligneBudgetaireId;
  final String intitule;
  final double montant;
  final int? compteId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  SousRubrique({
    this.id,
    required this.ligneBudgetaireId,
    required this.intitule,
    required this.montant,
    this.compteId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory SousRubrique.fromMap(Map<String, dynamic> map) {
    return SousRubrique(
      id: map['id'] as int?,
      ligneBudgetaireId: map['ligne_budgetaire_id'] as int,
      intitule: map['intitule'] as String,
      montant: (map['montant'] as num?)?.toDouble() ?? 0.0,
      compteId: map['compte_id'] as int?,
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'] as String)
              : null,
      updatedAt:
          map['updated_at'] != null
              ? DateTime.parse(map['updated_at'] as String)
              : null,
      deletedAt:
          map['deleted_at'] != null
              ? DateTime.parse(map['deleted_at'] as String)
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ligne_budgetaire_id': ligneBudgetaireId,
      'intitule': intitule,
      'montant': montant,
      'compte_id': compteId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}
