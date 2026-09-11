import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_service.dart';
import '../models/global_search_result.dart';
import '../models/saisie_comptable.dart';

/// Entrée statique de l'index des fonctionnalités/pages de l'application,
/// utilisée pour matcher des requêtes comme "grand livre" ou "balance".
class _FeatureEntry {
  final String label;
  final int pageIndex;
  final String keywords;

  const _FeatureEntry(this.label, this.pageIndex, this.keywords);
}

/// Recherche centralisée à travers les entités comptables existantes
/// (comptes, tiers, journaux, projets, bailleurs, écritures) et les pages
/// de l'application. Ne duplique aucune donnée : interroge directement les
/// tables déjà gérées par [DatabaseService].
class GlobalSearchService {
  static const int limitPerCategory = 6;

  static const List<_FeatureEntry> _features = [
    _FeatureEntry('Identification', 1, 'identification entite entité'),
    _FeatureEntry('Plan comptable', 4, 'plan comptable comptes'),
    _FeatureEntry('Liste des tiers', 5, 'tiers clients fournisseurs adherents adhérents'),
    _FeatureEntry('Codes journaux', 6, 'codes journaux journal'),
    _FeatureEntry('Liste des bailleurs', 7, 'bailleurs financeurs bailleur'),
    _FeatureEntry('Liste des projets', 8, 'projets projet'),
    _FeatureEntry('Gestion des budgets', 9, 'budgets budget'),
    _FeatureEntry('Saisie comptable', 10, 'saisie comptable ecriture écriture saisir'),
    _FeatureEntry('Journaux de saisie', 16, 'journaux de saisie periodes périodes'),
    _FeatureEntry('Interrogations & Lettrages', 11, 'interrogations lettrages lettrage'),
    _FeatureEntry('Exercices', 17, 'exercices exercice'),
    _FeatureEntry('Nouvel exercice', 12, 'nouvel exercice creation création'),
    _FeatureEntry('Balance des comptes', 13, 'balance generale des comptes balance générale'),
    _FeatureEntry('Grand livre', 14, 'grand livre'),
    _FeatureEntry('Journal', 15, 'journal edition impression édition'),
  ];

  static const List<GlobalSearchCategory> categoryOrder = [
    GlobalSearchCategory.compte,
    GlobalSearchCategory.tiers,
    GlobalSearchCategory.journal,
    GlobalSearchCategory.projet,
    GlobalSearchCategory.bailleur,
    GlobalSearchCategory.ecriture,
    GlobalSearchCategory.fonctionnalite,
  ];

