import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../i_accounting_repository.dart';
import 'network_client.dart';

/// Implémentation réseau de [IAccountingRepository] : traduit les opérations
/// génériques (query/insert/update/delete) en appels REST vers les
/// endpoints déjà exposés par le serveur (`network_routes.dart`).
///
/// Portée volontairement limitée : le serveur n'expose que les ressources
/// `compte`, `tiers`, `journal` (CRUD complet) et `exercice` (lecture seule).
/// Toute autre table, ou toute requête SQL brute ([rawQuery]), lève
/// [UnsupportedError] : les pages qui en dépendent (saisie/lettrage, budgets,
/// permissions, utilisateurs, ...) ne sont pas encore disponibles en mode
/// réseau et ne doivent pas être proposées à l'utilisateur connecté à
/// distance (voir `home_page.dart`, `_isNetworkMode`, qui bloque déjà la
/// navigation vers ces pages).
///
/// Avant de brancher les écritures (`/ecritures/<journalPeriodeId>` existe
/// déjà côté serveur, voir `network_routes.dart`), deux prérequis
/// d'architecture, pas seulement d'implémentation :
/// 1. [query] ici suppose une ressource "liste plate" (GET sans paramètre) ;
///    la route écritures est paramétrée par période de journal, donc ce
///    modèle `_listPaths` (chemin fixe par table) ne suffit pas tel quel.
/// 2. [transaction] n'est pas atomique côté réseau (chaque opération est un
///    appel HTTP indépendant) : acceptable pour des écritures unitaires sur
///    compte/tiers/journal, mais une écriture en partie double (plusieurs
///    lignes débit/crédit) ne doit pas pouvoir être enregistrée à moitié.
///    Il faut un endpoint serveur qui applique l'écriture complète comme une
///    seule opération atomique avant d'activer la saisie réseau.
class RemoteRepository implements IAccountingRepository {
  RemoteRepository(this._client);

  final NetworkClient _client;

  static const Map<String, String> _listPaths = {
    'compte': '/comptes',
    'tiers': '/tiers',
    'journal': '/journaux',
    'exercice': '/exercices',
  };

  static const Set<String> _writableTables = {'compte', 'tiers', 'journal'};

  String _requireListPath(String table) {
    final path = _listPaths[table];
    if (path == null) {
      throw UnsupportedError(
        'Table "$table" non disponible en mode réseau : le '
        'serveur n\'expose pas encore cette ressource.',
      );
    }
    return path;
  }

  void _requireWritable(String table) {
    if (!_writableTables.contains(table)) {
      throw UnsupportedError(
        'Écriture sur "$table" non disponible en mode réseau.',
      );
    }
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final rows = await _client.getList(_requireListPath(table));
    var filtered = rows.where((row) => _matchesWhere(row, where, whereArgs)).toList();

    if (orderBy != null) filtered = _applyOrderBy(filtered, orderBy);
    if (offset != null) {
      filtered = filtered.length > offset ? filtered.sublist(offset) : [];
    }
    if (limit != null && filtered.length > limit) {
      filtered = filtered.sublist(0, limit);
    }
    if (columns != null) {
      filtered = filtered
          .map((row) => {for (final c in columns) c: row[c]})
          .toList();
    }
    return filtered;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    throw UnsupportedError(
      'Requêtes SQL brutes non disponibles en mode réseau.',
    );
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    _requireWritable(table);
    await _client.postJson(_requireListPath(table), values);
    // Le serveur ne renvoie pas d'id pour ces ressources (comptes/tiers/
    // journaux) : les appelants existants (AuthService.createXxx) sont tous
    // `Future<void>` et ignorent la valeur de retour.
    return 0;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    _requireWritable(table);
    final id = _requireIdFromWhere(where, whereArgs);
    final listPath = _requireListPath(table);

    // Le code métier local exprime la suppression comme un update posant
    // `deleted_at` (soft delete) : le serveur, lui, expose une vraie route
    // DELETE qui applique les mêmes règles de gestion (vérifie les
    // dépendances, ...). On route donc ce cas vers DELETE plutôt que PUT,
    // qui ignorerait silencieusement `deleted_at`.
    if (values.containsKey('deleted_at') && values['deleted_at'] != null) {
      await _client.deleteJson('$listPath/$id');
    } else {
      await _client.putJson('$listPath/$id', values);
    }
    return 1;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    _requireWritable(table);
    final id = _requireIdFromWhere(where, whereArgs);
    await _client.deleteJson('${_requireListPath(table)}/$id');
    return 1;
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(IAccountingRepository txn) action,
  ) {
    // Pas de transaction atomique côté réseau (chaque opération est une
    // requête HTTP indépendante) : on exécute simplement les opérations à la
    // suite. Acceptable pour la portée actuelle, qui ne couvre que
    // des écritures unitaires sur compte/tiers/journal.
    return action(this);
  }

