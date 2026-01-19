import 'package:demo_odbc/dao/config/database_config.dart';
import 'package:demo_odbc/dao/config/database_type.dart';

class TestDatabaseConfig {
  final String driverName;
  final String username;
  final String password;
  final String database;
  final String server;
  final int port;
  final DatabaseType databaseType;

  TestDatabaseConfig({
    required this.driverName,
    required this.username,
    required this.password,
    required this.database,
    required this.server,
    required this.port,
    DatabaseType? databaseType,
  }) : databaseType = databaseType ?? DatabaseType.sqlServer;

  factory TestDatabaseConfig.sqlServer({
    required String driverName,
    required String username,
    required String password,
    required String database,
    required String server,
    required int port,
  }) {
    return TestDatabaseConfig(
      driverName: driverName,
      username: username,
      password: password,
      database: database,
      server: server,
      port: port,
      databaseType: DatabaseType.sqlServer,
    );
  }

  factory TestDatabaseConfig.postgresql({
    required String driverName,
    required String username,
    required String password,
    required String database,
    required String server,
    required int port,
  }) {
    return TestDatabaseConfig(
      driverName: driverName,
      username: username,
      password: password,
      database: database,
      server: server,
      port: port,
      databaseType: DatabaseType.postgresql,
    );
  }

  factory TestDatabaseConfig.sybaseAnywhere({
    required String driverName,
    required String username,
    required String password,
    required String database,
    required String server,
    required int port,
  }) {
    return TestDatabaseConfig(
      driverName: driverName,
      username: username,
      password: password,
      database: database,
      server: server,
      port: port,
      databaseType: DatabaseType.sybaseAnywhere,
    );
  }

  DatabaseConfig toDatabaseConfig() {
    switch (databaseType) {
      case DatabaseType.sqlServer:
        return DatabaseConfig.sqlServer(
          driverName: driverName,
          username: username,
          password: password,
          database: database,
          server: server,
          port: port,
        );
      case DatabaseType.postgresql:
        return DatabaseConfig.postgresql(
          driverName: driverName,
          username: username,
          password: password,
          database: database,
          server: server,
          port: port,
        );
      case DatabaseType.sybaseAnywhere:
        return DatabaseConfig.sybaseAnywhere(
          driverName: driverName,
          username: username,
          password: password,
          database: database,
          server: server,
          port: port,
        );
    }
  }

  void validate() {
    if (driverName.isEmpty) {
      throw ArgumentError('driverName cannot be empty');
    }
    if (username.isEmpty) {
      throw ArgumentError('username cannot be empty');
    }
    if (database.isEmpty) {
      throw ArgumentError('database cannot be empty');
    }
    if (server.isEmpty) {
      throw ArgumentError('server cannot be empty');
    }
    if (port <= 0) {
      throw ArgumentError('port must be greater than 0');
    }
  }
}

class PerformanceTestConfig {
  final int recordCount;
  final int batchSize;
  final bool enableMetrics;

  PerformanceTestConfig({
    this.recordCount = 10000,
    this.batchSize = 1000,
    this.enableMetrics = true,
  }) {
    if (recordCount <= 0) {
      throw ArgumentError('recordCount must be greater than 0');
    }
    if (batchSize <= 0) {
      throw ArgumentError('batchSize must be greater than 0');
    }
  }
}
