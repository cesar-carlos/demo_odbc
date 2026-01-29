import 'package:flutter_test/flutter_test.dart';

import 'package:demo_odbc/dao/driver/my_odbc.dart';
import 'package:odbc_fast/odbc_fast.dart' as odbc;

import 'test_config.dart';

/// E2E test using the **synchronous** ODBC API (no worker isolate).
///
/// If this test passes and the async E2E tests fail with "No error", the issue
/// is likely async/isolate-specific (e.g. connectionId or state in the worker).
void main() {
  late String connectionString;

  setUpAll(() {
    loadTestEnv();
    final testConfig = TestDatabaseConfig.fromEnv();
    testConfig.validate();
    final config = testConfig.toDatabaseConfig();
    final myOdbc = MyOdbc(
      driverName: config.driverName,
      username: config.username,
      password: config.password,
      database: config.database,
      server: config.server,
      port: config.port,
      databaseType: config.databaseType,
    );
    connectionString = myOdbc.getConnectionString();
  });

  group('Sync API (NativeOdbcConnection)', () {
    test('connect and execute SELECT 1 returns data', () {
      final native = odbc.NativeOdbcConnection();
      final initialized = native.initialize();
      expect(initialized, isTrue, reason: 'NativeOdbcConnection.initialize()');

      final connId = native.connect(connectionString);
      expect(connId, isNonZero, reason: 'connect() should return non-zero id');

      const sql = 'SELECT 1 AS value';
      final data = native.executeQueryParams(connId, sql, <odbc.ParamValue>[]);
      expect(data, isNotNull, reason: 'executeQueryParams should return data');
      expect(data!.isNotEmpty, isTrue, reason: 'SELECT 1 should return bytes');

      final ok = native.disconnect(connId);
      expect(ok, isTrue);
    });
  });
}