  Object? _requireIdFromWhere(String? where, List<Object?>? whereArgs) {
    if (where == 'id = ?' && whereArgs != null && whereArgs.length == 1) {
      return whereArgs.first;
    }
    throw UnsupportedError(
      'Condition de mise à jour non supportée en mode réseau : "$where"',
    );
  }

  /// Filtre minimal émulant les clauses `WHERE` réellement utilisées par les
  /// services métier contre ces tables (égalité simple, IS [NOT] NULL,
  /// combinées par AND). Toute clause non reconnue est ignorée sans erreur
  /// (comportement permissif : le serveur a déjà appliqué le filtrage
  /// pertinent pour les listes, ex. comptes actifs non supprimés).
  bool _matchesWhere(
    Map<String, Object?> row,
    String? where,
    List<Object?>? whereArgs,
  ) {
    if (where == null) return true;
    var argIndex = 0;
    for (final rawClause in where.split(' AND ')) {
      final clause = rawClause.trim();
      final placeholderMatch = RegExp(r'^(\w+)\s*=\s*\?$').firstMatch(clause);
      if (placeholderMatch != null) {
        final value = whereArgs != null && argIndex < whereArgs.length
            ? whereArgs[argIndex++]
            : null;
        if (!_looseEquals(row[placeholderMatch.group(1)], value)) return false;
        continue;
      }

      final literalMatch =
          RegExp(r'^(\w+)\s*=\s*(\S+)$').firstMatch(clause);
      if (literalMatch != null) {
        final literal = literalMatch.group(2)!;
        final parsed = int.tryParse(literal) ?? literal;
        if (!_looseEquals(row[literalMatch.group(1)], parsed)) return false;
        continue;
      }

      final notNullMatch =
          RegExp(r'^(\w+)\s+IS\s+NOT\s+NULL$').firstMatch(clause);
      if (notNullMatch != null) {
        if (row[notNullMatch.group(1)] == null) return false;
        continue;
      }

      final nullMatch = RegExp(r'^(\w+)\s+IS\s+NULL$').firstMatch(clause);
      if (nullMatch != null) {
        if (row[nullMatch.group(1)] != null) return false;
        continue;
      }
      // Clause non reconnue : ignorée (voir doc de la méthode).
    }
    return true;
  }

  bool _looseEquals(Object? a, Object? b) {
    if (a == b) return true;
    // Le JSON renvoie des bool pour certains flags quand la valeur SQLite
    // 0/1 a été convertie côté modèle serveur ; on tolère les deux formes.
    if (a is bool) return a == (b == 1 || b == true);
    if (b is bool) return b == (a == 1 || a == true);
    return a.toString() == b.toString();
  }

  List<Map<String, Object?>> _applyOrderBy(
    List<Map<String, Object?>> rows,
    String orderBy,
  ) {
    final clauses = orderBy.split(',').map((c) => c.trim()).toList();
    final sorted = [...rows];
    sorted.sort((a, b) {
      for (final clause in clauses) {
        final parts = clause.split(RegExp(r'\s+'));
        final column = parts.first;
        final descending = parts.length > 1 && parts[1].toUpperCase() == 'DESC';
        final va = a[column];
        final vb = b[column];
        final cmp = _compare(va, vb);
        if (cmp != 0) return descending ? -cmp : cmp;
      }
      return 0;
    });
    return sorted;
  }

  int _compare(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is num && b is num) return a.compareTo(b);
    return a.toString().compareTo(b.toString());
  }
}
