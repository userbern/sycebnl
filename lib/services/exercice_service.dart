import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/compte.dart';
import '../models/saisie_comptable.dart';
import 'database_service.dart';

/// Une ligne du journal des A-Nouveaux (report ou équilibrage).
class AnLigne {
  final String numeroCompte;
  final String intitule;
  final double montantDebit;
  final double montantCredit;

  const AnLigne({
    required this.numeroCompte,
    required this.intitule,
    required this.montantDebit,
    required this.montantCredit,
  });
}

/// Aperçu du journal des A-Nouveaux d'un exercice clôturé : les comptes
/// reportés (classes 1 à 5) et l'écriture d'équilibrage (121 ou 129).
class AnPreview {
  final List<AnLigne> lignes;
  final double totalDebit;
  final double totalCredit;
  final String? compteEquilibrage;
  final double montantEquilibrage;

  const AnPreview({
    required this.lignes,
    required this.totalDebit,
    required this.totalCredit,
    required this.compteEquilibrage,
    required this.montantEquilibrage,
  });

  bool get isEquilibre => (totalDebit - totalCredit).abs() <= 0.01;
}

/// Exception levée quand une opération sur les exercices est refusée pour
/// une raison métier (ex: clôture manquante, incohérence chronologique).
class ExerciceOperationException implements Exception {
  final String message;
  const ExerciceOperationException(this.message);

  @override
  String toString() => message;
}

/// Logique métier du cycle de vie des exercices comptables : création d'un
/// nouvel exercice (avec report, sans report, ou antérieur).
///
/// La création avec report recalcule les soldes des comptes classes 1 à 5
/// directement depuis les écritures de l'exercice précédent (aucune clôture
/// préalable requise) et les inscrit comme écritures d'ouverture du nouvel
/// exercice, taguées `code_journal = 'AN'`.
///
/// `getAnPreview` reste disponible pour la consultation en lecture seule
/// d'un éventuel journal AN généré par l'ancienne logique de clôture, sur
/// des dossiers créés avant ce changement.
class ExerciceService {
  static const String codeJournalAN = 'AN';

