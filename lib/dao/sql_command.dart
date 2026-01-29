import 'package:flutter/foundation.dart';
import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/driver/my_odbc.dart';
import 'package:demo_odbc/dao/driver/database_driver.dart';
import 'package:demo_odbc/dao/config/database_type.dart';
import 'package:demo_odbc/dao/config/database_config.dart';
import 'package:demo_odbc/dao/driver/smart_prepared_statement.dart';
import 'package:demo_odbc/dao/sql_valid_command.dart';
import 'package:demo_odbc/dao/sql_type_command.dart';
import 'package:demo_odbc/dao/sql_transaction.dart';
import 'package:demo_odbc/dao/utils/schema_utils.dart';

class SqlCommand {
  final DatabaseDriver odbc;
  late final SchemaUtils schema;
  String? commandText;
  final List<SqlTypeCommand> _params = [];
  List<Map<String, dynamic>> _result = [];
  Map<String, dynamic> _currentRecord = {};

  int _currentIndex = -1;
  bool _isConnected = false;
  SqlTransaction? transaction;

  bool _useReadUncommitted = false;

  SqlCommand(DatabaseConfig config)
      : odbc = MyOdbc(
          driverName: config.driverName,
          username: config.username,
          password: config.password,
          database: config.database,
          server: config.server,
          port: config.port,
          databaseType: config.databaseType,
        ) {
    transaction = SqlTransaction(odbc);
    schema = SchemaUtils(odbc);
  }

  SqlTypeCommand param(String name) {
    final sqlType = SqlTypeCommand(name);
    _params.add(sqlType);
    return sqlType;
  }

  SqlTypeCommand field(String name) {
    final sqlType = SqlTypeCommand(name);

    if (!_currentRecord.containsKey(name)) {
      return sqlType;
    }

    final value = _currentRecord[name];
    if (value == null) {
      return sqlType;
    }

    if (value is DateTime) {
      sqlType.asDate = value;
    } else if (value is int) {
      sqlType.asInt = value;
    } else if (value is double) {
      sqlType.asDouble = value;
    } else if (value is bool) {
      sqlType.asBool = value;
    } else {
      sqlType.asString = value.toString();
    }

    return sqlType;
  }

  Future<Result<Stream<Map<String, dynamic>>>> stream() async {
    try {
      if (!_isConnected) {
        await odbc.connect().getOrThrow();
        _isConnected = true;
      }

      var query = commandText;
      if (query == null || query.isEmpty) {
        return Failure(Exception('CommandText não pode ser vazio.'));
      }

      if (_useReadUncommitted) {
        if (odbc.type == DatabaseType.sqlServer ||
            odbc.type == DatabaseType.sybaseAnywhere) {
          query = _addNoLock(query);
        }
      }

      final preparedResult = _substituteParameters(query);
      if (preparedResult.isError()) {
        return Failure(preparedResult.exceptionOrNull()!);
      }
      final prepared = preparedResult.getOrThrow();

      return await odbc.executeCursor(prepared.sql, params: prepared.params);
    } catch (e, s) {
      return Failure(Exception('Error opening stream: $e\nStack: $s'));
    }
  }

  Result<PreparedData> _substituteParameters(String query) {
    final paramMap = <String, dynamic>{};
    for (var p in _params) {
      if (p.value == null) {
        return Failure(
            Exception('Parâmetro :${p.name} não foi definido ou está nulo.'));
      }
      paramMap[p.name] = p.value;
    }

    try {
      final stmt = SmartPreparedStatement.prepare(query);
      return stmt.execute(paramMap);
    } catch (e) {
      return Failure(e is Exception ? e : Exception(e.toString()));
    }
  }

  void enableReadUncommitted() {
    _useReadUncommitted = true;
  }

  void disableReadUncommitted() {
    _useReadUncommitted = false;
  }

  String _addNoLock(String? query) {
    if (query == null) return '';
    if (!query.toUpperCase().contains('NOLOCK')) {
      return query;
    }
    return query;
  }