  /// Recherche [query] dans toutes les catégories en parallèle et renvoie
  /// les résultats regroupés par catégorie. [exerciceId], si fourni, limite
  /// les écritures à l'exercice actif (comme le reste de l'application).
  static Future<Map<GlobalSearchCategory, List<GlobalSearchResult>>> search(
    String query, {
    int? exerciceId,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return {};

    final db = DatabaseService.database;
    final like = '%$q%';

    final rawResults = await Future.wait([
      db.query(
        'compte',
        where: '(numero_compte LIKE ? OR intitule LIKE ?) '
            'AND is_active = 1 AND deleted_at IS NULL',
        whereArgs: [like, like],
        orderBy: 'numero_compte ASC',
        limit: limitPerCategory,
      ),
      db.query(
        'tiers',
        where: '(numero_compte LIKE ? OR intitule LIKE ?) '
            'AND is_active = 1 AND deleted_at IS NULL',
        whereArgs: [like, like],
        orderBy: 'intitule ASC',
        limit: limitPerCategory,
      ),
      db.query(
        'journal',
        where: '(code LIKE ? OR libelle LIKE ?) '
            'AND is_active = 1 AND deleted_at IS NULL',
        whereArgs: [like, like],
        orderBy: 'code ASC',
        limit: limitPerCategory,
      ),
      db.query(
        'projet',
        where: '(code LIKE ? OR designation LIKE ?) AND deleted_at IS NULL',
        whereArgs: [like, like],
        orderBy: 'code ASC',
        limit: limitPerCategory,
      ),
      db.query(
        'bailleur',
        where: '(sigle LIKE ? OR designation LIKE ?) AND deleted_at IS NULL',
        whereArgs: [like, like],
        orderBy: 'sigle ASC',
        limit: limitPerCategory,
      ),
      _searchEcritures(db, like, exerciceId),
    ]);

    final comptes = rawResults[0];
    final tiers = rawResults[1];
    final journaux = rawResults[2];
    final projets = rawResults[3];
    final bailleurs = rawResults[4];
    final ecritures = rawResults[5];

    final map = <GlobalSearchCategory, List<GlobalSearchResult>>{};

    if (comptes.isNotEmpty) {
      map[GlobalSearchCategory.compte] =
          comptes.map((c) {
            return GlobalSearchResult(
              category: GlobalSearchCategory.compte,
              title: '${c['numero_compte']} — ${c['intitule']}',
              pageIndex: 4,
            );
          }).toList();
    }

    if (tiers.isNotEmpty) {
      map[GlobalSearchCategory.tiers] =
          tiers.map((t) {
            return GlobalSearchResult(
              category: GlobalSearchCategory.tiers,
              title: '${t['numero_compte']} — ${t['intitule']}',
              pageIndex: 5,
            );
          }).toList();
    }

    if (journaux.isNotEmpty) {
      map[GlobalSearchCategory.journal] =
          journaux.map((j) {
            return GlobalSearchResult(
              category: GlobalSearchCategory.journal,
              title: '${j['code']} — ${j['libelle']}',
              pageIndex: 6,
            );
          }).toList();
    }

    if (projets.isNotEmpty) {
      map[GlobalSearchCategory.projet] =
          projets.map((p) {
            return GlobalSearchResult(
              category: GlobalSearchCategory.projet,
              title: '${p['code']} — ${p['designation']}',
              pageIndex: 8,
            );
          }).toList();
    }

    if (bailleurs.isNotEmpty) {
      map[GlobalSearchCategory.bailleur] =
          bailleurs.map((b) {
            return GlobalSearchResult(
              category: GlobalSearchCategory.bailleur,
              title: '${b['sigle']} — ${b['designation']}',
              pageIndex: 7,
            );
          }).toList();
    }

    if (ecritures.isNotEmpty) {
      map[GlobalSearchCategory.ecriture] =
          ecritures.map((e) {
            return GlobalSearchResult(
              category: GlobalSearchCategory.ecriture,
              title: '${e['numero_document']} — ${e['libelle']}',
              subtitle:
                  'Compte ${e['numero_compte']} · Journal ${e['code_journal']}',
              journalPeriode: JournalPeriode.fromMap(e),
            );
          }).toList();
    }

    final qLower = q.toLowerCase();
    final featureMatches =
        _features
            .where(
              (f) =>
                  f.label.toLowerCase().contains(qLower) ||
                  f.keywords.contains(qLower),
            )
            .take(limitPerCategory)
            .map(
              (f) => GlobalSearchResult(
                category: GlobalSearchCategory.fonctionnalite,
                title: f.label,
                pageIndex: f.pageIndex,
              ),
            )
            .toList();
    if (featureMatches.isNotEmpty) {
      map[GlobalSearchCategory.fonctionnalite] = featureMatches;
    }

    return map;
  }

  /// Recherche ciblée dans les écritures comptables (jointure avec la
  /// période de journal pour permettre l'ouverture directe en saisie).
  static Future<List<Map<String, dynamic>>> _searchEcritures(
    Database db,
    String like,
    int? exerciceId,
  ) async {
    final where = StringBuffer(
      'e.deleted_at IS NULL AND '
      '(e.numero_document LIKE ? OR e.libelle LIKE ? OR e.numero_compte LIKE ?)',
    );
    final args = <dynamic>[like, like, like];
    if (exerciceId != null) {
      where.write(' AND jp.exercice_id = ?');
      args.add(exerciceId);
    }
    args.add(limitPerCategory);

    return db.rawQuery('''
      SELECT
        jp.id AS id,
        jp.code_journal,
        jp.annee,
        jp.mois,
        jp.exercice_id,
        jp.nombre_ecritures,
        jp.is_closed,
        jp.is_equilibre,
        jp.created_at,
        jp.updated_at,
        e.numero_document,
        e.libelle,
        e.numero_compte
      FROM ecritures e
      JOIN journaux_periodes jp ON e.journal_periode_id = jp.id
      WHERE $where
      ORDER BY e.created_at DESC
      LIMIT ?
    ''', args);
  }
}
