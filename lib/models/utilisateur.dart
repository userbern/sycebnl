class Utilisateur {
  final int? id;
  final String login;
  final String passwordHash;
  final String? nom;
  final String? prenom;
  final String? email;
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  Utilisateur({
    this.id,
    required this.login,
    required this.passwordHash,
    this.nom,
    this.prenom,
    this.email,
    this.role = 'utilisateur',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory Utilisateur.fromMap(Map<String, dynamic> map) {
    return Utilisateur(
      id: map['id'] as int?,
      login: map['login'] as String? ?? '',
      passwordHash:
          map['password_hash'] as String? ?? map['password'] as String? ?? '',
      nom: map['nom'] as String?,
      prenom: map['prenom'] as String?,
      email: map['email'] as String?,
      role: map['role'] as String? ?? 'utilisateur',
      isActive: _toBool(map['is_active']) || (map['deleted_at'] == null),
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
      'login': login,
      'password': passwordHash,
      'role': role,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at':
          updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toUsersMap() {
    return {
      if (id != null) 'id': id,
      'nom': nom ?? '',
      'prenom': prenom,
      'login': login,
      'password_hash': passwordHash,
      'email': email,
      'role': role,
      'is_active': isActive ? 1 : 0,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Utilisateur copyWith({
    int? id,
    String? login,
    String? passwordHash,
    String? nom,
    String? prenom,
    String? email,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Utilisateur(
      id: id ?? this.id,
      login: login ?? this.login,
      passwordHash: passwordHash ?? this.passwordHash,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  String get fullName {
    final parts = <String>[];
    if ((prenom ?? '').trim().isNotEmpty) parts.add(prenom!.trim());
    if ((nom ?? '').trim().isNotEmpty) parts.add(nom!.trim());
    return parts.isEmpty ? login : parts.join(' ');
  }

  bool get isAdmin => role.toLowerCase() == 'admin';

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
