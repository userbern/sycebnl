import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_service.dart';
import '../models/saisie_comptable.dart';

class SaisieComptableService {
  static Database get database => DatabaseService.database;
  static String _formatDateYMD(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '-${date.month.toString().padLeft(2, '0')}'
      '-${date.day.toString().padLeft(2, '0')}';

  static String _nowIso() => DateTime.now().toIso8601String();

  /// Creer ou recuperer une periode de journal
  static Future<JournalPeriode?> createJournalPeriode({
    required String codeJournal,
    required int annee,
    required int mois,
    required int exerciceId,
  }) async {
    try {
      final id = await database.insert('journaux_periodes', {
        'code_journal': codeJournal,
        'annee': annee,
        'mois': mois,
        'exercice_id': exerciceId,
        'nombre_ecritures': 0,
        'total_debit': 0,
        'total_credit': 0,
        'solde_final': 0,
        'is_equilibre': 0,
        'is_closed': 0,
        'created_at': _nowIso(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      if (id == 0) {
        // La periode existe deja, la recuperer
        final results = await database.query(
          'journaux_periodes',
          where:
              'code_journal = ? AND annee = ? AND mois = ? AND exercice_id = ?',
          whereArgs: [codeJournal, annee, mois, exerciceId],
        );
        if (results.isNotEmpty) {
          return JournalPeriode.fromMap(results.first);
        }
      } else {
        // Nouvelle periode creee
        return JournalPeriode(
          id: id,
          codeJournal: codeJournal,
          annee: annee,
          mois: mois,
          exerciceId: exerciceId,
          dateCreation: DateTime.now(),
          closureStatus: 0,
          isEquilibre: false,
        );
      }
    } catch (e) {
      throw Exception('Erreur creation periode: $e');
    }
    return null;
  }

  /// Recuperer toutes les periodes de journal
  static Future<List<JournalPeriode>> getJournalPeriodes({
    int? exerciceId,
  }) async {
    try {
      final results = await database.query(
        'journaux_periodes',
        where: exerciceId != null ? 'exercice_id = ?' : null,
        whereArgs: exerciceId != null ? [exerciceId] : null,
      );
      return results.map((r) => JournalPeriode.fromMap(r)).toList();
    } catch (e) {
      throw Exception('Erreur recuperation periodes: $e');
    }
  }

  /// Recuperer une periode par ID
  static Future<JournalPeriode> getJournalPeriodeById(int id) async {
    try {
      final results = await database.query(
        'journaux_periodes',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (results.isEmpty) {
        throw Exception('Periode non trouvee');
      }
      return JournalPeriode.fromMap(results.first);
    } catch (e) {
      throw Exception('Erreur recuperation periode: $e');
    }
  }

  /// Recuperer les ecritures pour un journal, une annee et un mois precis
  static Future<List<LigneEcriture>> getEcrituresByJournalAndYear(
    String codeJournal,
    int annee,
    int mois,
    int exerciceId,
  ) async {
    try {
      final results = await database.rawQuery(
        '''
        SELECT e.*, EXISTS(
                 SELECT 1
                 FROM ventilations_analytiques va
                 WHERE va.ecriture_id = e.id
               ) AS has_ventilation
        FROM ecritures e
        JOIN journaux_periodes jp ON e.journal_periode_id = jp.id
        WHERE jp.code_journal = ? AND jp.annee = ? AND jp.mois = ? AND jp.exercice_id = ?
        ORDER BY e.numero_enregistrement DESC, e.jour DESC
        ''',
        [codeJournal, annee, mois, exerciceId],
      );
      return results.map((r) => LigneEcriture.fromMap(r)).toList();
    } catch (e) {
      throw Exception('Erreur recuperation ecritures: $e');
    }
  }

  /// Recuperer les ecritures d'une periode
  static Future<List<LigneEcriture>> getEcritures(int journalPeriodeId) async {
    try {
      final results = await database.rawQuery(
        '''
        SELECT e.*, EXISTS(
                 SELECT 1
                 FROM ventilations_analytiques va
                 WHERE va.ecriture_id = e.id
               ) AS has_ventilation
        FROM ecritures e
        WHERE e.journal_periode_id = ?
        ORDER BY e.numero_enregistrement DESC, e.jour DESC
        ''',
        [journalPeriodeId],
      );
      return results.map((r) => LigneEcriture.fromMap(r)).toList();
    } catch (e) {
      throw Exception('Erreur recuperation ecritures: $e');
    }
  }

  /// Recuperer les ecritures d'un compte pour l'interrogation
  static Future<List<LigneEcriture>> getEcrituresParCompte({
    required String numeroCompte,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    try {
      final query = StringBuffer('''
        SELECT e.*,
               jp.annee AS periode_annee,
               jp.mois AS periode_mois,
               jp.code_journal,
               EXISTS(
                 SELECT 1
                 FROM ventilations_analytiques va
                 WHERE va.ecriture_id = e.id AND va.deleted_at IS NULL
               ) AS has_ventilation
        FROM ecritures e
        JOIN journaux_periodes jp ON e.journal_periode_id = jp.id
        WHERE e.numero_compte = ?
      ''');
      final queryArgs = <dynamic>[numeroCompte];

      if (dateDebut != null) {
        query.write(' AND date(e.date_comptable) >= date(?)');
        queryArgs.add(_formatDateYMD(dateDebut));
      }

      if (dateFin != null) {
        query.write(' AND date(e.date_comptable) <= date(?)');
        queryArgs.add(_formatDateYMD(dateFin));
      }

      query.write('''
        ORDER BY date(e.date_comptable) ASC, e.numero_enregistrement ASC, e.id ASC
      ''');

      final results = await database.rawQuery(query.toString(), queryArgs);
      return results.map((r) => LigneEcriture.fromMap(r)).toList();
    } catch (e) {
      throw Exception('Erreur recuperation interrogation compte: $e');
    }
  }

  static Future<List<LigneEcriture>> getEcrituresNonLettrees({
    required String numeroCompte,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) {
    return getEcrituresParCompte(
      numeroCompte: numeroCompte,
      dateDebut: dateDebut,
      dateFin: dateFin,
    ).then(
      (ecritures) =>
          ecritures.where((ecriture) => !ecriture.isLettrie).toList(),
    );
  }

  static Future<String> lettrerEcritures({
    required String numeroCompte,
    required List<int> ecritureIds,
    String? codeLettrage,
  }) async {
    if (ecritureIds.length < 2) {
      throw Exception('Sélectionnez au moins deux écritures à lettrer');
    }

    final selected = await database.rawQuery('''
      SELECT id, numero_compte, montant_debit, montant_credit, lettrage_code
      FROM ecritures
      WHERE id IN (${ecritureIds.map((_) => '?').join(', ')})
      ''', ecritureIds);

    if (selected.length != ecritureIds.length) {
      throw Exception('Certaines écritures sélectionnées sont introuvables');
    }

    double totalDebit = 0;
    double totalCredit = 0;
    for (final row in selected) {
      final compte = row['numero_compte']?.toString() ?? '';
      if (compte != numeroCompte) {
        throw Exception(
          'Toutes les écritures doivent appartenir au même compte',
        );
      }

      final lettrageExistant = row['lettrage_code']?.toString() ?? '';
      if (lettrageExistant.isNotEmpty) {
        throw Exception('Au moins une écriture est déjà lettrée');
      }

      totalDebit += (row['montant_debit'] as num?)?.toDouble() ?? 0.0;
      totalCredit += (row['montant_credit'] as num?)?.toDouble() ?? 0.0;
    }

    if ((totalDebit - totalCredit).abs() > 0.01) {
      throw Exception(
        'Le lettrage est possible seulement si le débit et le crédit sont équilibrés',
      );
    }

    final effectiveCode = codeLettrage ?? _generateLettrageCode(numeroCompte);
    final now = _nowIso();

    await database.transaction((txn) async {
      for (final id in ecritureIds) {
        await txn.update(
          'ecritures',
          {
            'lettrage_code': effectiveCode,
            'lettrage_date': now,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });

    return effectiveCode;
  }

  static Future<List<String>> lettrerAutomatiquement({
    required String numeroCompte,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final candidates = await getEcrituresNonLettrees(
      numeroCompte: numeroCompte,
      dateDebut: dateDebut,
      dateFin: dateFin,
    );

    final buckets = <String, List<LigneEcriture>>{};
    for (final ligne in candidates) {
      final montant = (ligne.montantDebit > 0
              ? ligne.montantDebit
              : ligne.montantCredit)
          .toStringAsFixed(2);
      final reference = (ligne.reference ?? '').trim().toLowerCase();
      final key = reference.isEmpty ? montant : '$montant|$reference';
      buckets.putIfAbsent(key, () => []).add(ligne);
    }

    final codes = <String>[];
    final now = _nowIso();

    await database.transaction((txn) async {
      for (final entry in buckets.entries) {
        final lignes = entry.value;
        if (lignes.length < 2) continue;

        double debit = 0;
        double credit = 0;
        for (final ligne in lignes) {
          debit += ligne.montantDebit;
          credit += ligne.montantCredit;
        }

        if ((debit - credit).abs() > 0.01) continue;

        final code = _generateLettrageCode(numeroCompte);
        codes.add(code);

        for (final ligne in lignes) {
          if (ligne.id == null) continue;
          await txn.update(
            'ecritures',
            {'lettrage_code': code, 'lettrage_date': now, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [ligne.id],
          );
        }
      }
    });

    return codes;
  }

  static Future<void> delettrerEcritures(List<int> ecritureIds) async {
    if (ecritureIds.isEmpty) return;

    final now = _nowIso();
    await database.transaction((txn) async {
      for (final id in ecritureIds) {
        await txn.update(
          'ecritures',
          {'lettrage_code': null, 'lettrage_date': null, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  /// Recuperer le nombre d'ecritures par periode
  static Future<Map<int, int>> getEcritureCountsByPeriode() async {
    try {
      final results = await database.rawQuery(
        'SELECT journal_periode_id, COUNT(DISTINCT numero_enregistrement) AS total FROM ecritures GROUP BY journal_periode_id',
      );

      final counts = <int, int>{};
      for (final row in results) {
        final rawId = row['journal_periode_id'];
        final rawTotal = row['total'];
        if (rawId is int) {
          final total =
              rawTotal is int
                  ? rawTotal
                  : rawTotal is num
                  ? rawTotal.toInt()
                  : 0;
          counts[rawId] = total;
        }
      }

      return counts;
    } catch (e) {
      throw Exception('Erreur recuperation nombre ecritures: $e');
    }
  }

  /// Ajouter une ligne d'ecriture
  static Future<int> addLigneEcriture(LigneEcriture ligne) async {
    try {
      final map = {
        'journal_periode_id': ligne.journalPeriodeId,
        'numero_enregistrement': ligne.numeroEnregistrement,
        'jour': ligne.jour,
        'date_comptable': _formatDateYMD(ligne.dateComptable),
        'numero_document': ligne.numeroDocument,
        'reference': ligne.reference,
        'numero_compte': ligne.numeroCompte,
        'numero_tiers': ligne.numeroTiers,
        'libelle': ligne.libelle,
        'montant_debit': ligne.montantDebit,
        'montant_credit': ligne.montantCredit,
        'is_ventilee': 0,
        'lettrage_code': ligne.lettrageCode,
        'lettrage_date': ligne.lettrageDate?.toIso8601String(),
        'created_at': _nowIso(),
        'updated_at': _nowIso(),
      };
      return await database.insert('ecritures', map);
    } catch (e) {
      throw Exception('Erreur ajout ecriture: $e');
    }
  }

  /// Modifier une ligne d'ecriture
  static Future<int> updateEcriture(LigneEcriture ligne) async {
    try {
      final map = {
        'journal_periode_id': ligne.journalPeriodeId,
        'numero_enregistrement': ligne.numeroEnregistrement,
        'jour': ligne.jour,
        'date_comptable': _formatDateYMD(ligne.dateComptable),
        'numero_document': ligne.numeroDocument,
        'reference': ligne.reference,
        'numero_compte': ligne.numeroCompte,
        'numero_tiers': ligne.numeroTiers,
        'libelle': ligne.libelle,
        'montant_debit': ligne.montantDebit,
        'montant_credit': ligne.montantCredit,
        'lettrage_code': ligne.lettrageCode,
        'lettrage_date': ligne.lettrageDate?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      return await database.update(
        'ecritures',
        map,
        where: 'id = ?',
        whereArgs: [ligne.id],
      );
    } catch (e) {
      throw Exception('Erreur modification ecriture: $e');
    }
  }

  /// Supprimer une ligne d'ecriture
  static Future<int> deleteEcriture(int id) async {
    try {
      return await database.delete(
        'ecritures',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Erreur suppression ecriture: $e');
    }
  }

  /// Calculer les totaux et solde
  static TotauxSaisie calculateTotaux(List<LigneEcriture> ecritures) {
    double totalDebit = 0;
    double totalCredit = 0;

    for (var ecriture in ecritures) {
      totalDebit += ecriture.montantDebit;
      totalCredit += ecriture.montantCredit;
    }

    return TotauxSaisie(
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      solde: totalDebit - totalCredit,
      isEquilibre: (totalDebit - totalCredit).abs() < 0.01,
    );
  }

  /// Obtenir le prochain numero d'enregistrement
  static int getNextNumeroEnregistrement(List<LigneEcriture> ecritures) {
    if (ecritures.isEmpty) {
      return 1;
    }
    final maxNumero = ecritures.fold<int>(
      0,
      (prev, ecriture) =>
          ecriture.numeroEnregistrement > prev
              ? ecriture.numeroEnregistrement
              : prev,
    );
    return maxNumero + 1;
  }

  static Map<String, dynamic> _ventilationToMap(
    VentilationAnalytique v, {
    bool forSave = false,
  }) {
    final map = <String, dynamic>{
      'ecriture_id': v.ligneEcritureId,
      'type': v.type,
      'montant_ventile': v.montantVentrle,
      'created_at': _nowIso(),
      'updated_at': _nowIso(),
    };

    if (forSave) {
      map['id_projet'] = v.idProjet != null ? int.tryParse(v.idProjet!) : null;
      map['volet'] = v.typeActivite;
      map['id_bailleur'] =
          v.idBailleur != null ? int.tryParse(v.idBailleur!) : null;
      map['id_poste_budgetaire'] =
          v.postebudgetaire != null ? int.tryParse(v.postebudgetaire!) : null;
      map['id_ligne_budgetaire'] =
          v.ligneBudgetaire != null ? int.tryParse(v.ligneBudgetaire!) : null;
    } else {
      map['id_projet'] = v.idProjet;
      map['type_activite'] = v.typeActivite;
      map['id_bailleur'] = v.idBailleur;
      map['poste_budgetaire'] = v.postebudgetaire;
      map['ligne_budgetaire'] = v.ligneBudgetaire;
    }

    return map;
  }

  /// Ajouter une ventilation analytique
  static Future<int> addVentilationAnalytique(
    VentilationAnalytique ventilation,
  ) async {
    try {
      final map = _ventilationToMap(ventilation, forSave: false);
      final id = await database.insert('ventilations_analytiques', map);
      await database.update(
        'ecritures',
        {'is_ventilee': 1, 'updated_at': _nowIso()},
        where: 'id = ?',
        whereArgs: [ventilation.ligneEcritureId],
      );
      return id;
    } catch (e) {
      throw Exception('Erreur ajout ventilation: $e');
    }
  }

  /// Recuperer les ventilations d'une ecriture
  static Future<List<VentilationAnalytique>> getVentilations(
    int ecritureId,
  ) async {
    try {
      final results = await database.rawQuery(
        '''
        SELECT va.*, 
               p.designation AS projet_nom,
               b.designation AS bailleur_nom,
               pb.intitule AS poste_nom,
               lb.intitule AS ligne_nom
        FROM ventilations_analytiques va
        LEFT JOIN projet p ON va.id_projet = p.id
        LEFT JOIN bailleur b ON va.id_bailleur = b.id
        LEFT JOIN poste_budgetaire pb ON va.id_poste_budgetaire = pb.id
        LEFT JOIN ligne_budgetaire lb ON va.id_ligne_budgetaire = lb.id
        WHERE va.ecriture_id = ?
        ORDER BY va.id ASC
        ''',
        [ecritureId],
      );
      return results.map((r) => VentilationAnalytique.fromMap(r)).toList();
    } catch (e) {
      throw Exception('Erreur recuperation ventilations: $e');
    }
  }

  /// Supprimer les ventilations d'une ecriture
  static Future<int> deleteVentilations(int ecritureId) async {
    try {
      final deleted = await database.delete(
        'ventilations_analytiques',
        where: 'ecriture_id = ?',
        whereArgs: [ecritureId],
      );
      await database.update(
        'ecritures',
        {'is_ventilee': 0, 'updated_at': _nowIso()},
        where: 'id = ?',
        whereArgs: [ecritureId],
      );
      return deleted;
    } catch (e) {
      throw Exception('Erreur suppression ventilations: $e');
    }
  }

  /// Mettre a jour les totaux et nombre d'ecritures d'une periode
  static Future<void> updatePeriodeTotaux(
    int journalPeriodeId,
    List<LigneEcriture> ecritures,
  ) async {
    try {
      final totaux = calculateTotaux(ecritures);
      final nombreEcritures =
          ecritures.map((e) => e.numeroEnregistrement).toSet().length;

      await database.update(
        'journaux_periodes',
        {
          'total_debit': totaux.totalDebit,
          'total_credit': totaux.totalCredit,
          'solde_final': totaux.solde,
          'nombre_ecritures': nombreEcritures,
          'is_equilibre': totaux.isEquilibre ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [journalPeriodeId],
      );
    } catch (e) {
      throw Exception('Erreur mise a jour totaux: $e');
    }
  }

  /// Sauvegarder une ventilation analytique
  static Future<int> saveVentilation(VentilationAnalytique ventilation) async {
    try {
      final map = {
        'ecriture_id': ventilation.ligneEcritureId,
        'type': ventilation.type,
        'id_projet':
            ventilation.idProjet != null
                ? int.tryParse(ventilation.idProjet!)
                : null,
        'volet': ventilation.typeActivite,
        'id_bailleur':
            ventilation.idBailleur != null
                ? int.tryParse(ventilation.idBailleur!)
                : null,
        'id_poste_budgetaire':
            ventilation.postebudgetaire != null
                ? int.tryParse(ventilation.postebudgetaire!)
                : null,
        'id_ligne_budgetaire':
            ventilation.ligneBudgetaire != null
                ? int.tryParse(ventilation.ligneBudgetaire!)
                : null,
        'montant_ventile': ventilation.montantVentrle,
        'created_at': _nowIso(),
        'updated_at': _nowIso(),
      };
      final id = await database.insert('ventilations_analytiques', map);
      await database.update(
        'ecritures',
        {'is_ventilee': 1, 'updated_at': _nowIso()},
        where: 'id = ?',
        whereArgs: [ventilation.ligneEcritureId],
      );
      return id;
    } catch (e) {
      throw Exception('Erreur sauvegarde ventilation: $e');
    }
  }

  static String _generateLettrageCode(String numeroCompte) {
    final normalizedCompte = numeroCompte.replaceAll(
      RegExp(r'[^0-9A-Za-z]'),
      '',
    );
    final timestamp =
        DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    return 'LT-${normalizedCompte.isEmpty ? 'CPTE' : normalizedCompte}-$timestamp';
  }
}
