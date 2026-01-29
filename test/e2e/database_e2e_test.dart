import 'package:flutter_test/flutter_test.dart';

import 'package:demo_odbc/dao/sql_command.dart';
import 'package:demo_odbc/dao/config/database_config.dart';
import 'package:demo_odbc/dao/utils/schema_utils.dart';
import 'test_config.dart';

void main() {
  late DatabaseConfig config;
  late SqlCommand command;
  late String testTableName;
  late SchemaUtils schema;

  setUpAll(() async {
    final testConfig = TestDatabaseConfig.sqlServer(
      driverName: 'SQL Server Native Client 11.0',
      username: 'sa',
      password: '123abc.',
      database: 'Estacao',
      server: 'CESAR_CARLOS\\DATA7',
      port: 1433,
    );

    testConfig.validate();
    config = testConfig.toDatabaseConfig();
    command = SqlCommand(config);

    testTableName = 'TestE2E_${DateTime.now().millisecondsSinceEpoch}';

    final connectResult = await command.connect();
    if (connectResult.isError()) {
      throw Exception('Failed to connect: ${connectResult.exceptionOrNull()}');
    }

    schema = SchemaUtils(command.odbc);
  });

  group('E2E Database Operations', () {
    test('should create table when table does not exist', () async {
      final existsBeforeResult = await schema.tableExists(testTableName);
      final existsBefore = existsBeforeResult.getOrThrow();
      expect(existsBefore, isFalse);

      final result = await schema.createTable(
        testTableName,
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

      expect(result.isSuccess(), isTrue);

      final existsAfterResult = await schema.tableExists(testTableName);
      existsAfterResult.fold(
        (exists) => expect(exists, isTrue),
        (failure) => fail('Should verify table exists: $failure'),
      );

      final idExistsResult = await schema.columnExists(testTableName, 'Id');
      idExistsResult.fold(
        (exists) => expect(exists, isTrue),
        (failure) => fail('Should verify Id column exists: $failure'),
      );

      final nomeExistsResult = await schema.columnExists(testTableName, 'Nome');
      nomeExistsResult.fold(
        (exists) => expect(exists, isTrue),
        (failure) => fail('Should verify Nome column exists: $failure'),
      );

      final emailExistsResult =
          await schema.columnExists(testTableName, 'Email');
      emailExistsResult.fold(
        (exists) => expect(exists, isTrue),
        (failure) => fail('Should verify Email column exists: $failure'),
      );
    });

    test('should add column when column does not exist', () async {
      final existsBeforeResult =
          await schema.columnExists(testTableName, 'Telefone');
      final existsBefore = existsBeforeResult.getOrThrow();
      expect(existsBefore, isFalse);

      final result = await schema.ensureColumn(
        testTableName,
        'Telefone',
        'NVARCHAR(20) NULL',
      );

      expect(result.isSuccess(), isTrue);

      final existsAfterResult =
          await schema.columnExists(testTableName, 'Telefone');
      existsAfterResult.fold(
        (exists) => expect(exists, isTrue),
        (failure) => fail('Should verify Telefone column exists: $failure'),
      );
    });

    test('should insert multiple records with named parameters', () async {
      final testData = [
        {
          'nome': 'João Silva',
          'email': 'joao@example.com',
          'telefone': '11999999999',
        },
        {
          'nome': 'Maria Santos',
          'email': 'maria@example.com',
          'telefone': '11888888888',
        },
        {
          'nome': 'Pedro Oliveira',
          'email': 'pedro@example.com',
          'telefone': '11777777777',
        },
      ];

      for (final data in testData) {
        command.clearParams();
        command.commandText = '''
          INSERT INTO $testTableName (Nome, Email, Telefone)
          VALUES (:nome, :email, :telefone)
        ''';

        command.param('nome').asString = data['nome'] as String;
        command.param('email').asString = data['email'] as String;
        command.param('telefone').asString = data['telefone'] as String;

        final result = await command.execute();
        result.fold(
          (success) => expect(result.isSuccess(), isTrue),
          (failure) => fail('Should insert record: $failure'),
        );
      }

      command.clearParams();
      final countQuery = 'SELECT COUNT(*) AS TotalCount FROM $testTableName';
      command.commandText = countQuery;
      final countResult = await command.open();
      countResult.fold(
        (success) {
          expect(command.recordCount, greaterThan(0));
          if (!command.eof) {
            final total = command.field('TotalCount').asInt;
            expect(total, isNotNull);
            expect(total, equals(testData.length));
          }
        },
        (failure) => fail('Should count records: $failure'),
      );
    });

    test('should select and iterate all records with correct types', () async {
      command.clearParams();
      command.commandText =
          'SELECT Id, Nome, Email, Telefone, DataCadastro, Ativo FROM $testTableName ORDER BY Id';

      final result = await command.open();
      result.fold(
        (success) {
          expect(command.recordCount, greaterThan(0));
          expect(command.eof, isFalse);

          int recordCount = 0;
          while (!command.eof) {
            final id = command.field('Id').asInt;
            final nome = command.field('Nome').asString;
            final email = command.field('Email').asString;
            final telefone = command.field('Telefone').asString;
            final dataCadastro = command.field('DataCadastro').asString;
            final ativo = command.field('Ativo').asBool;

            expect(id, isNotNull);
            expect(id, isA<int>());
            expect(id, greaterThan(0));
            expect(nome, isA<String>());
            expect(nome, isNotEmpty);
            expect(email, isA<String>());
            expect(telefone, isA<String>());
            expect(dataCadastro, isA<String>());
            expect(ativo, isA<bool>());

            recordCount++;
            command.next();
          }

          expect(recordCount, equals(command.recordCount));
        },
        (failure) => fail('Should select records: $failure'),
      );
    });

    test('should update records with named parameters', () async {
      command.clearParams();
      command.commandText = '''
        UPDATE $testTableName 
        SET Nome = :nome 
        WHERE Id = :id
      ''';

      command.param('id').asInt = 1;
      command.param('nome').asString = 'João Silva Atualizado';

      final result = await command.execute();
      result.fold(
        (success) => expect(result.isSuccess(), isTrue),
        (failure) => fail('Should update record: $failure'),
      );

      command.clearParams();
      command.commandText = 'SELECT Nome FROM $testTableName WHERE Id = :id';
      command.param('id').asInt = 1;

      final selectResult = await command.open();
      selectResult.fold(
        (success) {
          if (!command.eof) {
            final nome = command.field('Nome').asString;
            expect(nome, equals('João Silva Atualizado'));
          } else {
            fail('Should find updated record');
          }
        },
        (failure) => fail('Should select updated record: $failure'),
      );
    });

    test('should delete specific records', () async {
      command.clearParams();
      command.commandText = 'SELECT COUNT(*) AS TotalCount FROM $testTableName';
      final countBeforeResult = await command.open();
      int countBefore = 0;
      countBeforeResult.fold(
        (success) {
          if (!command.eof) {
            final totalValue = command.field('TotalCount').asInt;
            if (totalValue != null) {
              countBefore = totalValue;
            }
          }
        },
        (failure) => fail('Should count records before delete: $failure'),
      );

      expect(countBefore, greaterThan(0));

      command.clearParams();
      command.commandText = 'DELETE FROM $testTableName WHERE Id = :id';
      command.param('id').asInt = 1;

      final deleteResult = await command.execute();
      deleteResult.fold(
        (success) => expect(deleteResult.isSuccess(), isTrue),
        (failure) => fail('Should delete record: $failure'),
      );

      command.clearParams();
      command.commandText = 'SELECT COUNT(*) AS TotalCount FROM $testTableName';
      final countAfterResult = await command.open();
      countAfterResult.fold(
        (success) {
          if (!command.eof) {
            final countAfter = command.field('TotalCount').asInt;
            expect(countAfter, isNotNull);
            expect(countAfter, lessThan(countBefore));
          }
        },
        (failure) => fail('Should count records after delete: $failure'),
      );
    });

    test('should delete all records', () async {
      command.clearParams();
      command.commandText = 'DELETE FROM $testTableName';

      final deleteResult = await command.execute();
      deleteResult.fold(
        (success) => expect(deleteResult.isSuccess(), isTrue),
        (failure) => fail('Should delete all records: $failure'),
      );

      command.clearParams();
      command.commandText = 'SELECT COUNT(*) AS TotalCount FROM $testTableName';
      final countResult = await command.open();
      countResult.fold(
        (success) {
          if (!command.eof) {
            final total = command.field('TotalCount').asInt;
            expect(total, isNotNull);
            expect(total, equals(0));
          } else {
            expect(command.recordCount, equals(0));
          }
        },
        (failure) => fail('Should count records after delete all: $failure'),
      );
    });
  });

  tearDownAll(() async {
    try {
      final dropResult =
          await command.odbc.execute('DROP TABLE $testTableName');
      dropResult.fold(
        (success) => {},
        (failure) => print('Warning: Failed to drop table: $failure'),
      );
    } catch (e) {
      print('Warning: Error dropping table: $e');
    }

    await command.close();
  });
}
