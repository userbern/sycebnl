/// Métadonnées de sécurité d'un dossier comptable, stockées dans la table
/// `dossier_security` (une seule ligne par dossier). Distinct de
/// [FileConfig] : ce modèle concerne le chiffrement du fichier et la
/// récupération, pas la configuration comptable.
class DossierSecurity {
  final int? id;
  final String dossierUuid;
  final bool isEncrypted;
  final String authAlgo;
  final String? authSalt;
  final String? authHash;
  final String? argon2Params;
  final String? recoveryKeyHash;
  final String? recoveryKeySalt;
  final String? editorUnlockPubkeyWrapped;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DossierSecurity({
    this.id,
    required this.dossierUuid,
    this.isEncrypted = false,
    this.authAlgo = 'argon2id',
    this.authSalt,
    this.authHash,
    this.argon2Params,
    this.recoveryKeyHash,
    this.recoveryKeySalt,
    this.editorUnlockPubkeyWrapped,
    this.createdAt,
    this.updatedAt,
  });

  factory DossierSecurity.fromMap(Map<String, dynamic> map) {
    return DossierSecurity(
      id: map['id'] as int?,
      dossierUuid: map['dossier_uuid'] as String,
      isEncrypted: _toBool(map['is_encrypted']),
      authAlgo: map['auth_algo'] as String? ?? 'argon2id',
      authSalt: map['auth_salt'] as String?,
      authHash: map['auth_hash'] as String?,
      argon2Params: map['argon2_params'] as String?,
      recoveryKeyHash: map['recovery_key_hash'] as String?,
      recoveryKeySalt: map['recovery_key_salt'] as String?,
      editorUnlockPubkeyWrapped: map['editor_unlock_pubkey_wrapped'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'dossier_uuid': dossierUuid,
      'is_encrypted': isEncrypted ? 1 : 0,
      'auth_algo': authAlgo,
      'auth_salt': authSalt,
      'auth_hash': authHash,
      'argon2_params': argon2Params,
      'recovery_key_hash': recoveryKeyHash,
      'recovery_key_salt': recoveryKeySalt,
      'editor_unlock_pubkey_wrapped': editorUnlockPubkeyWrapped,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  DossierSecurity copyWith({
    bool? isEncrypted,
    String? authAlgo,
    String? authSalt,
    String? authHash,
    String? argon2Params,
    String? recoveryKeyHash,
    String? recoveryKeySalt,
    String? editorUnlockPubkeyWrapped,
    DateTime? updatedAt,
  }) {
    return DossierSecurity(
      id: id,
      dossierUuid: dossierUuid,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      authAlgo: authAlgo ?? this.authAlgo,
      authSalt: authSalt ?? this.authSalt,
      authHash: authHash ?? this.authHash,
      argon2Params: argon2Params ?? this.argon2Params,
      recoveryKeyHash: recoveryKeyHash ?? this.recoveryKeyHash,
      recoveryKeySalt: recoveryKeySalt ?? this.recoveryKeySalt,
      editorUnlockPubkeyWrapped:
          editorUnlockPubkeyWrapped ?? this.editorUnlockPubkeyWrapped,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
