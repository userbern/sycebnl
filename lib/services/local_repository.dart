import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_service.dart';
import 'i_accounting_repository.dart';

/// Implémentation locale de [IAccountingRepository] : délègue chaque
/// opération à la base SQLite actuellement ouverte par [DatabaseService].
/// Ne gère ni l'ouverture, ni la fermeture, ni les migrations du fichier
/// `.syca` — cela reste la responsabilité de [DatabaseService].
class LocalRepository implements IAccountingRepository {
  const LocalRepository();

  DatabaseExecutor get _executor => DatabaseService.database;

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
  }) {
    return _executor.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    return _executor.rawQuery(sql, arguments);
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _executor.insert(
      table,
      values,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _executor.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return _executor.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(IAccountingRepository txn) action,
  ) {
    return DatabaseService.database.transaction<T>((txn) {
      return action(_TransactionRepository(txn));
    });
  }
}

/// Repository lié à une [Transaction] sqflite en cours : toutes les
/// opérations exécutées à travers cette instance participent à la même
/// transaction que celle ouverte par [LocalRepository.transaction].
class _TransactionRepository implements IAccountingRepository {
  _TransactionRepository(this._txn);

  final Transaction _txn;

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
  }) {
    return _txn.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    return _txn.rawQuery(sql, arguments);
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _txn.insert(table, values, conflictAlgorithm: conflictAlgorithm);
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _txn.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return _txn.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(IAccountingRepository txn) action,
  ) {
    // sqflite ne supporte pas les transactions imbriquées : on réutilise la
    // transaction courante plutôt que d'en ouvrir une nouvelle.
    return action(this);
  }
}
