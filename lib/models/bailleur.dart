class Bailleur {
  final int? id;
  final String sigle;
  final String designation;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  Bailleur({
    this.id,
    required this.sigle,
    required this.designation,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  /// Vérifier si le bailleur est actif (soft delete)
  bool get isActive => deletedAt == null;

  factory Bailleur.fromMap(Map<String, dynamic> map) {
    return Bailleur(
      id: map['id'] as int?,
      sigle: map['sigle'] as String,
      designation: map['designation'] as String,
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'] as String)
              : DateTime.now(),
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
      'sigle': sigle,
      'designation': designation,
      'created_at': createdAt.toIso8601String(),
      'updated_at':
          updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  Bailleur copyWith({
    int? id,
    String? sigle,
    String? designation,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Bailleur(
      id: id ?? this.id,
      sigle: sigle ?? this.sigle,
      designation: designation ?? this.designation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
