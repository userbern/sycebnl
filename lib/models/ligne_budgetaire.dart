class LigneBudgetaire {
  final int? id;
  final int posteBudgetaireId;
  final String code;
  final String intitule;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  LigneBudgetaire({
    this.id,
    required this.posteBudgetaireId,
    required this.code,
    required this.intitule,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory LigneBudgetaire.fromMap(Map<String, dynamic> map) {
    return LigneBudgetaire(
      id: map['id'] as int?,
      posteBudgetaireId: map['poste_budgetaire_id'] as int,
      code: map['code'] as String,
      intitule: map['intitule'] as String,
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
      'poste_budgetaire_id': posteBudgetaireId,
      'code': code,
      'intitule': intitule,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}
