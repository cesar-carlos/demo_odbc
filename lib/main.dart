import 'dart:io';
import 'package:flutter/material.dart';
import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/sql_command.dart';
import 'package:demo_odbc/dao/config/database_config.dart';
import 'package:demo_odbc/dao/safe_select_builder.dart';
import 'package:demo_odbc/dao/table_metadata.dart';

void main() async {
  await selectExemplo();
  //await updateExemplo();
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
    // Constrói query segura consultando metadados
    // -----------------------------------------------------------------------
    // Exemplo: Safe Select Builder + Coluna Manual
    // -----------------------------------------------------------------------
    final metadata = TableMetadata(query.odbc);
    final safeBuilder = SafeSelectBuilder(metadata);

    // 1. Obter colunas seguras (exclui image/varbinary automaticamente)
    final safeColsResult = await safeBuilder.getSafeColumns('Cliente');
    if (safeColsResult.isError()) throw safeColsResult.exceptionOrNull()!;
    final safeCols = safeColsResult.getOrThrow();

    // 2. Montar query manual adicionando uma coluna específica se necessário
    // OBS: Se adicionar campo IMAGE/VARBINARY aqui, cuidado com o erro HY001!
    query.commandText = '''
      SELECT 
        CodCliente, Nome, Observacao 
      FROM Cliente WITH (NOLOCK)
      WHERE CodCliente > :CodCliente
    ''';

    //print('SQL Gerado: ${query.commandText}');

    query.param('CodCliente').asInt = 1;

    return await query.open();
  });

  result.fold(
    (success) {
      while (!query.eof) {
        debugPrint(query.field("CodCliente").asInt.toString());
        debugPrint(query.field("Nome").asString);
        debugPrint(query.field("Observacao").asString);

        query.next();
      }

      debugPrint('Total de registros: ${query.recordCount}');
    },
    (failure) {
      debugPrint('Erro no SELECT: $failure');
    },
  );

  await query.close();
}

Future<void> updateExemplo() async {
  final config = DatabaseConfig.sqlServer(
    driverName: 'SQL Server Native Client 11.0',
    username: 'sa',
    password: '123abc.',
    database: 'NSE',
    server: 'CESAR_CARLOS\\DATA7',
    port: 1433,
  );
  final query = SqlCommand(config);

  await query.connect().flatMap((_) {
    query.commandText = '''
      UPDATE Cliente SET Observacao = :observacao 
      WHERE CodCliente = :codCliente
    ''';

    query.param('codCliente').asInt = 1;
    query.param('observacao').asString = 'Observação de teste2';

    return query.execute();
  }).fold(
    (success) => debugPrint('Update realizado com sucesso!'),
    (failure) => debugPrint('Erro no UPDATE: $failure'),
  );

  await query.close();
}
