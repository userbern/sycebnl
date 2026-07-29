import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/compte.dart';
import '../models/journal.dart';
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

/// Logique métier du cycle de vie des exercices comptables : clôture,
/// génération du journal des A-Nouveaux (AN), et création d'un nouvel
/// exercice (avec report, sans report, ou antérieur).
///
/// Le journal AN est stocké comme une période normale (`journaux_periodes`,
/// code 'AN') rattachée à l'exercice clôturé qui l'a généré. La création
/// avec report ne fait que lire ces écritures et les recopier telles
/// quelles sous le nouvel exercice — aucun recalcul de solde.
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

  /// Clôture un exercice : génère automatiquement le journal des
  /// A-Nouveaux (report des soldes des classes 1 à 5, équilibré par une
  /// écriture sur le compte 121 (excédent) ou 129 (déficit)), puis marque
  /// l'exercice comme clôturé.
  static Future<void> cloturerExercice(int exerciceId) async {
    await DatabaseService.ensureDatabaseOpen();

    final exercices = await DatabaseService.getExercices();
    final exercice = exercices.firstWhere(
      (e) => e['id'] == exerciceId,
      orElse: () => <String, dynamic>{},
    );
    if (exercice.isEmpty) {
      throw const ExerciceOperationException('Exercice introuvable.');
    }
    if ((exercice['is_cloture'] as int? ?? 0) == 1) {
      throw const ExerciceOperationException('Cet exercice est déjà clôturé.');
    }

    final dateFin = DateTime.parse(exercice['date_fin'] as String);
    final config = await DatabaseService.getConfig();
    final longueurCompte = (config?['longueur_compte_general'] as int?) ?? 7;

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
        [exerciceId],
      );

      if (soldes.isNotEmpty) {
        await _genererJournalAN(
          txn,
          exerciceId: exerciceId,
          exerciceCode: exercice['code'] as String,
          dateEcriture: dateFin,
          soldes: soldes,
          longueurCompte: longueurCompte,
        );
      }

      await txn.update(
        'exercice',
        {
          'is_cloture': 1,
          'is_active': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [exerciceId],
      );
    });
  }

  static Future<void> _genererJournalAN(
    Transaction txn, {
    required int exerciceId,
    required String exerciceCode,
    required DateTime dateEcriture,
    required List<Map<String, dynamic>> soldes,
    required int longueurCompte,
  }) async {
    await _ensureJournalAN(txn);

    final now = DateTime.now().toIso8601String();
    final dateStr = _formatDateYMD(dateEcriture);
    final document = 'AN-$exerciceCode';

    final periodeId = await _findOrCreatePeriodeAN(
      txn,
      exerciceId: exerciceId,
      annee: dateEcriture.year,
      mois: dateEcriture.month,
      now: now,
    );

    var numeroEnregistrement = 1;
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

      await txn.insert('ecritures', {
        'journal_periode_id': periodeId,
        'numero_enregistrement': numeroEnregistrement++,
        'jour': dateEcriture.day,
        'date_comptable': dateStr,
        'numero_document': document,
        'reference': document,
        'numero_compte': numeroCompte,
        'numero_tiers': null,
        'libelle': "Solde de clôture $exerciceCode",
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
      final compteEquilibrage = await _ensureCompteResultat(
        txn,
        excedent: excedent,
        longueurCompte: longueurCompte,
        now: now,
      );

      final debit = ecart < 0 ? -ecart : 0.0;
      final credit = ecart > 0 ? ecart : 0.0;
      totalDebit += debit;
      totalCredit += credit;

      await txn.insert('ecritures', {
        'journal_periode_id': periodeId,
        'numero_enregistrement': numeroEnregistrement++,
        'jour': dateEcriture.day,
        'date_comptable': dateStr,
        'numero_document': document,
        'reference': document,
        'numero_compte': compteEquilibrage,
        'numero_tiers': null,
        'libelle': excedent
            ? "Résultat excédentaire $exerciceCode"
            : "Résultat déficitaire $exerciceCode",
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
        'is_closed': 1,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [periodeId],
    );
  }

  static Future<int> _findOrCreatePeriodeAN(
    Transaction txn, {
    required int exerciceId,
    required int annee,
    required int mois,
    required String now,
  }) async {
    final rows = await txn.query(
      'journaux_periodes',
      where: 'code_journal = ? AND annee = ? AND mois = ? AND exercice_id = ?',
      whereArgs: [codeJournalAN, annee, mois, exerciceId],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as int;

    return await txn.insert('journaux_periodes', {
      'code_journal': codeJournalAN,
      'annee': annee,
      'mois': mois,
      'exercice_id': exerciceId,
      'nombre_ecritures': 0,
      'total_debit': 0,
      'total_credit': 0,
      'solde_final': 0,
      'is_equilibre': 0,
      'is_closed': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  static Future<void> _ensureJournalAN(Transaction txn) async {
    final now = DateTime.now().toIso8601String();
    await txn.insert('journal', {
      'code': codeJournalAN,
      'libelle': 'Journal des A-Nouveaux',
      'type': TypeJournal.nonFinancier.toDbString(),
      'numero_compte_tresorerie': null,
      'saisie_analytique': 0,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Renvoie le numéro du compte de résultat (121 excédent / 129 déficit),
  /// paddé selon la longueur de compte configurée pour ce dossier, et le
  /// crée dans le plan comptable s'il n'existe pas encore.
  static Future<String> _ensureCompteResultat(
    Transaction txn, {
    required bool excedent,
    required int longueurCompte,
    required String now,
  }) async {
    final base = excedent ? '121' : '129';
    final numeroCompte = base.length < longueurCompte
        ? base.padRight(longueurCompte, '0')
        : base;

    final existing = await txn.query(
      'compte',
      where: 'numero_compte = ? AND deleted_at IS NULL',
      whereArgs: [numeroCompte],
      limit: 1,
    );
    if (existing.isNotEmpty) return numeroCompte;

    await txn.insert('compte', {
      'numero_compte': numeroCompte,
      'intitule': excedent
          ? 'Report à nouveau créditeur (excédent)'
          : 'Report à nouveau débiteur (déficit)',
      'type': TypeCompte.detail.toDbString(),
      'nature': NatureCompte.bilanRessourcesDurables.toDbString(),
      'liaison_tiers': 0,
      'description':
          'Compte créé automatiquement lors de la clôture pour équilibrer le journal AN',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    return numeroCompte;
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

  /// Crée un nouvel exercice en reprenant, sans aucun recalcul, les
  /// écritures du journal AN généré à la clôture de [exercicePrecedentId].
  static Future<void> creerExerciceAvecReport({
    required String code,
    required DateTime dateDebut,
    required DateTime dateFin,
    required int exercicePrecedentId,
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
    if ((precedent['is_cloture'] as int? ?? 0) != 1) {
      throw const ExerciceOperationException(
        'La clôture de l\'exercice précédent est obligatoire avant de créer '
        'un exercice avec report : elle seule génère le journal AN.',
      );
    }

    final dureeMois = _dureeMois(dateDebut, dateFin);

    await DatabaseService.database.transaction((txn) async {
      final periodeRows = await txn.query(
        'journaux_periodes',
        where: 'code_journal = ? AND exercice_id = ?',
        whereArgs: [codeJournalAN, exercicePrecedentId],
        limit: 1,
      );
      final lignesAN = periodeRows.isEmpty
          ? <Map<String, dynamic>>[]
          : await txn.query(
              'ecritures',
              where: 'journal_periode_id = ?',
              whereArgs: [periodeRows.first['id']],
              orderBy: 'numero_enregistrement',
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

      if (lignesAN.isNotEmpty) {
        final dateStr = _formatDateYMD(dateDebut);
        final document = 'OUV-$code';
        final nouvellePeriodeId = await txn.insert('journaux_periodes', {
          'code_journal': codeJournalAN,
          'annee': dateDebut.year,
          'mois': dateDebut.month,
          'exercice_id': nouvelExerciceId,
          'nombre_ecritures': lignesAN.length,
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
        for (final ligne in lignesAN) {
          final debit = (ligne['montant_debit'] as num?)?.toDouble() ?? 0.0;
          final credit = (ligne['montant_credit'] as num?)?.toDouble() ?? 0.0;
          totalDebit += debit;
          totalCredit += credit;

          await txn.insert('ecritures', {
            'journal_periode_id': nouvellePeriodeId,
            'numero_enregistrement': numeroEnregistrement++,
            'jour': dateDebut.day,
            'date_comptable': dateStr,
            'numero_document': document,
            'reference': document,
            'numero_compte': ligne['numero_compte'],
            'numero_tiers': null,
            'libelle': 'Ouverture $code',
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

  /// Crée un exercice totalement vide (pas de compte d'ouverture). Il
  /// pourra être clôturé plus tard normalement : sa clôture générera son
  /// propre journal AN comme n'importe quel autre exercice.
  static Future<void> creerExerciceSansReport({
    required String code,
    required DateTime dateDebut,
    required DateTime dateFin,
  }) async {
    await DatabaseService.ensureDatabaseOpen();
    await _validerCodeUnique(code);

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
    DateTime? plusAncienDebut;
    for (final e in exercices) {
      final debut = DateTime.tryParse(e['date_debut']?.toString() ?? '');
      if (debut == null) continue;
      if (plusAncienDebut == null || debut.isBefore(plusAncienDebut)) {
        plusAncienDebut = debut;
      }
    }

    if (plusAncienDebut != null && !dateFin.isBefore(plusAncienDebut)) {
      throw ExerciceOperationException(
        'Cet exercice doit se terminer avant le début du plus ancien '
        'exercice existant (${_formatDateYMD(plusAncienDebut)}).',
      );
    }

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
