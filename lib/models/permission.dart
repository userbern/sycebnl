class Permission {
  final int? id;
  final int utilisateurId;
  final int moduleId;
  final bool lecture;
  final bool ajout;
  final bool modification;
  final bool suppression;
  final String? moduleNom;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  Permission({
    this.id,
    required this.utilisateurId,
    required this.moduleId,
    this.lecture = false,
    this.ajout = false,
    this.modification = false,
    this.suppression = false,
    this.moduleNom,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory Permission.fromMap(Map<String, dynamic> map) {
    return Permission(
      id: map['id'] as int?,
      utilisateurId: map['utilisateur_id'] as int? ?? 0,
      moduleId: map['module_id'] as int? ?? 0,
      lecture: _toBool(map['lecture']),
      ajout: _toBool(map['ajout']),
      modification: _toBool(map['modification']),
      suppression: _toBool(map['suppression']),
      moduleNom: map['module_nom'] as String?,
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
      if (id != null) 'id': id,
      'utilisateur_id': utilisateurId,
      'module_id': moduleId,
      'lecture': lecture ? 1 : 0,
      'ajout': ajout ? 1 : 0,
      'modification': modification ? 1 : 0,
      'suppression': suppression ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  Permission copyWith({
    int? id,
    int? utilisateurId,
    int? moduleId,
    bool? lecture,
    bool? ajout,
    bool? modification,
    bool? suppression,
    String? moduleNom,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Permission(
      id: id ?? this.id,
      utilisateurId: utilisateurId ?? this.utilisateurId,
      moduleId: moduleId ?? this.moduleId,
      lecture: lecture ?? this.lecture,
      ajout: ajout ?? this.ajout,
      modification: modification ?? this.modification,
      suppression: suppression ?? this.suppression,
      moduleNom: moduleNom ?? this.moduleNom,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  bool get hasAnyPermission => lecture || ajout || modification || suppression;

  static bool _toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == '1' || normalized == 'true' || normalized == 'yes';
    }
    return false;
  }
}
