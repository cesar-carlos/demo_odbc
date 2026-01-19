import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/table_metadata.dart';

class _CacheEntry {
  final List<Map<String, dynamic>> columns;
  final DateTime timestamp;

  _CacheEntry(this.columns) : timestamp = DateTime.now();

  bool get isValid {
    // Cache expira em 30 minutos
    return DateTime.now().difference(timestamp) < const Duration(minutes: 30);
  }
}

class SafeSelectBuilder {
  final TableMetadata metadata;
  static final Map<String, _CacheEntry> _cache = {};

  SafeSelectBuilder(this.metadata);

  static void clearCache() {
    _cache.clear();
  }

  /// Gera uma lista de colunas segura (com CAST para LOBs), pronta para ser usada em SELECTs.
  /// Suporta [alias] para usar em JOINs (ex: "c.Nome, CAST(c.Obs...)").
  Future<Result<String>> getSafeColumns(String tableName,
      {String? alias, int maxLobSize = 4000}) async {
    if (_cache.containsKey(tableName)) {
      final entry = _cache[tableName]!;
      if (entry.isValid) {
        return Success(_buildColumnsString(entry.columns, maxLobSize, alias));
      } else {
        _cache.remove(tableName);
      }
    }

    final columnsResult = await metadata.getColumns(tableName);

    return columnsResult.map((columns) {
      _cache[tableName] = _CacheEntry(columns);
      return _buildColumnsString(columns, maxLobSize, alias);
    });
  }

  /// Método para gerar SELECT paginado (Requer SQL Server 2012+).
  /// [orderBy] é obrigatório para paginação.
  Future<Result<String>> buildPaginated(
    String tableName, {
    required String orderBy,
    int page = 1,
    int pageSize = 100,
    int maxLobSize = 4000,
    bool withNoLock = false,
  }) async {
    return (await getSafeColumns(tableName, maxLobSize: maxLobSize))
        .map((cols) {
      final offset = (page - 1) * pageSize;
      return '''
        SELECT $cols 
        FROM $tableName${withNoLock ? ' WITH (NOLOCK)' : ''}
        ORDER BY $orderBy
        OFFSET $offset ROWS FETCH NEXT $pageSize ROWS ONLY
      ''';
    });
  }

  /// Método de conveniência para gerar um SELECT simples completo FROM tabela.
  Future<Result<String>> buildSafely(String tableName,
      {int maxLobSize = 4000, bool withNoLock = false}) async {
    return (await getSafeColumns(tableName, maxLobSize: maxLobSize)).map(
        (cols) =>
            'SELECT $cols FROM $tableName${withNoLock ? ' WITH (NOLOCK)' : ''}');
  }

  String _buildColumnsString(
      List<Map<String, dynamic>> columns, int maxLobSize, String? alias) {
    if (columns.isEmpty) {
      return alias != null ? '$alias.*' : '*'; // Fallback
    }

    final prefix = alias != null ? '$alias.' : '';

    return columns.map((col) {
      final name = col['name'] as String;
      final varcharSize = _getVarcharSize(col, maxLobSize);

      return 'CAST($prefix$name AS VARCHAR($varcharSize)) AS $name';
    }).join(', ');
  }

  String _getVarcharSize(
    Map<String, dynamic> col,
    int? defaultSize,
  ) {
    final type = (col['type'] as String).toLowerCase();
    final rawLength = col['length'];
    final length = rawLength is int
        ? rawLength
        : int.tryParse(rawLength?.toString() ?? '');

    // Colunas binárias → VARCHAR(MAX)
    final isBinary = type == 'image' ||
        type == 'varbinary' ||
        type == 'binary';

    if (isBinary) {
      return 'MAX';
    }

    // Se tem length definido, usa o tamanho real
    if (length != null && length > 0) {
      return length.toString();
    }

    // Tamanhos padrão baseados no tipo de dado
    switch (type) {
      case 'int':
      case 'integer':
        return '11'; // INT: -2,147,483,648 a 2,147,483,647 (máx 11 chars)
      case 'bigint':
        return '20'; // BIGINT: valores muito grandes (máx 20 chars)
      case 'smallint':
        return '6'; // SMALLINT: -32,768 a 32,767 (máx 6 chars)
      case 'tinyint':
        return '3'; // TINYINT: 0 a 255 (máx 3 chars)
      case 'bit':
        return '1'; // BIT: 0 ou 1
      case 'money':
      case 'smallmoney':
        return '50'; // MONEY: valores monetários formatados
      case 'decimal':
      case 'numeric':
        return '50'; // DECIMAL/NUMERIC: valores decimais
      case 'float':
      case 'real':
        return '50'; // FLOAT/REAL: valores decimais
      case 'datetime':
      case 'datetime2':
      case 'smalldatetime':
        return '50'; // DATETIME: formato ISO pode precisar de espaço
      case 'date':
        return '10'; // DATE: formato ISO (YYYY-MM-DD)
      case 'time':
        return '16'; // TIME: formato ISO (HH:MM:SS.mmm)
      default:
        return (defaultSize ?? 2000).toString(); // Padrão para tipos desconhecidos
    }
  }
}
