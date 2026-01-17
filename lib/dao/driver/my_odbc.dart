import 'package:dart_odbc/dart_odbc.dart';
import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/config/database_type.dart';
import 'package:demo_odbc/dao/driver/database_driver.dart';
import 'package:demo_odbc/dao/driver/database_error.dart';

class MyOdbc implements DatabaseDriver {
  late final DartOdbc driver;
  final String driverName;
  final String username;
  final String password;
  final String database;
  final String server;
  final int port;
  final DatabaseType databaseType;

  MyOdbc({
    required this.driverName,
    required this.username,
    required this.password,
    required this.database,
    required this.server,
    required this.port,
    DatabaseType? databaseType,
  }) : databaseType = databaseType ?? DatabaseType.sqlServer {
    driver = DartOdbc();
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
      Packet Size = 4096;
      TrustServerCertificate = yes;
      Encrypt = false;
      Connection Timeout = 30;
      ReadOnly = 0;
    ''';

      case DatabaseType.sybaseAnywhere:
        return '''
      DRIVER={$driverName};
      ServerName=$server;
      Port=$port;
      DatabaseName=$database;
      UID=$username;
      PWD=$password;
      Connection Timeout = 30;
    ''';

      case DatabaseType.postgresql:
        return '''
      DRIVER={$driverName};
      Server=$server;
      Port=$port;
      Database=$database;
      UID=$username;
      PWD=$password;
      Connection Timeout = 30;
    ''';
    }
  }

  @override
  DatabaseType get type => databaseType;

  @override
  Future<Result<Unit>> connect() async {
    try {
      await driver.connectWithConnectionString(getConnectionString());
      return Success.unit();
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
    try {
      final result = await driver.execute(
        query,
        params: params,
      );
      return Success(result.toList());
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
      final cursor = await driver.executeCursor(query, params: params);

      final stream = () async* {
        try {
          while (true) {
            final row = await cursor.next();
            if (row is CursorDone) {
              break;
            }

            yield row as Map<String, dynamic>;
          }
        } finally {
          await cursor.close();
        }
      }();

      return Success(stream);
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
      await driver.disconnect();
      return Success.unit();
    } catch (err, stackTrace) {
      return Failure(ConnectionError(
        'Falha ao desconectar do banco de dados',
        err,
        stackTrace,
      ));
    }
  }

  @override
  Future<Result<Unit>> startTransaction() async {
    try {
      String transactionCommand;
      switch (databaseType) {
        case DatabaseType.sqlServer:
        case DatabaseType.sybaseAnywhere:
          transactionCommand = 'BEGIN TRANSACTION';
          break;
        case DatabaseType.postgresql:
          transactionCommand = 'BEGIN';
          break;
      }
      await driver.execute(transactionCommand);
      return Success.unit();
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
    try {
      await driver.execute('COMMIT');
      return Success.unit();
    } catch (err, stackTrace) {
      return Failure(TransactionError(
        'Falha ao realizar commit',
        err,
        stackTrace,
      ));
    }
  }

  @override
  Future<Result<Unit>> rollbackTransaction() async {
    try {
      await driver.execute('ROLLBACK');
      return Success.unit();
    } catch (err, stackTrace) {
      return Failure(TransactionError(
        'Falha ao realizar rollback',
        err,
        stackTrace,
      ));
    }
  }
}
