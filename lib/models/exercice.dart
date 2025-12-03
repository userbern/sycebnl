/// Modèle pour un exercice comptable
class Exercice {
  final int? id;
  final String code;
  final DateTime dateDebut;
  final DateTime dateFin;
  final int dureeMois;
  final String statut; // 'OUVERT' ou 'CLOTURE'
  final bool isCurrent;
  final DateTime? createdAt;

  Exercice({
    this.id,
    required this.code,
    required this.dateDebut,
    required this.dateFin,
    required this.dureeMois,
    this.statut = 'OUVERT',
    this.isCurrent = false,
    this.createdAt,
  });

  /// Créer un exercice depuis la base de données
  factory Exercice.fromMap(Map<String, dynamic> map) {
    return Exercice(
      id: map['id'] as int?,
      code: map['code'] as String,
      dateDebut: DateTime.parse(map['date_debut'] as String),
      dateFin: DateTime.parse(map['date_fin'] as String),
      dureeMois: map['duree_mois'] as int,
      statut: map['statut'] as String? ?? 'OUVERT',
      isCurrent: (map['is_current'] as int? ?? 0) == 1,
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'] as String)
              : null,
    );
  }

  /// Convertir en Map pour la base de données
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'code': code,
      'date_debut': dateDebut.toIso8601String(),
      'date_fin': dateFin.toIso8601String(),
      'duree_mois': dureeMois,
      'statut': statut,
      'is_current': isCurrent ? 1 : 0,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  /// Copier avec modifications
  Exercice copyWith({
    int? id,
    String? code,
    DateTime? dateDebut,
    DateTime? dateFin,
    int? dureeMois,
    String? statut,
    bool? isCurrent,
    DateTime? createdAt,
  }) {
    return Exercice(
      id: id ?? this.id,
      code: code ?? this.code,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFin: dateFin ?? this.dateFin,
      dureeMois: dureeMois ?? this.dureeMois,
      statut: statut ?? this.statut,
      isCurrent: isCurrent ?? this.isCurrent,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Vérifier si l'exercice est ouvert
  bool get isOuvert => statut == 'OUVERT';

  /// Vérifier si l'exercice est clôturé
  bool get isCloture => statut == 'CLOTURE';

  @override
  String toString() {
    return 'Exercice(id: $id, code: $code, dateDebut: $dateDebut, dateFin: $dateFin, statut: $statut, isCurrent: $isCurrent)';
  }
}
