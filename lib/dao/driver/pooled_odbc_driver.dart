import 'package:odbc_fast/odbc_fast.dart' as odbc;
import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/config/database_type.dart';
import 'package:demo_odbc/dao/driver/database_driver.dart';
import 'package:demo_odbc/dao/driver/database_error.dart';

/// Implementação de [DatabaseDriver] que usa uma conexão obtida do pool nativo odbc_fast.
///
/// [connect] é no-op (a conexão já vem do pool). [disconnect] devolve a conexão
/// ao pool via [odbc.OdbcService.poolReleaseConnection].
class PooledOdbcDriver implements DatabaseDriver {
  PooledOdbcDriver({
    required this.connectionId,
    required this.service,
    required this.poolId,
    required this.databaseType,
  });

  final String connectionId;
  final odbc.OdbcService service;
  final int poolId;
  final DatabaseType databaseType;

  int? _currentTxnId;

  static List<Map<String, dynamic>> _queryResultToRows(odbc.QueryResult qr) {
    final cols = qr.columns;
    return qr.rows
        .map((row) => {
              for (var i = 0; i < cols.length; i++)
                cols[i]: (i < row.length ? row[i] : null)
            })
        .toList();
  }

  static DatabaseError _mapOdbcError(odbc.OdbcError e, [String? query]) {
    if (e is odbc.ConnectionError) {
      return ConnectionError(e.message, e, StackTrace.current);
    }
    if (e is odbc.QueryError) {
      return QueryError(
        e.message,
        query: query,
        originalError: e,
        stackTrace: StackTrace.current,
      );
    }
    return QueryError(
      e.message,
      query: query,
      originalError: e,
      stackTrace: StackTrace.current,
    );
  }

  @override
  DatabaseType get type => databaseType;

  @override
  Future<Result<Unit>> connect() async {
    return const Success(unit);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> execute(String query,
      {List<dynamic>? params}) async {
    try {
      final paramsList = params ?? [];
      final result =
          await service.executeQueryParams(connectionId, query, paramsList);

      return result.fold(
        (qr) => Success(_queryResultToRows(qr)),
        (e) {
          if (e is odbc.OdbcError) {
            return Failure(_mapOdbcError(e, query));
          }
          return Failure(QueryError(
            'Falha ao executar query',
            query: query,
            originalError: e,
            stackTrace: StackTrace.current,
          ));
        },
      );
    } catch (err, stackTrace) {
      return Failure(QueryError(
        'Falha ao executar query',
        query: query,
        originalError: err,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<Stream<Map<String, dynamic>>>> executeCursor(String query,
      {List<dynamic>? params}) async {
    try {
      final paramsList = params ?? [];
      final result =
          await service.executeQueryParams(connectionId, query, paramsList);

      return result.fold(
        (qr) {
          final rows = _queryResultToRows(qr);
          return Success(Stream.fromIterable(rows));
        },
        (e) {
          if (e is odbc.OdbcError) {
            return Failure(_mapOdbcError(e, query));
          }
          return Failure(QueryError(
            'Falha ao executar cursor (stream)',
            query: query,
            originalError: e,
            stackTrace: StackTrace.current,
          ));
        },
      );
    } catch (err, stackTrace) {
      return Failure(QueryError(
        'Falha ao executar cursor (stream)',
        query: query,
        originalError: err,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<Unit>> disconnect() async {
    try {
      final result = await service.poolReleaseConnection(connectionId);
      _currentTxnId = null;
      return result.fold(
        (_) => const Success(unit),
        (e) {
          if (e is odbc.OdbcError) {
            final msg = e.message.toLowerCase();
            if (msg.contains('already closed') ||
                msg.contains('connection closed') ||
                msg.contains('lost connection') ||
                msg.contains('not connected') ||
                msg.contains('invalid connection')) {
              return const Success(unit);
            }
            return Failure(_mapOdbcError(e));
          }
          return Failure(ConnectionError(
            'Falha ao devolver conexão ao pool',
            e,
            StackTrace.current,
          ));
        },
      );
    } catch (err, stackTrace) {
      final errorMessage = err.toString().toLowerCase();
      if (errorMessage.contains('already closed') ||
          errorMessage.contains('connection closed') ||
          errorMessage.contains('lost connection') ||
          errorMessage.contains('not connected')) {
        _currentTxnId = null;
        return const Success(unit);
      }
      return Failure(ConnectionError(
        'Falha ao devolver conexão ao pool',
        err,
        stackTrace,
      ));
    }
  }

  @override
  Future<Result<Unit>> startTransaction() async {
    try {
      final result = await service.beginTransaction(
        connectionId,
        odbc.IsolationLevel.readCommitted,
      );
      return result.fold(
        (txnId) {
          _currentTxnId = txnId;
          return const Success(unit);
        },
        (e) {
          if (e is odbc.OdbcError) {
            return Failure(TransactionError(
              e.message,
              e,
              StackTrace.current,
            ));
          }
          return Failure(TransactionError(
            'Falha ao iniciar transação',
            e,
            StackTrace.current,
          ));
        },
      );
    } catch (err, stackTrace) {
      return Failure(TransactionError(
        'Falha ao iniciar transação',
        err,
        stackTrace,
      ));
    }
  }

  @override
  Future<Result<Unit>> commitTransaction() async {
    final txnId = _currentTxnId;
    if (txnId == null) {
      return Failure(TransactionError(
        'Nenhuma transação ativa para commit.',
        null,
        StackTrace.current,
      ));
    }
    try {
      final result = await service.commitTransaction(connectionId, txnId);
      _currentTxnId = null;
      return result.fold(
        (_) => const Success(unit),
        (e) {
          if (e is odbc.OdbcError) {
            return Failure(TransactionError(
              e.message,
              e,
              StackTrace.current,
            ));
          }
          return Failure(TransactionError(
            'Falha ao realizar commit',
            e,
            StackTrace.current,
          ));
        },
      );
    } catch (err, stackTrace) {
      _currentTxnId = null;
      return Failure(TransactionError(
        'Falha ao realizar commit',
        err,
        stackTrace,
      ));
    }
  }

  @override
  Future<Result<Unit>> rollbackTransaction() async {
    final txnId = _currentTxnId;
    if (txnId == null) {
      return Failure(TransactionError(
        'Nenhuma transação ativa para rollback.',
        null,
        StackTrace.current,
      ));
    }
    try {
      final result = await service.rollbackTransaction(connectionId, txnId);
      _currentTxnId = null;
      return result.fold(
        (_) => const Success(unit),
        (e) {
          if (e is odbc.OdbcError) {
            return Failure(TransactionError(
              e.message,
              e,
              StackTrace.current,
            ));
          }
          return Failure(TransactionError(
            'Falha ao realizar rollback',
            e,
            StackTrace.current,
          ));
        },
      );
    } catch (err, stackTrace) {
      _currentTxnId = null;
      return Failure(TransactionError(
        'Falha ao realizar rollback',
        err,
        stackTrace,
      ));
    }
  }
}
