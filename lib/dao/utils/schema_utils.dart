import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/config/database_type.dart';
import 'package:demo_odbc/dao/driver/database_driver.dart';


class SchemaUtils {
  final DatabaseDriver driver;

  SchemaUtils(this.driver);

  /// Verifica se uma tabela existe no banco de dados.
  Future<Result<bool>> tableExists(String tableName) async {
    final sanitizedName = _sanitize(tableName);
    String query;

    switch (driver.type) {
      case DatabaseType.sybaseAnywhere:
        query = "SELECT 1 FROM SYS.SYSTABLE WHERE table_name = '$sanitizedName' AND table_type = 'BASE'";
        break;
      case DatabaseType.sqlServer:
      case DatabaseType.postgresql:
        // Padrão ANSI
        query = "SELECT 1 FROM information_schema.tables WHERE table_name = '$sanitizedName' AND table_type = 'BASE TABLE'";
        break;
    }
    return _checkExists(query);
  }

  /// Verifica se uma view existe.
  Future<Result<bool>> viewExists(String viewName) async {
    final sanitizedName = _sanitize(viewName);
    String query;

    switch (driver.type) {
      case DatabaseType.sybaseAnywhere:
        query = "SELECT 1 FROM SYS.SYSTABLE WHERE table_name = '$sanitizedName' AND table_type = 'VIEW'";
        break;
      case DatabaseType.sqlServer:
      case DatabaseType.postgresql:
        query = "SELECT 1 FROM information_schema.tables WHERE table_name = '$sanitizedName' AND table_type = 'VIEW'";
        break;
    }
    return _checkExists(query);
  }

  /// Verifica se uma coluna existe em uma tabela.
  Future<Result<bool>> columnExists(String tableName, String columnName) async {
    final t = _sanitize(tableName);
    final c = _sanitize(columnName);
    String query;

    switch (driver.type) {
      case DatabaseType.sybaseAnywhere:
        query = '''
          SELECT 1 
          FROM SYS.SYSCOLUMN c 
          JOIN SYS.SYSTABLE t ON c.table_id = t.table_id 
          WHERE t.table_name = '$t' AND c.column_name = '$c'
        ''';
        break;
      case DatabaseType.sqlServer:
      case DatabaseType.postgresql:
        query = "SELECT 1 FROM information_schema.columns WHERE table_name = '$t' AND column_name = '$c'";
        break;
    }
    return _checkExists(query);
  }

  /// Verifica se uma procedure ou function existe.
  Future<Result<bool>> procedureExists(String procName) async {
    final p = _sanitize(procName);
    String query;

    switch (driver.type) {
      case DatabaseType.sybaseAnywhere:
        query = "SELECT 1 FROM SYS.SYSPROCEDURE WHERE proc_name = '$p'";
        break;
      case DatabaseType.sqlServer:
      case DatabaseType.postgresql:
        query = "SELECT 1 FROM information_schema.routines WHERE routine_name = '$p'";
        break;
    }
    return _checkExists(query);
  }

  /// Cria uma nova tabela se ela não existir (via verificação manual antes pode ser feito pelo caller).
  /// [ddlBody] deve conter o corpo da definição, ex: "(Id INT, Nome VARCHAR(100))"
  Future<Result<Unit>> createTable(String tableName, String ddlBody) async {
    return (await driver.execute('CREATE TABLE $tableName $ddlBody')).map((_) => unit);
  }

  /// Garante que uma coluna exista na tabela. Se não existir, executa ALTER TABLE ADD.
  /// [ddlType] ex: "INT", "VARCHAR(100) NULL".
  Future<Result<Unit>> ensureColumn(String tableName, String columnName, String ddlType) async {
    final existsResult = await columnExists(tableName, columnName);
    
    if (existsResult.isError()) {
      return existsResult.map((_) => unit);
    }
    
    if (existsResult.getOrThrow()) {
      return Success.unit(); // Já existe
    }

    // Não existe, cria
    final query = 'ALTER TABLE $tableName ADD $columnName $ddlType';
    return (await driver.execute(query)).map((_) => unit);
  }

  Future<Result<bool>> _checkExists(String query) async {
    final result = await driver.execute(query);
    if (result.isError()) {
      return Failure(result.exceptionOrNull()!);
    }
    final rows = result.getOrThrow();
    return Success(rows.isNotEmpty);
  }

  String _sanitize(String input) {
    return input.replaceAll("'", "''");
  }
}
