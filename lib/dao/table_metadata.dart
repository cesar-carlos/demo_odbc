import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/config/database_type.dart';
import 'package:demo_odbc/dao/driver/database_driver.dart';

class TableMetadata {
  final DatabaseDriver driver;

  TableMetadata(this.driver);

  Future<Result<List<Map<String, dynamic>>>> getColumns(
      String tableName) async {
    final sanitizedTable = tableName.replaceAll("'", "''");
    String query;

    switch (driver.type) {
      case DatabaseType.sybaseAnywhere:
        query = '''
          SELECT 
            c.column_name as name, 
            d.domain_name as type, 
            c.width as length 
          FROM SYS.SYSCOLUMN c 
          JOIN SYS.SYSTABLE t ON c.table_id = t.table_id 
          JOIN SYS.SYSDOMAIN d ON c.domain_id = d.domain_id 
          WHERE t.table_name = '$sanitizedTable'
        ''';
        break;

      case DatabaseType.sqlServer:
      case DatabaseType.postgresql:
        final defaultSchema = _getDefaultSchema();
        query = '''
          SELECT 
            column_name as name, 
            data_type as type, 
            character_maximum_length as length
          FROM information_schema.columns 
          WHERE table_name = '$sanitizedTable'
          AND table_schema = '$defaultSchema'
        ''';
        break;
    }

    return await driver.execute(query);
  }

  String _getDefaultSchema() {
    switch (driver.type) {
      case DatabaseType.sqlServer:
        return 'dbo';
      case DatabaseType.sybaseAnywhere:
        return 'dba';
      case DatabaseType.postgresql:
        return 'public';
    }
  }
}