  String _getReadUncommittedCommand() {
    switch (odbc.type) {
      case DatabaseType.sqlServer:
      case DatabaseType.sybaseAnywhere:
        return 'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED';
      case DatabaseType.postgresql:
        return 'SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED';
    }
  }

  String _getReadCommittedCommand() {
    switch (odbc.type) {
      case DatabaseType.sqlServer:
      case DatabaseType.sybaseAnywhere:
        return 'SET TRANSACTION ISOLATION LEVEL READ COMMITTED';
      case DatabaseType.postgresql:
        return 'SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED';
    }
  }

  Future<Result<Unit>> open() async {
    try {
      SqlValidCommand.validateOpen(_isConnected, commandText);
    } catch (e) {
      return Failure(e is Exception ? e : Exception(e.toString()));
    }

    _currentIndex = -1;
    _currentRecord = {};

    final queryToProcess = commandText!;
    return _substituteParameters(queryToProcess).fold(
      (prepared) async {
        if (_useReadUncommitted) {
          await odbc.execute(_getReadUncommittedCommand());
        }

        final resultRows =
            await odbc.execute(prepared.sql, params: prepared.params);

        if (_useReadUncommitted) {
          await odbc.execute(_getReadCommittedCommand());
        }

        return resultRows.map((rows) {
          _result = rows;
          if (_result.isNotEmpty) {
            _currentIndex = 0;
            _currentRecord = Map<String, dynamic>.from(_result[_currentIndex]);
          }
          return unit;
        });
      },
      (error) async {
        if (_useReadUncommitted) {
          try {
            await odbc.execute(_getReadCommittedCommand());
          } catch (_) {}
        }
        return Failure(error);
      },
    );
  }

  bool get eof =>
      _result.isEmpty || _currentIndex < 0 || _currentIndex >= _result.length;

  bool get isEmpty => _result.isEmpty;

  int get recordCount => _result.length;

  void next() {
    if (_result.isEmpty) return;

    if (_currentIndex < _result.length - 1) {
      _currentIndex++;
      _currentRecord = Map<String, dynamic>.from(_result[_currentIndex]);
    } else {
      _currentIndex = _result.length;
    }
  }

  void first() {
    if (_result.isNotEmpty) {
      _currentIndex = 0;
      _currentRecord = Map<String, dynamic>.from(_result[_currentIndex]);
    }
  }

  Future<Result<Unit>> connect() async {
    final result = await odbc.connect();
    if (result case Success()) {
      _isConnected = true;
    } else {
      _isConnected = false;
    }
    return result;
  }

  Future<Result<Unit>> close() async {
    try {
      if (_isConnected) {
        final disconnectResult = await odbc.disconnect();
        if (disconnectResult.isError()) {
          final error = disconnectResult.exceptionOrNull();
          final errorMessage = error?.toString() ?? 'Unknown error';

          if (errorMessage.contains('already closed') ||
              errorMessage.contains('connection closed') ||
              errorMessage.contains('Lost connection')) {
            debugPrint('Warning: Connection was already closed. Continuing...');
          } else {
            debugPrint('Warning while disconnecting: $errorMessage');
          }
        }
      }
    } catch (e) {
      debugPrint(
          'Warning while closing connection (may already be closed): $e');
    } finally {
      _currentIndex = -1;
      _currentRecord = {};
      _isConnected = false;
      _result.clear();
      _params.clear();
    }

    return Success.unit();
  }

  void clearParams() {
    _params.clear();
  }