  static String _formatDateYMD(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Trouve, parmi une liste d'exercices, celui dont la date de fin précède
  /// immédiatement [dateDebut].
  static Map<String, dynamic>? exercicePrecedent(
    List<Map<String, dynamic>> exercices,
    DateTime dateDebut,
  ) {
    Map<String, dynamic>? selected;
    DateTime? selectedEnd;

    for (final exercice in exercices) {
      final rawEnd = exercice['date_fin'];
      if (rawEnd == null) continue;

      final end = DateTime.tryParse(rawEnd.toString());
      if (end == null || !end.isBefore(dateDebut)) continue;

      if (selectedEnd == null || end.isAfter(selectedEnd)) {
        selected = exercice;
        selectedEnd = end;
      }
    }

    return selected;
  }

  /// Exercice existant dont la date de fin est la plus tardive, ou `null`
  /// si aucun exercice n'existe encore.
  static Map<String, dynamic>? _dernierExerciceGlobal(
    List<Map<String, dynamic>> exercices,
  ) {
    Map<String, dynamic>? best;
    DateTime? bestEnd;
    for (final e in exercices) {
      final end = DateTime.tryParse(e['date_fin']?.toString() ?? '');
      if (end == null) continue;
      if (bestEnd == null || end.isAfter(bestEnd)) {
        best = e;
        bestEnd = end;
      }
    }
    return best;
  }

  /// Exercice existant dont la date de début est la plus ancienne, ou `null`
  /// si aucun exercice n'existe encore.
  static Map<String, dynamic>? _plusAncienExerciceGlobal(
    List<Map<String, dynamic>> exercices,
  ) {
    Map<String, dynamic>? best;
    DateTime? bestStart;
    for (final e in exercices) {
      final start = DateTime.tryParse(e['date_debut']?.toString() ?? '');
      if (start == null) continue;
      if (bestStart == null || start.isBefore(bestStart)) {
        best = e;
        bestStart = start;
      }
    }
    return best;
  }

  static bool _memeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Vérifie que [dateDebut] enchaîne exactement (sans trou ni
  /// chevauchement) sur la fin de l'exercice existant le plus récent, s'il y
  /// en a un. Ne bloque rien pour le tout premier exercice d'un dossier.
  static void _validerContinuiteApres(
    DateTime dateDebut,
    List<Map<String, dynamic>> exercices,
  ) {
    final dernier = _dernierExerciceGlobal(exercices);
    if (dernier == null) return;

    final finPrecedente = DateTime.tryParse(dernier['date_fin'].toString());
    if (finPrecedente == null) return;

    final attendu = finPrecedente.add(const Duration(days: 1));
    if (!_memeJour(dateDebut, attendu)) {
      throw ExerciceOperationException(
        'La date de début doit suivre immédiatement la fin de l\'exercice '
        '"${dernier['code']}" (${_formatDateYMD(attendu)}), sans écart ni '
        'chevauchement.',
      );
    }
  }

  /// Vérifie que [dateFin] enchaîne exactement (sans trou ni chevauchement)
  /// sur le début de l'exercice existant le plus ancien, s'il y en a un.
  static void _validerContinuiteAvant(
    DateTime dateFin,
    List<Map<String, dynamic>> exercices,
  ) {
    final plusAncien = _plusAncienExerciceGlobal(exercices);
    if (plusAncien == null) return;

    final debutSuivant = DateTime.tryParse(plusAncien['date_debut'].toString());
    if (debutSuivant == null) return;

    final attendu = debutSuivant.subtract(const Duration(days: 1));
    if (!_memeJour(dateFin, attendu)) {
      throw ExerciceOperationException(
        'La date de fin doit se terminer exactement la veille du début de '
        'l\'exercice "${plusAncien['code']}" (${_formatDateYMD(attendu)}), '
        'sans écart.',
      );
    }
  }

  /// Vérifie l'existence du compte [numeroCompte] et le crée dans le plan
  /// comptable s'il n'existe pas encore (compte d'équilibrage libre choisi
  /// par l'utilisateur pour le report).
  static Future<void> _ensureCompteEquilibrage(
    Transaction txn,
    String numeroCompte,
    String now,
  ) async {
    final existing = await txn.query(
      'compte',
      where: 'numero_compte = ? AND deleted_at IS NULL',
      whereArgs: [numeroCompte],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    await txn.insert('compte', {
      'numero_compte': numeroCompte,
      'intitule': 'Report à nouveau',
      'type': TypeCompte.detail.toDbString(),
      'nature': NatureCompte.bilanRessourcesDurables.toDbString(),
      'liaison_tiers': 0,
      'description':
          'Compte créé automatiquement lors du report d\'un exercice',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Lit le journal AN généré à la clôture de [exerciceId] et le restitue
  /// sous forme d'aperçu (comptes reportés, total, compte d'équilibrage).
  static Future<AnPreview?> getAnPreview(int exerciceId) async {
    await DatabaseService.ensureDatabaseOpen();

    final periodeRows = await DatabaseService.database.query(
      'journaux_periodes',
      where: 'code_journal = ? AND exercice_id = ?',
      whereArgs: [codeJournalAN, exerciceId],
      limit: 1,
    );
    if (periodeRows.isEmpty) return null;

    final periodeId = periodeRows.first['id'] as int;
    final ecritures = await DatabaseService.database.rawQuery(
      '''
      SELECT e.numero_compte, e.libelle, e.montant_debit, e.montant_credit,
             COALESCE(c.intitule, e.libelle) AS intitule_compte
      FROM ecritures e
      LEFT JOIN compte c ON c.numero_compte = e.numero_compte
      WHERE e.journal_periode_id = ?
      ORDER BY e.numero_enregistrement
      ''',
      [periodeId],
    );

    final lignes = <AnLigne>[];
    double totalDebit = 0;
    double totalCredit = 0;
    String? compteEquilibrage;
    double montantEquilibrage = 0;

    for (final row in ecritures) {
      final numeroCompte = row['numero_compte']?.toString() ?? '';
      final debit = (row['montant_debit'] as num?)?.toDouble() ?? 0.0;
      final credit = (row['montant_credit'] as num?)?.toDouble() ?? 0.0;
      totalDebit += debit;
      totalCredit += credit;

      lignes.add(AnLigne(
        numeroCompte: numeroCompte,
        intitule: row['intitule_compte']?.toString() ?? '',
        montantDebit: debit,
        montantCredit: credit,
      ));

      if (numeroCompte.startsWith('121') || numeroCompte.startsWith('129')) {
        compteEquilibrage = numeroCompte;
        montantEquilibrage = debit > 0 ? debit : credit;
      }
    }

    return AnPreview(
      lignes: lignes,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      compteEquilibrage: compteEquilibrage,
      montantEquilibrage: montantEquilibrage,
    );
  }

  /// Calcule uniquement les totaux débit/crédit des soldes des comptes
  /// classes 1 à 5 de [exercicePrecedentId] (sans ligne d'équilibrage, sans
  /// détail par compte). Utilisé pour afficher le solde total à reporter
  /// avant même que l'utilisateur ait choisi le compte d'équilibrage.
  static Future<({double totalDebit, double totalCredit})> calculerTotauxReport(
    int exercicePrecedentId,
  ) async {
    await DatabaseService.ensureDatabaseOpen();

    final soldes = await DatabaseService.database.rawQuery(
      '''
      SELECT COALESCE(SUM(e.montant_debit - e.montant_credit), 0) AS solde
      FROM compte c
      JOIN ecritures e ON e.numero_compte = c.numero_compte
      JOIN journaux_periodes jp ON jp.id = e.journal_periode_id
      WHERE jp.exercice_id = ?
        AND c.deleted_at IS NULL
        AND substr(c.numero_compte, 1, 1) IN ('1', '2', '3', '4', '5')
      GROUP BY c.numero_compte
      HAVING ABS(solde) > 0.01
      ''',
      [exercicePrecedentId],
    );

    double totalDebit = 0;
    double totalCredit = 0;
    for (final row in soldes) {
      final solde = (row['solde'] as num?)?.toDouble() ?? 0.0;
      if (solde > 0) {
        totalDebit += solde;
      } else {
        totalCredit += -solde;
      }
    }
    return (totalDebit: totalDebit, totalCredit: totalCredit);
  }

  /// Calcule, sans rien écrire en base, les soldes des comptes classes 1 à 5
  /// de [exercicePrecedentId] tels qu'ils seront repris à l'ouverture du
  /// nouvel exercice, avec la ligne d'équilibrage sur le compte choisi par
  /// l'utilisateur ([compteEquilibrage]) le cas échéant. Utilisé pour
  /// l'aperçu avant validation.
  static Future<AnPreview> previewReportSoldes(
    int exercicePrecedentId, {
    required String compteEquilibrage,
  }) async {
    await DatabaseService.ensureDatabaseOpen();

    final soldes = await DatabaseService.database.rawQuery(
      '''
      SELECT
        c.numero_compte,
        c.intitule,
        COALESCE(SUM(e.montant_debit - e.montant_credit), 0) AS solde
      FROM compte c
      JOIN ecritures e ON e.numero_compte = c.numero_compte
      JOIN journaux_periodes jp ON jp.id = e.journal_periode_id
      WHERE jp.exercice_id = ?
        AND c.deleted_at IS NULL
        AND substr(c.numero_compte, 1, 1) IN ('1', '2', '3', '4', '5')
      GROUP BY c.numero_compte, c.intitule
      HAVING ABS(solde) > 0.01
      ORDER BY c.numero_compte
      ''',
      [exercicePrecedentId],
    );

    final lignes = <AnLigne>[];
    double totalDebit = 0;
    double totalCredit = 0;

    for (final row in soldes) {
      final numeroCompte = row['numero_compte']?.toString() ?? '';
      final solde = (row['solde'] as num?)?.toDouble() ?? 0.0;
      if (numeroCompte.isEmpty || solde.abs() <= 0.01) continue;

      final debit = solde > 0 ? solde : 0.0;
      final credit = solde < 0 ? -solde : 0.0;
      totalDebit += debit;
      totalCredit += credit;

      lignes.add(AnLigne(
        numeroCompte: numeroCompte,
        intitule: row['intitule']?.toString() ?? '',
        montantDebit: debit,
        montantCredit: credit,
      ));
    }

    String? compteEquilibrageUtilise;
    double montantEquilibrage = 0;
    final ecart = totalDebit - totalCredit;
    if (ecart.abs() > 0.01) {
      final excedent = ecart > 0;
      compteEquilibrageUtilise = compteEquilibrage;
      montantEquilibrage = ecart.abs();
      final debit = ecart < 0 ? -ecart : 0.0;
      final credit = ecart > 0 ? ecart : 0.0;
      totalDebit += debit;
      totalCredit += credit;

      final compteRows = await DatabaseService.database.query(
        'compte',
        where: 'numero_compte = ? AND deleted_at IS NULL',
        whereArgs: [compteEquilibrage],
        limit: 1,
      );
      final intitule = compteRows.isNotEmpty
          ? (compteRows.first['intitule']?.toString() ?? 'Nouveau compte')
          : 'Nouveau compte';

      lignes.add(AnLigne(
        numeroCompte: compteEquilibrage,
        intitule: excedent ? '$intitule (excédent)' : '$intitule (déficit)',
        montantDebit: debit,
        montantCredit: credit,
      ));
    }

    return AnPreview(
      lignes: lignes,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      compteEquilibrage: compteEquilibrageUtilise,
      montantEquilibrage: montantEquilibrage,
    );
  }

  /// Le document qui identifie les écritures de report générées pour
  /// l'exercice de code [code] (voir [creerExerciceAvecReport] /
  /// [regenererReportSoldes]).
  static String _documentReport(String code) => 'OUV-$code';

  static Future<Map<String, dynamic>?> _exerciceParId(int exerciceId) async {
    final exercices = await DatabaseService.getExercices();
    final match = exercices.firstWhere(
      (e) => e['id'] == exerciceId,
      orElse: () => <String, dynamic>{},
    );
    return match.isEmpty ? null : match;
  }

  /// `true` si [periode] est la période contenant les écritures de report
  /// (A-Nouveaux) générées à la création de son exercice — c'est sur cette
  /// période que la régénération est proposée à l'utilisateur.
  static Future<bool> estPeriodeDeReport(JournalPeriode periode) async {
    final exerciceId = periode.exerciceId;
    if (exerciceId == null) return false;

    final exercice = await _exerciceParId(exerciceId);
    if (exercice == null) return false;

    final dateDebut = DateTime.tryParse(exercice['date_debut']?.toString() ?? '');
    if (dateDebut == null) return false;
    if (periode.annee != dateDebut.year || periode.mois != dateDebut.month) {
      return false;
    }

    await DatabaseService.ensureDatabaseOpen();
    final rows = await DatabaseService.database.query(
      'ecritures',
      where: 'journal_periode_id = ? AND numero_document = ?',
      whereArgs: [periode.id, _documentReport(exercice['code'].toString())],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Id de l'exercice précédant celui de [periode], utilisé comme source des
  /// soldes à reporter. `null` si [periode] n'est pas rattachée à un
  /// exercice ou si aucun exercice précédent n'existe.
  static Future<int?> exercicePrecedentIdPourPeriode(
    JournalPeriode periode,
  ) async {
    final exerciceId = periode.exerciceId;
    if (exerciceId == null) return null;
    final exercice = await _exerciceParId(exerciceId);
    if (exercice == null) return null;

    final dateDebut = DateTime.tryParse(exercice['date_debut']?.toString() ?? '');
    if (dateDebut == null) return null;

    final exercices = await DatabaseService.getExercices();
    final precedent = exercicePrecedent(exercices, dateDebut);
    return precedent == null ? null : precedent['id'] as int;
  }

  /// Compte d'équilibrage utilisé lors de la précédente génération du report
  /// de [periode] (déduit de l'écriture "Report à nouveau…"), s'il y en a
  /// un. Sert à pré-remplir le champ lors d'une régénération.
  static Future<String?> compteEquilibrageActuel(JournalPeriode periode) async {
    final exerciceId = periode.exerciceId;
    if (exerciceId == null) return null;
    final exercice = await _exerciceParId(exerciceId);
    if (exercice == null) return null;

    await DatabaseService.ensureDatabaseOpen();
    final rows = await DatabaseService.database.query(
      'ecritures',
      where: 'journal_periode_id = ? AND numero_document = ? AND libelle LIKE ?',
      whereArgs: [
        periode.id,
        _documentReport(exercice['code'].toString()),
        'Report à nouveau%',
      ],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['numero_compte']?.toString();
  }

  /// Recalcule les écritures de report (A-Nouveaux) de [periode] à partir
  /// des soldes ACTUELS de l'exercice précédent, et remplace celles générées
  /// lors d'une précédente génération. À utiliser quand des écritures de
  /// l'exercice précédent ont été ajoutées ou modifiées après la création de
  /// l'exercice courant.
  static Future<AnPreview> regenererReportSoldes({
    required JournalPeriode periode,
    required String compteEquilibrage,
  }) async {
    await DatabaseService.ensureDatabaseOpen();

    final exerciceId = periode.exerciceId;
    if (exerciceId == null) {
      throw const ExerciceOperationException('Période sans exercice associé.');
    }
    final exercice = await _exerciceParId(exerciceId);
    if (exercice == null) {
      throw const ExerciceOperationException('Exercice introuvable.');
    }

    final exercices = await DatabaseService.getExercices();
    final dateDebut = DateTime.parse(exercice['date_debut'].toString());
    final precedent = exercicePrecedent(exercices, dateDebut);
    if (precedent == null) {
      throw const ExerciceOperationException(
        'Aucun exercice précédent trouvé pour régénérer ce report.',
      );
    }

    final code = exercice['code'].toString();
    final document = _documentReport(code);
    final precedentId = precedent['id'] as int;
    final dateDebutStr = _formatDateYMD(dateDebut);

    late AnPreview preview;

    await DatabaseService.database.transaction((txn) async {
      await txn.delete(
        'ecritures',
        where: 'journal_periode_id = ? AND numero_document = ?',
        whereArgs: [periode.id, document],
      );

      final soldes = await txn.rawQuery(
        '''
        SELECT
          c.numero_compte,
          c.intitule,
          COALESCE(SUM(e.montant_debit - e.montant_credit), 0) AS solde
        FROM compte c
        JOIN ecritures e ON e.numero_compte = c.numero_compte
        JOIN journaux_periodes jp ON jp.id = e.journal_periode_id
        WHERE jp.exercice_id = ?
          AND c.deleted_at IS NULL
          AND substr(c.numero_compte, 1, 1) IN ('1', '2', '3', '4', '5')
        GROUP BY c.numero_compte, c.intitule
        HAVING ABS(solde) > 0.01
        ORDER BY c.numero_compte
        ''',
        [precedentId],
      );

      final now = DateTime.now().toIso8601String();
      final maxNumRows = await txn.rawQuery(
        'SELECT COALESCE(MAX(numero_enregistrement), 0) AS m FROM ecritures '
        'WHERE journal_periode_id = ?',
        [periode.id],
      );
      var numeroEnregistrement =
          ((maxNumRows.first['m'] as num?)?.toInt() ?? 0) + 1;

      final lignes = <AnLigne>[];
      double totalDebit = 0;
      double totalCredit = 0;

      for (final row in soldes) {
        final numeroCompte = row['numero_compte']?.toString() ?? '';
        final solde = (row['solde'] as num?)?.toDouble() ?? 0.0;
        if (numeroCompte.isEmpty || solde.abs() <= 0.01) continue;

        final debit = solde > 0 ? solde : 0.0;
        final credit = solde < 0 ? -solde : 0.0;
        totalDebit += debit;
        totalCredit += credit;

        lignes.add(AnLigne(
          numeroCompte: numeroCompte,
          intitule: row['intitule']?.toString() ?? '',
          montantDebit: debit,
          montantCredit: credit,
        ));

        await txn.insert('ecritures', {
          'journal_periode_id': periode.id,
          'numero_enregistrement': numeroEnregistrement++,
          'jour': dateDebut.day,
          'date_comptable': dateDebutStr,
          'numero_document': document,
          'reference': document,
          'numero_compte': numeroCompte,
          'numero_tiers': null,
          'libelle': 'Ouverture $code',
          'montant_debit': debit,
          'montant_credit': credit,
          'is_ventilee': 0,
          'created_at': now,
          'updated_at': now,
        });
      }

      String? compteEquilibrageUtilise;
      double montantEquilibrage = 0;
      final ecart = totalDebit - totalCredit;
      if (ecart.abs() > 0.01) {
        final excedent = ecart > 0;
        await _ensureCompteEquilibrage(txn, compteEquilibrage, now);

        final debit = ecart < 0 ? -ecart : 0.0;
        final credit = ecart > 0 ? ecart : 0.0;
        totalDebit += debit;
        totalCredit += credit;
        compteEquilibrageUtilise = compteEquilibrage;
        montantEquilibrage = ecart.abs();

        final compteRows = await txn.query(
          'compte',
          where: 'numero_compte = ? AND deleted_at IS NULL',
          whereArgs: [compteEquilibrage],
          limit: 1,
        );
        final intitule = compteRows.isNotEmpty
            ? (compteRows.first['intitule']?.toString() ?? 'Nouveau compte')
            : 'Nouveau compte';

        lignes.add(AnLigne(
          numeroCompte: compteEquilibrage,
          intitule: excedent ? '$intitule (excédent)' : '$intitule (déficit)',
          montantDebit: debit,
          montantCredit: credit,
        ));

        await txn.insert('ecritures', {
          'journal_periode_id': periode.id,
          'numero_enregistrement': numeroEnregistrement++,
          'jour': dateDebut.day,
          'date_comptable': dateDebutStr,
          'numero_document': document,
          'reference': document,
          'numero_compte': compteEquilibrage,
          'numero_tiers': null,
          'libelle': excedent
              ? 'Report à nouveau créditeur (excédent) $code'
              : 'Report à nouveau débiteur (déficit) $code',
          'montant_debit': debit,
          'montant_credit': credit,
          'is_ventilee': 0,
          'created_at': now,
          'updated_at': now,
        });
      }

      // Recalcule les totaux agrégés de la période à partir de TOUTES ses
      // écritures (pas seulement celles du report), au cas où l'utilisateur
      // y aurait ajouté des écritures manuelles.
      final aggRows = await txn.rawQuery(
        '''
        SELECT
          COUNT(*) AS nb,
          COALESCE(SUM(montant_debit), 0) AS td,
          COALESCE(SUM(montant_credit), 0) AS tc
        FROM ecritures
        WHERE journal_periode_id = ?
        ''',
        [periode.id],
      );
      final nb = (aggRows.first['nb'] as num?)?.toInt() ?? 0;
      final td = (aggRows.first['td'] as num?)?.toDouble() ?? 0.0;
      final tc = (aggRows.first['tc'] as num?)?.toDouble() ?? 0.0;

      await txn.update(
        'journaux_periodes',
        {
          'nombre_ecritures': nb,
          'total_debit': td,
          'total_credit': tc,
          'solde_final': td - tc,
          'is_equilibre': (td - tc).abs() <= 0.01 ? 1 : 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [periode.id],
      );

      preview = AnPreview(
        lignes: lignes,
        totalDebit: totalDebit,
        totalCredit: totalCredit,
        compteEquilibrage: compteEquilibrageUtilise,
        montantEquilibrage: montantEquilibrage,
      );
    });

    return preview;
  }

  static Future<void> _validerCodeUnique(String code) async {
    final exercices = await DatabaseService.getExercices();
    if (exercices.length >= 5) {
      throw const ExerciceOperationException(
        'Maximum 5 exercices par fichier comptable',
      );
    }
    if (exercices.any((e) => e['code'] == code)) {
      throw const ExerciceOperationException(
        'Un exercice avec ce code existe déjà',
      );
    }
  }

  /// Crée un nouvel exercice en reprenant les soldes de
  /// [exercicePrecedentId], recalculés directement depuis ses écritures
  /// (comptes classes 1 à 5), enregistrés dans le journal [codeJournal]
  /// choisi par l'utilisateur et équilibrés si besoin sur le compte
  /// [compteEquilibrage] qu'il a également choisi. Aucune clôture préalable
  /// requise.
  static Future<void> creerExerciceAvecReport({
    required String code,
    required DateTime dateDebut,
    required DateTime dateFin,
    required int exercicePrecedentId,
    required String codeJournal,
    required String compteEquilibrage,
  }) async {
    await DatabaseService.ensureDatabaseOpen();
    await _validerCodeUnique(code);

    final exercices = await DatabaseService.getExercices();
    final precedent = exercices.firstWhere(
      (e) => e['id'] == exercicePrecedentId,
      orElse: () => <String, dynamic>{},
    );
    if (precedent.isEmpty) {
      throw const ExerciceOperationException('Exercice précédent introuvable.');
    }
    _validerContinuiteApres(dateDebut, exercices);

    final dureeMois = _dureeMois(dateDebut, dateFin);

    await DatabaseService.database.transaction((txn) async {
      final soldes = await txn.rawQuery(
        '''
        SELECT
          c.numero_compte,
          c.intitule,
          COALESCE(SUM(e.montant_debit - e.montant_credit), 0) AS solde
        FROM compte c
        JOIN ecritures e ON e.numero_compte = c.numero_compte
        JOIN journaux_periodes jp ON jp.id = e.journal_periode_id
        WHERE jp.exercice_id = ?
          AND c.deleted_at IS NULL
          AND substr(c.numero_compte, 1, 1) IN ('1', '2', '3', '4', '5')
        GROUP BY c.numero_compte, c.intitule
        HAVING ABS(solde) > 0.01
        ORDER BY c.numero_compte
        ''',
        [exercicePrecedentId],
      );

      final now = DateTime.now().toIso8601String();
      final nouvelExerciceId = await txn.insert('exercice', {
        'code': code,
        'date_debut': _formatDateYMD(dateDebut),
        'date_fin': _formatDateYMD(dateFin),
        'duree_mois': dureeMois,
        'is_active': 0,
        'is_cloture': 0,
        'created_at': now,
        'updated_at': now,
      });

      if (soldes.isNotEmpty) {
        final dateStr = _formatDateYMD(dateDebut);
        final document = 'OUV-$code';
        final nouvellePeriodeId = await txn.insert('journaux_periodes', {
          'code_journal': codeJournal,
          'annee': dateDebut.year,
          'mois': dateDebut.month,
          'exercice_id': nouvelExerciceId,
          'nombre_ecritures': 0,
          'total_debit': 0,
          'total_credit': 0,
          'solde_final': 0,
          'is_equilibre': 0,
          'is_closed': 0,
          'created_at': now,
          'updated_at': now,
        });

        double totalDebit = 0;
        double totalCredit = 0;
        var numeroEnregistrement = 1;

        for (final row in soldes) {
          final numeroCompte = row['numero_compte']?.toString() ?? '';
          final solde = (row['solde'] as num?)?.toDouble() ?? 0.0;
          if (numeroCompte.isEmpty || solde.abs() <= 0.01) continue;

          final debit = solde > 0 ? solde : 0.0;
          final credit = solde < 0 ? -solde : 0.0;
          totalDebit += debit;
          totalCredit += credit;

          await txn.insert('ecritures', {
            'journal_periode_id': nouvellePeriodeId,
            'numero_enregistrement': numeroEnregistrement++,
            'jour': dateDebut.day,
            'date_comptable': dateStr,
            'numero_document': document,
            'reference': document,
            'numero_compte': numeroCompte,
            'numero_tiers': null,
            'libelle': 'Ouverture $code',
            'montant_debit': debit,
            'montant_credit': credit,
            'is_ventilee': 0,
            'created_at': now,
            'updated_at': now,
          });
        }

        final ecart = totalDebit - totalCredit;
        if (ecart.abs() > 0.01) {
          final excedent = ecart > 0;
          await _ensureCompteEquilibrage(txn, compteEquilibrage, now);

          final debit = ecart < 0 ? -ecart : 0.0;
          final credit = ecart > 0 ? ecart : 0.0;
          totalDebit += debit;
          totalCredit += credit;

          await txn.insert('ecritures', {
            'journal_periode_id': nouvellePeriodeId,
            'numero_enregistrement': numeroEnregistrement++,
            'jour': dateDebut.day,
            'date_comptable': dateStr,
            'numero_document': document,
            'reference': document,
            'numero_compte': compteEquilibrage,
            'numero_tiers': null,
            'libelle': excedent
                ? 'Report à nouveau créditeur (excédent) $code'
                : 'Report à nouveau débiteur (déficit) $code',
            'montant_debit': debit,
            'montant_credit': credit,
            'is_ventilee': 0,
            'created_at': now,
            'updated_at': now,
          });
        }

        await txn.update(
          'journaux_periodes',
          {
            'nombre_ecritures': numeroEnregistrement - 1,
            'total_debit': totalDebit,
            'total_credit': totalCredit,
            'solde_final': totalDebit - totalCredit,
            'is_equilibre': (totalDebit - totalCredit).abs() <= 0.01 ? 1 : 0,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [nouvellePeriodeId],
        );
      }
    });
  }

  /// Crée un exercice totalement vide (pas de compte d'ouverture).
  static Future<void> creerExerciceSansReport({
    required String code,
    required DateTime dateDebut,
    required DateTime dateFin,
  }) async {
    await DatabaseService.ensureDatabaseOpen();
    await _validerCodeUnique(code);

    final exercices = await DatabaseService.getExercices();
    _validerContinuiteApres(dateDebut, exercices);

    final now = DateTime.now().toIso8601String();
    await DatabaseService.database.insert('exercice', {
      'code': code,
      'date_debut': _formatDateYMD(dateDebut),
      'date_fin': _formatDateYMD(dateFin),
      'duree_mois': _dureeMois(dateDebut, dateFin),
      'is_active': 0,
      'is_cloture': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Crée un exercice antérieur aux exercices déjà présents (ex: la base
  /// contient 2026, on ajoute 2025). Vérifie qu'il ne chevauche pas et
  /// précède bien le plus ancien exercice existant.
  static Future<void> creerExerciceAnterieur({
    required String code,
    required DateTime dateDebut,
    required DateTime dateFin,
  }) async {
    await DatabaseService.ensureDatabaseOpen();
    await _validerCodeUnique(code);

    if (!dateFin.isAfter(dateDebut)) {
      throw const ExerciceOperationException(
        'La date de fin doit être postérieure à la date de début.',
      );
    }

    final exercices = await DatabaseService.getExercices();
    _validerContinuiteAvant(dateFin, exercices);

    final now = DateTime.now().toIso8601String();
    await DatabaseService.database.insert('exercice', {
      'code': code,
      'date_debut': _formatDateYMD(dateDebut),
      'date_fin': _formatDateYMD(dateFin),
      'duree_mois': _dureeMois(dateDebut, dateFin),
      'is_active': 0,
      'is_cloture': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  static int _dureeMois(DateTime debut, DateTime fin) {
    final m = (fin.year - debut.year) * 12 + (fin.month - debut.month) + 1;
    return m < 1 ? 1 : m;
  }
}
