class PosteBudgetaire {
  final int? id;
  final int budgetId;
  final String intitule;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  PosteBudgetaire({
    this.id,
    required this.budgetId,
    required this.intitule,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory PosteBudgetaire.fromMap(Map<String, dynamic> map) {
    return PosteBudgetaire(
      id: map['id'] as int?,
      budgetId: map['budget_id'] as int,
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
      'budget_id': budgetId,
      'intitule': intitule,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}
