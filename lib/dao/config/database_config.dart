import 'package:demo_odbc/dao/config/database_type.dart';

class DatabaseConfig {
  final String driverName;
  final String username;
  final String password;
  final String database;
  final String server;
  final int port;
  final DatabaseType databaseType;

  /// Maximum result buffer size in bytes (odbc_fast 0.3.0+). When null, package default (16 MB) is used.
  final int? maxResultBufferBytes;

  DatabaseConfig({
    required this.driverName,
    required this.username,
    required this.password,
    required this.database,
    required this.server,
    required this.port,
    DatabaseType? databaseType,
    this.maxResultBufferBytes,
  }) : databaseType = databaseType ?? DatabaseType.sqlServer;

  factory DatabaseConfig.sqlServer({
    required String driverName,
    required String username,
    required String password,
    required String database,
    required String server,
    required int port,
    int? maxResultBufferBytes,
  }) {
    return DatabaseConfig(
      driverName: driverName,
      username: username,
      password: password,
      database: database,
      server: server,
      port: port,
      databaseType: DatabaseType.sqlServer,
      maxResultBufferBytes: maxResultBufferBytes,
    );
  }

  factory DatabaseConfig.sybaseAnywhere({
    required String driverName,
    required String username,
    required String password,
    required String database,
    required String server,
    required int port,
    int? maxResultBufferBytes,
  }) {
    return DatabaseConfig(
      driverName: driverName,
      username: username,
      password: password,
      database: database,
      server: server,
      port: port,
      databaseType: DatabaseType.sybaseAnywhere,
      maxResultBufferBytes: maxResultBufferBytes,
    );
  }

  factory DatabaseConfig.postgresql({
    required String driverName,
    required String username,
    required String password,
    required String database,
    required String server,
    required int port,
    int? maxResultBufferBytes,
  }) {
    return DatabaseConfig(
      driverName: driverName,
      username: username,
      password: password,
      database: database,
      server: server,
      port: port,
      databaseType: DatabaseType.postgresql,
      maxResultBufferBytes: maxResultBufferBytes,
    );
  }
}
