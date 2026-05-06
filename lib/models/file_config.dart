class FileConfig {
  final int? id;
  final int longueurCompteGeneral;
  final int longueurCompteTiers;
  final bool hasPassword;
  final String? passwordHash;
  final String? login;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  FileConfig({
    this.id,
    required this.longueurCompteGeneral,
    required this.longueurCompteTiers,
    this.hasPassword = false,
    this.passwordHash,
    this.login,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory FileConfig.fromMap(Map<String, dynamic> map) {
    return FileConfig(
      id: map['id'] as int?,
      longueurCompteGeneral:
          map['longueur_compte_general'] as int? ??
          map['longueurCompteGeneral'] as int? ??
          6,
      longueurCompteTiers:
          map['longueur_compte_tiers'] as int? ??
          map['longueurCompteTiers'] as int? ??
          8,
      hasPassword: _toBool(map['has_password'] ?? map['hasPassword']),
      passwordHash:
          map['password_hash'] as String? ?? map['passwordHash'] as String?,
      login: map['login'] as String?,
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
      'longueur_compte_general': longueurCompteGeneral,
      'longueur_compte_tiers': longueurCompteTiers,
      'has_password': hasPassword ? 1 : 0,
      'password_hash': passwordHash,
      'login': login,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  FileConfig copyWith({
    int? id,
    int? longueurCompteGeneral,
    int? longueurCompteTiers,
    bool? hasPassword,
    String? passwordHash,
    String? login,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return FileConfig(
      id: id ?? this.id,
      longueurCompteGeneral:
          longueurCompteGeneral ?? this.longueurCompteGeneral,
      longueurCompteTiers: longueurCompteTiers ?? this.longueurCompteTiers,
      hasPassword: hasPassword ?? this.hasPassword,
      passwordHash: passwordHash ?? this.passwordHash,
      login: login ?? this.login,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  bool get isPasswordProtected =>
      hasPassword && (passwordHash?.isNotEmpty ?? false);

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
