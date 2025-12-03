/// Types de journal comptable
enum TypeJournal { financier, nonFinancier }

/// Extension pour convertir enum en string
extension TypeJournalExtension on TypeJournal {
  String toDbString() {
    switch (this) {
      case TypeJournal.financier:
        return 'financier';
      case TypeJournal.nonFinancier:
        return 'non_financier';
    }
  }

  String toLabel() {
    switch (this) {
      case TypeJournal.financier:
        return 'Financier';
      case TypeJournal.nonFinancier:
        return 'Non Financier';
    }
  }
}

/// Convertir string en enum
TypeJournal stringToTypeJournal(String value) {
  switch (value) {
    case 'financier':
      return TypeJournal.financier;
    case 'non_financier':
      return TypeJournal.nonFinancier;
    default:
      return TypeJournal.financier;
  }
}

/// Modèle pour un Journal comptable
class Journal {
  final String id;
  final String code;
  final String intitule;
  final TypeJournal type;
  final String? compteFresorerie; // Compte de trésorerie (si type financier)
  final bool saisieAnalytique;
  final bool isActive;

  // Métadonnées
  final DateTime createdAt;
  final DateTime updatedAt;

  Journal({
    required this.id,
    required this.code,
    required this.intitule,
    required this.type,
    this.compteFresorerie,
    required this.saisieAnalytique,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Créer à partir d'une réponse Supabase
  factory Journal.fromJson(Map<String, dynamic> json) {
    return Journal(
      id: json['id'] as String,
      code: json['code'] as String,
      intitule: json['intitule'] as String,
      type: stringToTypeJournal(json['type'] as String),
      compteFresorerie: json['compte_fresorerie'] as String?,
      saisieAnalytique: json['saisie_analytique'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Créer à partir d'une Map SQLite
  factory Journal.fromMap(Map<String, dynamic> map) {
    return Journal(
      id: map['id'].toString(),
      code: (map['code'] ?? '') as String,
      intitule: (map['libelle'] ?? map['intitule'] ?? '') as String,
      type: stringToTypeJournal((map['type'] ?? 'financier') as String),
      compteFresorerie: map['numero_compte_tresorerie'] as String?,
      saisieAnalytique: (map['saisie_analytique'] as int?) == 1,
      isActive: (map['is_active'] ?? 1 as int?) == 1,
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'] as String)
              : DateTime.now(),
      updatedAt:
          map['updated_at'] != null
              ? DateTime.parse(map['updated_at'] as String)
              : DateTime.now(),
    );
  }

  /// Convertir en JSON pour envoyer à Supabase
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'intitule': intitule,
      'type': type.toDbString(),
      'compte_fresorerie': compteFresorerie,
      'saisie_analytique': saisieAnalytique,
      'is_active': isActive,
    };
  }

  /// Copier avec modifications
  Journal copyWith({
    String? code,
    String? intitule,
    TypeJournal? type,
    String? compteFresorerie,
    bool? saisieAnalytique,
    bool? isActive,
  }) {
    return Journal(
      id: id,
      code: code ?? this.code,
      intitule: intitule ?? this.intitule,
      type: type ?? this.type,
      compteFresorerie: compteFresorerie ?? this.compteFresorerie,
      saisieAnalytique: saisieAnalytique ?? this.saisieAnalytique,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Format la date de création
  String get formattedCreatedAt {
    return createdAt.toString().substring(0, 19);
  }

  /// Format la date de modification
  String get formattedUpdatedAt {
    return updatedAt.toString().substring(0, 19);
  }
}
