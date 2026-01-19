import 'package:flutter_test/flutter_test.dart';

import 'package:demo_odbc/dao/sql_command.dart';
import 'package:demo_odbc/dao/config/database_config.dart';
import 'package:demo_odbc/dao/utils/schema_utils.dart';
import 'test_config.dart';

void main() {
  late DatabaseConfig config;
  late SqlCommand command;
  late String perfTableName;
  late PerformanceTestConfig perfConfig;
  late SchemaUtils schema;

  setUpAll(() async {
    final testConfig = TestDatabaseConfig.sqlServer(
      driverName: 'SQL Server Native Client 11.0',
      username: 'sa',
      password: '123abc.',
      database: 'NSE',
      server: 'CESAR_CARLOS\\DATA7',
      port: 1433,
    );

    testConfig.validate();
    config = testConfig.toDatabaseConfig();
    command = SqlCommand(config);
    perfConfig = PerformanceTestConfig(
      recordCount: 10000,
      batchSize: 1000,
      enableMetrics: true,
    );

    perfTableName = 'TestPerf_${DateTime.now().millisecondsSinceEpoch}';

    final connectResult = await command.connect();
    if (connectResult.isError()) {
      throw Exception('Failed to connect: ${connectResult.exceptionOrNull()}');
    }

    schema = SchemaUtils(command.odbc);

    final createResult = await schema.createTable(
      perfTableName,
      '''
      (
        Id INT PRIMARY KEY IDENTITY(1,1),
        Nome NVARCHAR(100) NOT NULL,
        Email VARCHAR(200),
        DataCadastro DATETIME DEFAULT GETDATE(),
        Ativo BIT DEFAULT 1
      )
      ''',
    );

    if (createResult.isError()) {
      throw Exception(
          'Failed to create performance table: ${createResult.exceptionOrNull()}');
    }
  });

  group('Performance Tests', () {
    test('should insert large amount of data efficiently using bulkInsert',
        () async {
      final stopwatch = Stopwatch()..start();
      final data = _generateTestData(perfConfig.recordCount);

      final result = await command.bulkInsert(
        perfTableName,
        data,
        batchSize: perfConfig.batchSize,
      );

      stopwatch.stop();

      expect(result.isSuccess(), isTrue);
      final inserted = result.getOrThrow();
      expect(inserted, equals(perfConfig.recordCount));

      if (perfConfig.enableMetrics) {
        final seconds = stopwatch.elapsedMilliseconds / 1000.0;
        final recordsPerSecond = perfConfig.recordCount / seconds;
        print(
            'INSERT Performance: ${perfConfig.recordCount} records in ${stopwatch.elapsedMilliseconds}ms');
        print(
            'Throughput: ${recordsPerSecond.toStringAsFixed(2)} records/second');
      }

      expect(stopwatch.elapsedMilliseconds, lessThan(300000));
    });

    test('should update large amount of data efficiently', () async {
      final stopwatch = Stopwatch()..start();

      command.clearParams();
      command.commandText = '''
        UPDATE $perfTableName 
        SET Nome = :nome 
        WHERE Id BETWEEN :minId AND :maxId
      ''';
      command.param('nome').asString = 'Updated';
      command.param('minId').asInt = 1;
      command.param('maxId').asInt = perfConfig.recordCount;

      final result = await command.execute();
      stopwatch.stop();

      expect(result.isSuccess(), isTrue);

      if (perfConfig.enableMetrics) {
        final seconds = stopwatch.elapsedMilliseconds / 1000.0;
        final recordsPerSecond = perfConfig.recordCount / seconds;
        print(
            'UPDATE Performance: ${perfConfig.recordCount} records in ${stopwatch.elapsedMilliseconds}ms');
        print(
            'Throughput: ${recordsPerSecond.toStringAsFixed(2)} records/second');
      }

      expect(stopwatch.elapsedMilliseconds, lessThan(300000));
    });

    test('should select all records efficiently', () async {
      final stopwatch = Stopwatch()..start();

      command.clearParams();
      command.commandText =
          'SELECT Id, Nome, Email, DataCadastro, Ativo FROM $perfTableName';

      final result = await command.open();
      stopwatch.stop();

      result.fold(
        (success) {
          expect(command.recordCount, equals(perfConfig.recordCount));

          int iteratedCount = 0;
          while (!command.eof) {
            final id = command.field('Id').asInt;
            final nome = command.field('Nome').asString;
            expect(id, isNotNull);
            expect(id, greaterThan(0));
            expect(nome, isNotNull);
            expect(nome, isNotEmpty);
            iteratedCount++;
            command.next();
          }

          expect(iteratedCount, equals(perfConfig.recordCount));

          if (perfConfig.enableMetrics) {
            final seconds = stopwatch.elapsedMilliseconds / 1000.0;
            final recordsPerSecond = perfConfig.recordCount / seconds;
            print(
                'SELECT Performance: ${perfConfig.recordCount} records in ${stopwatch.elapsedMilliseconds}ms');
            print(
                'Throughput: ${recordsPerSecond.toStringAsFixed(2)} records/second');
          }
        },
        (failure) => fail('Should select all records: $failure'),
      );

      expect(stopwatch.elapsedMilliseconds, lessThan(300000));
    });

    test('should select with WHERE filter efficiently', () async {
      final stopwatch = Stopwatch()..start();

      command.clearParams();
      command.commandText =
          'SELECT Id, Nome FROM $perfTableName WHERE Id BETWEEN :minId AND :maxId';
      command.param('minId').asInt = 1;
      command.param('maxId').asInt = 1000;

      final result = await command.open();
      stopwatch.stop();

      result.fold(
        (success) {
          expect(command.recordCount, equals(1000));

          if (perfConfig.enableMetrics) {
            final seconds = stopwatch.elapsedMilliseconds / 1000.0;
            final recordsPerSecond = 1000 / seconds;
            print(
                'SELECT WHERE Performance: 1000 records in ${stopwatch.elapsedMilliseconds}ms');
            print(
                'Throughput: ${recordsPerSecond.toStringAsFixed(2)} records/second');
          }
        },
        (failure) => fail('Should select filtered records: $failure'),
      );

      expect(stopwatch.elapsedMilliseconds, lessThan(30000));
    });

    test('should select with ORDER BY efficiently', () async {
      final stopwatch = Stopwatch()..start();

      command.clearParams();
      command.commandText =
          'SELECT TOP 1000 Id, Nome FROM $perfTableName ORDER BY Nome DESC';

      final result = await command.open();
      stopwatch.stop();

      result.fold(
        (success) {
          expect(command.recordCount, lessThanOrEqualTo(1000));

          if (perfConfig.enableMetrics) {
            final seconds = stopwatch.elapsedMilliseconds / 1000.0;
            final count = command.recordCount;
            final recordsPerSecond = count / seconds;
            print(
                'SELECT ORDER BY Performance: $count records in ${stopwatch.elapsedMilliseconds}ms');
            print(
                'Throughput: ${recordsPerSecond.toStringAsFixed(2)} records/second');
          }
        },
        (failure) => fail('Should select ordered records: $failure'),
      );

      expect(stopwatch.elapsedMilliseconds, lessThan(30000));
    });

    test('should delete large amount of data efficiently', () async {
      command.clearParams();
      command.commandText = 'SELECT COUNT(*) as Total FROM $perfTableName';
      final countBeforeResult = await command.open();
      int countBefore = 0;
      countBeforeResult.fold(
        (success) {
          if (!command.eof) {
            final totalValue = command.field('Total').asInt;
            if (totalValue != null) {
              countBefore = totalValue;
            }
          }
        },
        (failure) => fail('Should count records before delete: $failure'),
      );

      expect(countBefore, greaterThan(0));

      final stopwatch = Stopwatch()..start();

      command.clearParams();
      command.commandText =
          'DELETE FROM $perfTableName WHERE Id BETWEEN :minId AND :maxId';
      command.param('minId').asInt = 1;
      command.param('maxId').asInt = 5000;

      final deleteResult = await command.execute();
      stopwatch.stop();

      deleteResult.fold(
        (success) => expect(deleteResult.isSuccess(), isTrue),
        (failure) => fail('Should delete records: $failure'),
      );

      if (perfConfig.enableMetrics) {
        final seconds = stopwatch.elapsedMilliseconds / 1000.0;
        const deletedCount = 5000;
        final recordsPerSecond = deletedCount / seconds;
        print(
            'DELETE Performance: $deletedCount records in ${stopwatch.elapsedMilliseconds}ms');
        print(
            'Throughput: ${recordsPerSecond.toStringAsFixed(2)} records/second');
      }

      expect(stopwatch.elapsedMilliseconds, lessThan(300000));
    });

    test('should delete all records efficiently', () async {
      final stopwatch = Stopwatch()..start();

      command.clearParams();
      command.commandText = 'DELETE FROM $perfTableName';

      final deleteResult = await command.execute();
      stopwatch.stop();

      deleteResult.fold(
        (success) => expect(deleteResult.isSuccess(), isTrue),
        (failure) => fail('Should delete all records: $failure'),
      );

      command.clearParams();
      command.commandText = 'SELECT COUNT(*) as Total FROM $perfTableName';
      final countResult = await command.open();
      countResult.fold(
        (success) {
          if (!command.eof) {
            final total = command.field('Total').asInt;
            expect(total, isNotNull);
            expect(total, equals(0));
          } else {
            expect(command.recordCount, equals(0));
          }

          if (perfConfig.enableMetrics) {
            print(
                'DELETE ALL Performance: completed in ${stopwatch.elapsedMilliseconds}ms');
          }
        },
        (failure) => fail('Should count records after delete all: $failure'),
      );

      expect(stopwatch.elapsedMilliseconds, lessThan(300000));
    });
  });

  tearDownAll(() async {
    try {
      final dropResult =
          await command.odbc.execute('DROP TABLE $perfTableName');
      dropResult.fold(
        (success) => {},
        (failure) =>
            print('Warning: Failed to drop performance table: $failure'),
      );
    } catch (e) {
      print('Warning: Error dropping performance table: $e');
    }

    await command.close();
  });
}

List<Map<String, dynamic>> _generateTestData(int count) {
  return List.generate(
      count,
      (index) => {
            'Nome': 'TestUser_$index',
            'Email': 'user$index@test.com',
            'DataCadastro': DateTime.now(),
            'Ativo': true,
          });
}
