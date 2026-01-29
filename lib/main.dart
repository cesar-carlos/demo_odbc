import 'dart:io';
import 'package:flutter/material.dart';
import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/sql_command.dart';
import 'package:demo_odbc/dao/config/database_config.dart';

void main() async {
  await selectExemplo();
  exit(0);
}

Future<void> selectExemplo() async {
  final config = DatabaseConfig.sqlServer(
    driverName: 'SQL Server Native Client 11.0',
    username: 'sa',
    password: '123abc.',
    database: 'Estacao',
    server: 'CESAR_CARLOS\\DATA7',
    port: 1433,
  );

  final query = SqlCommand(config);
  var recordCount = 0;

  query.commandText = '''
    SELECT *
    FROM Produto
  ''';

  final result = await query.connect().flatMap((_) => query.open());

  try {
    result.fold(
      (success) {
        while (!query.eof) {
          recordCount++;
          //debugPrint('Record: ${query.field('CodProduto').asInt}');
          //debugPrint('Record: ${query.field('Nome').asString}');
          //debugPrint('Record: ${query.field('Email').asString}');
          //debugPrint('Record: ${query.field('DataCadastro').asString}');
          query.next();
        }

        debugPrint('Total records in recordCount: $recordCount');
        debugPrint('Total records in query: ${query.recordCount}');
      },
      (failure) {
        debugPrint('Error in SELECT: $failure');
        debugPrint('Stack trace: ${failure.toString()}');
      },
    );
  } catch (e, stackTrace) {
    debugPrint('Fatal error during processing: $e');
    debugPrint('Stack trace: $stackTrace');
  } finally {
    await query.close();
    debugPrint('Connection closed.');
  }
}
