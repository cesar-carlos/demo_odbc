import 'dart:async';
import 'dart:collection';
import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/config/database_config.dart';
import 'package:demo_odbc/dao/driver/database_driver.dart';
import 'package:demo_odbc/dao/driver/my_odbc.dart';

class OdbcConnectionPool {
  static final OdbcConnectionPool _instance = OdbcConnectionPool._internal();
  factory OdbcConnectionPool() => _instance;

  OdbcConnectionPool._internal();

  final Queue<DatabaseDriver> _available = Queue<DatabaseDriver>();
  final List<DatabaseDriver> _inUse = [];

  DatabaseConfig? _config;
  int _maxSize = 10;

  void init(DatabaseConfig config, {int maxSize = 10}) {
    _config = config;
    _maxSize = maxSize;
  }

  Future<Result<DatabaseDriver>> acquire() async {
    if (_config == null) {
      return Failure(
          Exception('Pool não inicializado. Chame init() primeiro.'));
    }

    if (_available.isNotEmpty) {
      final driver = _available.removeFirst();
      _inUse.add(driver);

      return Success(driver);
    }

    if (_inUse.length < _maxSize) {
      final newDriver = MyOdbc(
        driverName: _config!.driverName,
        server: _config!.server,
        database: _config!.database,
        username: _config!.username,
        password: _config!.password,
        port: _config!.port,
        databaseType: _config!.databaseType,
        maxResultBufferBytes: _config!.maxResultBufferBytes,
      );

      final connectResult = await newDriver.connect();
      if (connectResult.isError()) {
        return Failure(connectResult.exceptionOrNull() ??
            Exception('Failed to create connection in pool'));
      }

      _inUse.add(newDriver);
      return Success(newDriver);
    }

    return Failure(Exception(
        'Pool de conexões esgotado (Max: $_maxSize). Tente novamente mais tarde.'));
  }

  void release(DatabaseDriver driver) {
    if (_inUse.remove(driver)) {
      _available.add(driver);
    } else {}
  }

  Future<void> closeAll() async {
    for (var driver in _available) {
      await driver.disconnect();
    }
    for (var driver in _inUse) {
      await driver.disconnect();
    }
    _available.clear();
    _inUse.clear();
  }
}
