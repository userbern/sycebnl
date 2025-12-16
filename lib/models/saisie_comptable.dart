// Modèles pour la saisie comptable

/// Représente une période de saisie pour un journal
class JournalPeriode {
  final int id;
  final String codeJournal;
  final int annee;
  final int mois;
  final int? exerciceId;
  final DateTime dateCreation;
  final DateTime? dateModification;
  int nombreEcritures;
  final int closureStatus;
  final bool isEquilibre;

  JournalPeriode({
    required this.id,
    required this.codeJournal,
    required this.annee,
    required this.mois,
    this.exerciceId,
    required this.dateCreation,
    this.dateModification,
    this.nombreEcritures = 0,
    this.closureStatus = 0,
    this.isEquilibre = false,
  });

  String get periodeLabel {
    final months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return '${months[mois - 1]} $annee';
  }

  String get codeJournalMois =>
      '$codeJournal-${annee.toString().substring(2)}-${mois.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'codeJournal': codeJournal,
    'annee': annee,
    'mois': mois,
    'exerciceId': exerciceId,
    'dateCreation': dateCreation.toIso8601String(),
    'dateModification': dateModification?.toIso8601String(),
    'nombreEcritures': nombreEcritures,
    'closureStatus': closureStatus,
    'isEquilibre': isEquilibre,
  };

  factory JournalPeriode.fromJson(Map<String, dynamic> json) => JournalPeriode(
    id: json['id'],
    codeJournal: json['codeJournal'],
    annee: json['annee'],
    mois: json['mois'],
    exerciceId: json['exerciceId'],
    dateCreation: DateTime.parse(json['dateCreation']),
    dateModification:
        json['dateModification'] != null
            ? DateTime.parse(json['dateModification'])
            : null,
    nombreEcritures: json['nombreEcritures'] ?? 0,
    closureStatus: _normalizeClosureStatus(
      json.containsKey('closureStatus') && json['closureStatus'] != null
          ? json['closureStatus']
          : json['isClosed'],
    ),
    isEquilibre: json['isEquilibre'] ?? false,
  );

  factory JournalPeriode.fromMap(Map<String, dynamic> map) => JournalPeriode(
    id: map['id'] ?? 0,
    codeJournal: map['code_journal'] ?? '',
    annee: map['annee'] ?? 0,
    mois: map['mois'] ?? 0,
    exerciceId: map['exercice_id'] as int?,
    dateCreation:
        map['created_at'] != null
            ? DateTime.parse(map['created_at'])
            : DateTime.now(),
    dateModification:
        map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    nombreEcritures: map['nombre_ecritures'] ?? 0,
    closureStatus: _normalizeClosureStatus(map['is_closed']),
    isEquilibre: (map['is_equilibre'] ?? 0) == 1,
  );

  bool get isClosed => closureStatus == 2;
  bool get isPartiallyClosed => closureStatus == 1;

  static int _normalizeClosureStatus(dynamic rawValue) {
    if (rawValue == null) {
      return 0;
    }

    if (rawValue is int) {
      return rawValue;
    }

    if (rawValue is num) {
      return rawValue.toInt();
    }

    if (rawValue is bool) {
      return rawValue ? 2 : 0;
    }

    if (rawValue is String) {
      final trimmed = rawValue.trim();
      if (trimmed.isEmpty) {
        return 0;
      }

      final parsed = int.tryParse(trimmed);
      if (parsed != null) {
        return parsed;
      }

      final lowered = trimmed.toLowerCase();
      if (lowered == 'true') {
        return 2;
      }
      if (lowered == 'false') {
        return 0;
      }
    }

    return 0;
  }
}

/// Représente une ligne d'écriture comptable
class LigneEcriture {
  final int? id;
  final int journalPeriodeId;
  final int numeroEnregistrement;
  final int jour;
  final String numeroDocument;
  final String? reference;
  final String numeroCompte;
  final String? numeroTiers;
  final String libelle;
  final double montantDebit;
  final double montantCredit;
  final VentilationAnalytique? ventilation;
  final DateTime dateCreation;
  final bool hasVentilation;

  LigneEcriture({
    this.id,
    required this.journalPeriodeId,
    required this.numeroEnregistrement,
    required this.jour,
    required this.numeroDocument,
    this.reference,
    required this.numeroCompte,
    this.numeroTiers,
    required this.libelle,
    required this.montantDebit,
    required this.montantCredit,
    this.ventilation,
    DateTime? dateCreation,
    bool? hasVentilation,
  }) : dateCreation = dateCreation ?? DateTime.now(),
       hasVentilation = hasVentilation ?? false;