  Future<Result<int>> bulkInsert(
      String tableName, List<Map<String, dynamic>> rows,
      {int batchSize = 1000}) async {
    if (rows.isEmpty) return const Success(0);

    final columns = rows.first.keys.toList();
    final columnsStr = columns.join(', ');

    int totalAffected = 0;
    int batchCount = (rows.length / batchSize).ceil();

    debugPrint(
        'BulkInsert: Starting ${rows.length} records in $batchCount batches of $batchSize');

    for (var i = 0; i < rows.length; i += batchSize) {
      final end = (i + batchSize < rows.length) ? i + batchSize : rows.length;
      final batch = rows.sublist(i, end);

      debugPrint(
          'BulkInsert: Processing batch ${((i / batchSize) + 1).toInt()}/$batchCount (${batch.length} records)');

      final valuesBuffer = StringBuffer();

      for (var j = 0; j < batch.length; j++) {
        final row = batch[j];
        if (j > 0) valuesBuffer.write(', ');

        valuesBuffer.write('(');
        for (var k = 0; k < columns.length; k++) {
          if (k > 0) valuesBuffer.write(', ');
          final col = columns[k];
          final val = row[col];

          if (val == null) {
            valuesBuffer.write('NULL');
          } else if (val is num) {
            valuesBuffer.write(val.toString());
          } else if (val is bool) {
            valuesBuffer.write(val ? '1' : '0');
          } else if (val is DateTime) {
            // Format: YYYY-MM-DD HH:MM:SS.mmm (milliseconds only for SQL Server DATETIME)
            final year = val.year.toString().padLeft(4, '0');
            final month = val.month.toString().padLeft(2, '0');
            final day = val.day.toString().padLeft(2, '0');
            final hour = val.hour.toString().padLeft(2, '0');
            final minute = val.minute.toString().padLeft(2, '0');
            final second = val.second.toString().padLeft(2, '0');
            final ms = val.millisecond.toString().padLeft(3, '0');
            valuesBuffer.write("'$year-$month-$day $hour:$minute:$second.$ms'");
          } else {
            valuesBuffer.write("N'");
            valuesBuffer.write(val.toString().replaceAll("'", "''"));
            valuesBuffer.write("'");
          }
        }
        valuesBuffer.write(')');
      }

      final sql = 'INSERT INTO $tableName ($columnsStr) VALUES $valuesBuffer';

      debugPrint('BulkInsert: SQL length ${sql.length} characters');
      final result = await odbc.execute(sql);

      if (result.isSuccess()) {
        totalAffected += batch.length;
        debugPrint(
            'BulkInsert: Batch succeeded, total affected: $totalAffected');
      } else {
        final error = result.exceptionOrNull();
        debugPrint('BulkInsert error: $error');
        return Failure(error ?? Exception('Unknown error in Bulk Insert'));
      }
    }

    debugPrint('BulkInsert: Completed, total affected: $totalAffected');
    return Success(totalAffected);
  }

  Future<Result<Unit>> startTransaction() async {
    return await transaction?.start(isSelect: false) ?? Success.unit();
  }

  Future<Result<Unit>> commit() async {
    return await transaction?.commit() ?? Success.unit();
  }

  Future<Result<Unit>> rollback() async {
    return await transaction?.rollback() ?? Success.unit();
  }

  void onAutoCommit() {
    transaction?.onAutoCommit();
  }

  void offAutoCommit() {
    transaction?.offAutoCommit();
  }

  bool isTransactionOpen() {
    return transaction?.isOpen() ?? false;
  }

  Future<Result<Unit>> execute() async {
    try {
      SqlValidCommand.validateExecute(_isConnected, commandText);
    } catch (e) {
      return Failure(e is Exception ? e : Exception(e.toString()));
    }

    return _substituteParameters(commandText!).fold(
      (prepared) async {
        if (transaction != null &&
            !transaction!.autoCommit &&
            !transaction!.isOpen()) {
          final startResult = await transaction!.start(isSelect: false);
          if (startResult case Failure()) return startResult;
        }

        final execResult =
            await odbc.execute(prepared.sql, params: prepared.params);

        if (execResult case Failure()) {
          await transaction?.doAutoRollback();
          return execResult.map((_) => unit);
        }

        await transaction?.doAutoCommit();
        return Success.unit();
      },
      (error) => Future.value(Failure(error)),
    );
  }
}
