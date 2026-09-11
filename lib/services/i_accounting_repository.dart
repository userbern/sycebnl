import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Abstraction des opérations de données utilisées par SOFICOM sur le
/// dossier comptable actif (fichier `.syca`), indépendante du mécanisme
/// d'accès. Aujourd'hui, la seule implémentation est [LocalRepository]
/// (SQLite local via [DatabaseService]) ; une future implémentation réseau
/// pourra s'y substituer sans changer le code appelant.
///
/// Ne couvre volontairement que les opérations réellement utilisées par le
/// code métier de SOFICOM (query/rawQuery/insert/update/delete/transaction),
/// pas l'intégralité de l'API sqflite. L'ouverture, la fermeture et les
/// migrations du fichier `.syca` restent de la responsabilité de
/// `DatabaseService`, pas de ce repository.
abstract class IAccountingRepository {
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
  });

  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]);

  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
  });

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  });

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  });

  /// Exécute [action] dans une transaction. À l'intérieur de [action],
  /// utiliser exclusivement le repository transactionnel fourni en
  /// paramètre (pas l'instance englobante) pour que toutes les opérations
  /// participent à la même transaction.
  Future<T> transaction<T>(
    Future<T> Function(IAccountingRepository txn) action,
  );
}