  bool get isEquilibree => ventilation?.isComplete ?? false;
  bool get isValid =>
      (montantDebit > 0 || montantCredit > 0) &&
      !(montantDebit > 0 && montantCredit > 0) &&
      jour >= 1 &&
      jour <= 31;

  Map<String, dynamic> toJson() => {
    'id': id,
    'journalPeriodeId': journalPeriodeId,
    'numeroEnregistrement': numeroEnregistrement,
    'jour': jour,
    'numeroDocument': numeroDocument,
    'reference': reference ?? numeroDocument,
    'numeroCompte': numeroCompte,
    'numeroTiers': numeroTiers,
    'libelle': libelle,
    'montantDebit': montantDebit,
    'montantCredit': montantCredit,
    'ventilation': ventilation?.toJson(),
    'dateCreation': dateCreation.toIso8601String(),
    'hasVentilation': hasVentilation,
  };

  factory LigneEcriture.fromJson(Map<String, dynamic> json) => LigneEcriture(
    id: json['id'],
    journalPeriodeId: json['journalPeriodeId'],
    numeroEnregistrement: json['numeroEnregistrement'],
    jour: json['jour'],
    numeroDocument: json['numeroDocument'],
    reference: json['reference'],
    numeroCompte: json['numeroCompte'],
    numeroTiers: json['numeroTiers'],
    libelle: json['libelle'],
    montantDebit: (json['montantDebit'] as num).toDouble(),
    montantCredit: (json['montantCredit'] as num).toDouble(),
    ventilation:
        json['ventilation'] != null
            ? VentilationAnalytique.fromJson(json['ventilation'])
            : null,
    dateCreation: DateTime.parse(json['dateCreation']),
    hasVentilation: _mapToBool(json['hasVentilation']),
  );

  factory LigneEcriture.fromMap(Map<String, dynamic> map) => LigneEcriture(
    id: map['id'],
    journalPeriodeId: map['journal_periode_id'] ?? 0,
    numeroEnregistrement: map['numero_enregistrement'] ?? 0,
    jour: map['jour'] ?? 0,
    numeroDocument: map['numero_document'] ?? '',
    reference: map['reference'],
    numeroCompte: map['numero_compte'] ?? '',
    numeroTiers: map['numero_tiers'],
    libelle: map['libelle'] ?? '',
    montantDebit: (map['montant_debit'] as num?)?.toDouble() ?? 0.0,
    montantCredit: (map['montant_credit'] as num?)?.toDouble() ?? 0.0,
    dateCreation:
        map['created_at'] != null
            ? DateTime.parse(map['created_at'])
            : DateTime.now(),
    hasVentilation: _mapToBool(
      map['has_ventilation'] ?? map['hasVentilation'] ?? map['is_ventilee'],
    ),
  );

  LigneEcriture copyWith({
    int? id,
    int? journalPeriodeId,
    int? numeroEnregistrement,
    int? jour,
    String? numeroDocument,
    String? reference,
    String? numeroCompte,
    String? numeroTiers,
    String? libelle,
    double? montantDebit,
    double? montantCredit,
    VentilationAnalytique? ventilation,
    DateTime? dateCreation,
    bool? hasVentilation,
  }) {
    return LigneEcriture(
      id: id ?? this.id,
      journalPeriodeId: journalPeriodeId ?? this.journalPeriodeId,
      numeroEnregistrement: numeroEnregistrement ?? this.numeroEnregistrement,
      jour: jour ?? this.jour,
      numeroDocument: numeroDocument ?? this.numeroDocument,
      reference: reference ?? this.reference,
      numeroCompte: numeroCompte ?? this.numeroCompte,
      numeroTiers: numeroTiers ?? this.numeroTiers,
      libelle: libelle ?? this.libelle,
      montantDebit: montantDebit ?? this.montantDebit,
      montantCredit: montantCredit ?? this.montantCredit,
      ventilation: ventilation ?? this.ventilation,
      dateCreation: dateCreation ?? this.dateCreation,
      hasVentilation: hasVentilation ?? this.hasVentilation,
    );
  }
}

