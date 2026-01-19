import 'dart:io';
import 'package:flutter/material.dart';
import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/sql_command.dart';
import 'package:demo_odbc/dao/config/database_config.dart';
import 'package:demo_odbc/dao/safe_select_builder.dart';
import 'package:demo_odbc/dao/table_metadata.dart';

void main() async {
  await selectExemplo();
  exit(0);
}

Future<void> selectExemplo() async {
  final config = DatabaseConfig.sqlServer(
    driverName: 'SQL Server Native Client 11.0',
    username: 'sa',
    password: '123abc.',
    database: 'NSE',
    server: 'CESAR_CARLOS\\DATA7',
    port: 1433,
  );

  final query = SqlCommand(config);

  final result = await query.connect().flatMap((_) async {
    final metadata = TableMetadata(query.odbc);
    final safeBuilder = SafeSelectBuilder(metadata);

    final safeColsResult = await safeBuilder.getSafeColumns('Cliente');
    if (safeColsResult.isError()) throw safeColsResult.exceptionOrNull()!;

    query.commandText = '''
      SELECT *
      FROM Produto
    ''';

    return await query.open();
  });

  try {
    result.fold(
      (success) {
        while (!query.eof) {
          query.next();
        }

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
