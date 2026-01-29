import 'dart:io';

import 'package:demo_odbc/dao/config/database_config.dart';
import 'package:demo_odbc/dao/config/database_type.dart';

/// Variáveis carregadas do .env (preenchido por [loadTestEnv]).
final Map<String, String> _testEnv = {};

/// Carrega variáveis do arquivo .env na raiz do projeto (para testes).
/// Chame uma vez em setUpAll antes de usar [TestDatabaseConfig.fromEnv].
void loadTestEnv() {
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    throw Exception(
      'Arquivo .env não encontrado. Copie .env.example para .env e preencha '
      'ODBC_DRIVER, ODBC_SERVER, ODBC_PORT, ODBC_DATABASE, ODBC_USERNAME, ODBC_PASSWORD.',
    );
  }
  final content = envFile.readAsStringSync();
  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf('=');
    if (idx <= 0) continue;
    final key = trimmed.substring(0, idx).trim();
    var value = trimmed.substring(idx + 1).trim();
    if (value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1).replaceAll(r'\"', '"');
    } else if (value.startsWith("'") && value.endsWith("'")) {
      value = value.substring(1, value.length - 1).replaceAll(r"\'", "'");
    }
    _testEnv[key] = value;
  }
}

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

  /// Cria configuração a partir do arquivo .env (variáveis ODBC_*).
  /// Chame [loadTestEnv] uma vez em setUpAll antes de usar.
  factory TestDatabaseConfig.fromEnv() {
    final driver = _testEnv['ODBC_DRIVER'] ?? '';
    final server = _testEnv['ODBC_SERVER'] ?? '';
    final port = int.tryParse(_testEnv['ODBC_PORT'] ?? '') ?? 1433;
    final database = _testEnv['ODBC_DATABASE'] ?? '';
    final username = _testEnv['ODBC_USERNAME'] ?? '';
    final password = _testEnv['ODBC_PASSWORD'] ?? '';
    return TestDatabaseConfig(
      driverName: driver,
      username: username,
      password: password,
      database: database,
      server: server,
      port: port,
      databaseType: DatabaseType.sqlServer,
    );
  }

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