/// Représente une ventilation analytique d'une ligne
class VentilationAnalytique {
  final int? id;
  final int ligneEcritureId;
  final String type; // 'fonctionnement' ou 'projet'
  final String? idProjet;
  final String? typeActivite; // 'administration' ou 'activite'
  final String? idBailleur;
  final String? postebudgetaire;
  final String? ligneBudgetaire;
  final double montantVentrle;
  final DateTime dateCreation;
  final String? projetNom;
  final String? bailleurNom;
  final String? posteNom;
  final String? ligneNom;

  VentilationAnalytique({
    this.id,
    required this.ligneEcritureId,
    required this.type,
    this.idProjet,
    this.typeActivite,
    this.idBailleur,
    this.postebudgetaire,
    this.ligneBudgetaire,
    this.montantVentrle = 0.0,
    DateTime? dateCreation,
    this.projetNom,
    this.bailleurNom,
    this.posteNom,
    this.ligneNom,
  }) : dateCreation = dateCreation ?? DateTime.now();

  bool get isComplete {
    if (type == 'fonctionnement') return true;
    if (type == 'projet') {
      return idProjet != null &&
          typeActivite != null &&
          idBailleur != null &&
          (postebudgetaire != null || ligneBudgetaire != null);
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ligneEcritureId': ligneEcritureId,
    'type': type,
    'idProjet': idProjet,
    'typeActivite': typeActivite,
    'idBailleur': idBailleur,
    'postebudgetaire': postebudgetaire,
    'ligneBudgetaire': ligneBudgetaire,
    'montantVentrle': montantVentrle,
    'dateCreation': dateCreation.toIso8601String(),
    'projetNom': projetNom,
    'bailleurNom': bailleurNom,
    'posteNom': posteNom,
    'ligneNom': ligneNom,
  };

  factory VentilationAnalytique.fromJson(Map<String, dynamic> json) =>
      VentilationAnalytique(
        id: json['id'],
        ligneEcritureId: json['ligneEcritureId'],
        type: json['type'],
        idProjet: json['idProjet'],
        typeActivite: json['typeActivite'],
        idBailleur: json['idBailleur'],
        postebudgetaire: json['postebudgetaire'],
        ligneBudgetaire: json['ligneBudgetaire'],
        montantVentrle: (json['montantVentrle'] as num).toDouble(),
        dateCreation: DateTime.parse(json['dateCreation']),
        projetNom: json['projetNom'],
        bailleurNom: json['bailleurNom'],
        posteNom: json['posteNom'],
        ligneNom: json['ligneNom'],
      );

  factory VentilationAnalytique.fromMap(Map<String, dynamic> map) =>
      VentilationAnalytique(
        id: map['id'],
        ligneEcritureId: map['ecriture_id'] ?? 0,
        type: map['type'] ?? 'fonctionnement',
        idProjet: map['id_projet']?.toString(),
        typeActivite: map['volet'] ?? map['type_activite'],
        idBailleur: map['id_bailleur']?.toString(),
        postebudgetaire: map['id_poste_budgetaire']?.toString(),
        ligneBudgetaire: map['id_ligne_budgetaire']?.toString(),
        montantVentrle: (map['montant_ventile'] as num?)?.toDouble() ?? 0.0,
        dateCreation:
            map['created_at'] != null
                ? DateTime.parse(map['created_at'])
                : DateTime.now(),
        projetNom: map['projet_nom'] ?? map['projet_designation'],
        bailleurNom: map['bailleur_nom'] ?? map['bailleur_designation'],
        posteNom: map['poste_nom'],
        ligneNom: map['ligne_nom'],
      );
}

/// Résumé des totaux
class TotauxSaisie {
  final double totalDebit;
  final double totalCredit;
  final double solde;
  final bool isEquilibre;
  final bool isSoldeNegatif;

  TotauxSaisie({
    required this.totalDebit,
    required this.totalCredit,
    double? solde,
    bool? isEquilibre,
    bool? isSoldeNegatif,
  }) : solde = solde ?? (totalDebit - totalCredit),
       isEquilibre = isEquilibre ?? ((totalDebit - totalCredit).abs() < 0.01),
       isSoldeNegatif = isSoldeNegatif ?? ((totalDebit - totalCredit) < 0);
}

/// Convertit des valeurs issues de SQLite en booléen fiable
bool _mapToBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    if (normalized == 'true' || normalized == '1' || normalized == 'oui') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'non') {
      return false;
    }
  }
  return false;
}
