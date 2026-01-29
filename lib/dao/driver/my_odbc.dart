import 'package:odbc_fast/odbc_fast.dart' as odbc;
import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/config/database_type.dart';
import 'package:demo_odbc/dao/driver/database_driver.dart';
import 'package:demo_odbc/dao/driver/database_error.dart';

/// Implementação de [DatabaseDriver] usando odbc_fast (async).
///
/// Para Flutter, o ServiceLocator é inicializado com useAsync: true para
/// manter a UI responsiva. Chame [OdbcConnectionPool] ou use [SqlCommand]
/// normalmente; a primeira conexão inicializa o locator.
class MyOdbc implements DatabaseDriver {
  static bool _locatorInitialized = false;

  final String driverName;
  final String username;
  final String password;
  final String database;
  final String server;
  final int port;
  final DatabaseType databaseType;

  /// Maximum result buffer size in bytes (odbc_fast 0.3.0+).
  /// When null, package default (16 MB) is used. Set e.g. 64*1024*1024 for large result sets.
  final int? maxResultBufferBytes;

  String? _connectionId;
  int? _currentTxnId;

  MyOdbc({
    required this.driverName,
    required this.username,
    required this.password,
    required this.database,
    required this.server,
    required this.port,
    DatabaseType? databaseType,
    this.maxResultBufferBytes,
  }) : databaseType = databaseType ?? DatabaseType.sqlServer;

  odbc.OdbcService get _service {
    if (!_locatorInitialized) {
      odbc.ServiceLocator().initialize(useAsync: true);
      _locatorInitialized = true;
    }
    return odbc.ServiceLocator().asyncService;
  }

  String getConnectionString() {
    switch (databaseType) {
      case DatabaseType.sqlServer:
        return '''
      DRIVER={$driverName};
      Server=$server;
      Port=$port;
      Database=$database;
      UID=$username;
      PWD=$password;
      Trusted_connection = yes;
      MARS_Connection = yes;
      MultipleActiveResultSets = true;
      Packet Size = 16384;
      TrustServerCertificate = yes;
      Encrypt = false;
      Connection Timeout = 30;
      ReadOnly = 0;
    '''
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

      case DatabaseType.sybaseAnywhere:
        return '''
      DRIVER={$driverName};
      ServerName=$server;
      Port=$port;
      DatabaseName=$database;
      UID=$username;
      PWD=$password;
      Connection Timeout = 30;
    '''
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

      case DatabaseType.postgresql:
        return '''
      DRIVER={$driverName};
      Server=$server;
      Port=$port;
      Database=$database;
      UID=$username;
      PWD=$password;
      Connection Timeout = 30;
    '''
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    }
  }

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
    try {
      await _service.initialize();
      final options = maxResultBufferBytes != null
          ? odbc.ConnectionOptions(maxResultBufferBytes: maxResultBufferBytes)
          : null;
      final connResult = await _service.connect(
        getConnectionString(),
        options: options,
      );
      return connResult.fold(
        (connection) {
          _connectionId = connection.id;
          return const Success(unit);
        },
        (e) {
          if (e is odbc.OdbcError) {
            return Failure(_mapOdbcError(e));
          }
          return Failure(ConnectionError(
            'Falha ao conectar ao banco de dados',
            e,
            StackTrace.current,
          ));
        },
      );
    } catch (err, stackTrace) {
      return Failure(ConnectionError(
        'Falha ao conectar ao banco de dados',
        err,
        stackTrace,
      ));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> execute(String query,
      {List<dynamic>? params}) async {
    final cid = _connectionId;
    if (cid == null) {
      return Failure(ConnectionError(
        'Não conectado. Chame connect() antes de execute.',
        null,
        StackTrace.current,
      ));
    }
    try {
      final paramsList = params ?? [];
      final result = await _service.executeQueryParams(cid, query, paramsList);

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
    final cid = _connectionId;
    if (cid == null) {
      return Failure(ConnectionError(
        'Não conectado. Chame connect() antes de executeCursor.',
        null,
        StackTrace.current,
      ));
    }
    try {
      final paramsList = params ?? [];
      final result = await _service.executeQueryParams(cid, query, paramsList);

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
    final cid = _connectionId;
    if (cid == null) {
      return const Success(unit);
    }
    try {
      final result = await _service.disconnect(cid);
      _connectionId = null;
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
            'Falha ao desconectar do banco de dados',
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
        _connectionId = null;
        _currentTxnId = null;
        return const Success(unit);
      }
      return Failure(ConnectionError(
        'Falha ao desconectar do banco de dados',
        err,
        stackTrace,
      ));
    }
  }

  @override
  Future<Result<Unit>> startTransaction() async {
    final cid = _connectionId;
    if (cid == null) {
      return Failure(ConnectionError(
        'Não conectado. Chame connect() antes de startTransaction.',
        null,
        StackTrace.current,
      ));
    }
    try {
      final result = await _service.beginTransaction(
        cid,
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
    final cid = _connectionId;
    final txnId = _currentTxnId;
    if (cid == null || txnId == null) {
      return Failure(TransactionError(
        'Nenhuma transação ativa para commit.',
        null,
        StackTrace.current,
      ));
    }
    try {
      final result = await _service.commitTransaction(cid, txnId);
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
    final cid = _connectionId;
    final txnId = _currentTxnId;
    if (cid == null || txnId == null) {
      return Failure(TransactionError(
        'Nenhuma transação ativa para rollback.',
        null,
        StackTrace.current,
      ));
    }
    try {
      final result = await _service.rollbackTransaction(cid, txnId);
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
