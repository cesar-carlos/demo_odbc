import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/table_metadata.dart';

class _CacheEntry {
  final List<Map<String, dynamic>> columns;
  final DateTime timestamp;

  _CacheEntry(this.columns) : timestamp = DateTime.now();

  bool get isValid {
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

  /// Generates a safe column list (with CAST for LOBs), ready to be used in SELECTs.
  /// Supports [alias] for use in JOINs (e.g., "c.Nome, CAST(c.Obs...)").
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

  /// Generates a paginated SELECT (Requires SQL Server 2012+).
  /// [orderBy] is required for pagination.
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

  /// Convenience method to generate a complete simple SELECT FROM table.
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

    final isBinary = type == 'image' || type == 'varbinary' || type == 'binary';

    if (isBinary) {
      return 'MAX';
    }

    if (length != null && length > 0) {
      return length.toString();
    }
    switch (type) {
      case 'int':
      case 'integer':
        return '11';
      case 'bigint':
        return '20';
      case 'smallint':
        return '6';
      case 'tinyint':
        return '3';
      case 'bit':
        return '1';
      case 'money':
      case 'smallmoney':
        return '50';
      case 'decimal':
      case 'numeric':
        return '50';
      case 'float':
      case 'real':
        return '50';
      case 'datetime':
      case 'datetime2':
      case 'smalldatetime':
        return '50';
      case 'date':
        return '10';
      case 'time':
        return '16';
      default:
        return (defaultSize ?? 2000).toString();
    }
  }
}
