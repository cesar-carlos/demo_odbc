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
    // Constrói query segura consultando metadados
    // -----------------------------------------------------------------------
    // Exemplo: Safe Select Builder + Coluna Manual
    // -----------------------------------------------------------------------
    final metadata = TableMetadata(query.odbc);
    final safeBuilder = SafeSelectBuilder(metadata);

    // 1. Obter colunas seguras (exclui image/varbinary automaticamente)
    // Nota: safeCols não está sendo usado neste exemplo, mas pode ser útil para validação
    final safeColsResult = await safeBuilder.getSafeColumns('Cliente');
    if (safeColsResult.isError()) throw safeColsResult.exceptionOrNull()!;

    // 2. Montar query manual adicionando uma coluna específica se necessário
    // OBS: Se adicionar campo IMAGE/VARBINARY aqui, cuidado com o erro HY001!
    query.commandText = '''
      SELECT *
      FROM Produto
    ''';

    return await query.open();
  });

  try {
    result.fold(
      (success) {
        // Processa usando while (!query.eof)
        int recordCount = 0;

        while (!query.eof) {
          // Processa cada registro individualmente
          // Exemplo de acesso aos dados:
          // final codProduto = query.field('CodProduto').asInt;
          // final nome = query.field('Nome').asString;
          // final codTipoProduto = query.field('CodTipoProduto').asInt;
          // final codUnidadeMedida = query.field('CodUnidadeMedida').asInt;

          // Exibe progresso a cada 1000 registros
          if (recordCount % 1000 == 0) {
            debugPrint('Processados $recordCount registros...');
          }

          query.next();
        }

        debugPrint('Total de registros processados: $recordCount');
        debugPrint('Total de registros na query: ${query.recordCount}');
      },
      (failure) {
        debugPrint('Erro no SELECT: $failure');
        debugPrint('Stack trace: ${failure.toString()}');
      },
    );
  } catch (e, stackTrace) {
    debugPrint('Erro fatal durante processamento: $e');
    debugPrint('Stack trace: $stackTrace');
  } finally {
    await query.close();
    debugPrint('Conexão fechada.');
  }
}
