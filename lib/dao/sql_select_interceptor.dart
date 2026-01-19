import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/table_metadata.dart';

class _SelectInfo {
  final bool isSelectAll;
  final List<String> columns;
  final String tableName;
  final String restOfQuery;

  _SelectInfo({
    required this.isSelectAll,
    required this.columns,
    required this.tableName,
    required this.restOfQuery,
  });
}

class _CacheEntry {
  final List<Map<String, dynamic>> columns;
  final Map<String, Map<String, dynamic>> columnMap;
  final DateTime timestamp;

  _CacheEntry(this.columns)
      : columnMap = {for (var col in columns) col['name'] as String: col},
        timestamp = DateTime.now();

  bool get isValid {
    return DateTime.now().difference(timestamp) < const Duration(minutes: 8);
  }
}

class _MetadataCache {
  static final Map<String, _CacheEntry> _cache = {};

  static Future<Result<_CacheEntry>> getCached(
    TableMetadata metadata,
    String tableName,
  ) async {
    final key = '${metadata.driver.type}_$tableName';

    if (_cache.containsKey(key)) {
      final entry = _cache[key]!;
      if (entry.isValid) {
        return Success(entry);
      } else {
        _cache.remove(key);
      }
    }

    final columnsResult = await metadata.getColumns(tableName);
    return columnsResult.map((columns) {
      final entry = _CacheEntry(columns);
      _cache[key] = entry;
      return entry;
    });
  }

  static void clearCache() {
    _cache.clear();
  }
}

class _TypeInfo {
  final String lowerType;
  late final bool isUnicode;
  late final bool isBinary;
  late final bool isString;

  _TypeInfo(this.lowerType) {
    isUnicode = lowerType == 'nvarchar' ||
        lowerType == 'nchar' ||
        lowerType == 'ntext';
    isBinary = lowerType == 'image' ||
        lowerType == 'varbinary' ||
        lowerType == 'binary';
    isString = lowerType == 'varchar' ||
        lowerType == 'char' ||
        lowerType == 'text';
  }
}

class _TypeCache {
  static final Map<String, _TypeInfo> _cache = {};

  static _TypeInfo getTypeInfo(String type) {
    final key = type.toLowerCase();
    return _cache.putIfAbsent(key, () => _TypeInfo(key));
  }

  static void clearCache() {
    _cache.clear();
  }
}

class SqlSelectInterceptor {
  final TableMetadata metadata;

  SqlSelectInterceptor(this.metadata);

  static void clearCache() {
    _MetadataCache.clearCache();
    _TypeCache.clearCache();
  }

  Future<Result<String>> interceptSelect(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 10) {
      return Success(query);
    }

    try {
      final selectInfo = _parseSelect(trimmedQuery);
      if (selectInfo == null) {
        return Success(query);
      }

      if (selectInfo.isSelectAll) {
        return await _applyCastToAllColumns(
          selectInfo.tableName,
          selectInfo.restOfQuery,
        );
      } else {
        return await _applyCastToColumns(
          selectInfo.columns,
          selectInfo.tableName,
          selectInfo.restOfQuery,
        );
      }
    } catch (e) {
      return Failure(Exception('Erro ao interceptar SELECT: $e'));
    }
  }

  _SelectInfo? _parseSelect(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 10) return null;

    final upperQuery = trimmedQuery.toUpperCase();
    if (!upperQuery.startsWith('SELECT')) return null;

    final selectMatch = RegExp(
      r'SELECT\s+(.+?)\s+FROM\s+(\w+(?:\.\w+)?)(?:\s+(?:WITH\s*\([^)]+\)))?(.*)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(trimmedQuery);

    if (selectMatch == null) return null;

    final columnsPart = selectMatch.group(1)?.trim() ?? '';
    final tableName = selectMatch.group(2)?.trim() ?? '';
    final restOfQuery = selectMatch.group(3)?.trim() ?? '';

    if (tableName.isEmpty) return null;

    final isSelectAll = columnsPart.trim() == '*';
    final columns = isSelectAll
        ? <String>[]
        : columnsPart
            .split(',')
            .map((col) => col.trim())
            .where((col) => col.isNotEmpty)
            .toList();

    return _SelectInfo(
      isSelectAll: isSelectAll,
      columns: columns,
      tableName: tableName,
      restOfQuery: restOfQuery,
    );
  }

  Future<Result<String>> _applyCastToColumns(
    List<String> columns,
    String tableName,
    String restOfQuery,
  ) async {
    final cacheResult = await _MetadataCache.getCached(metadata, tableName);
    if (cacheResult.isError()) {
      return Failure(
        cacheResult.exceptionOrNull() ??
            Exception('Erro ao obter colunas da tabela $tableName'),
      );
    }

    final entry = cacheResult.getOrThrow();
    final columnMap = entry.columnMap;

    final buffer = StringBuffer();
    for (var i = 0; i < columns.length; i++) {
      if (i > 0) buffer.write(', ');

      final cleanCol = columns[i].trim();
      final colInfo = columnMap[cleanCol];

      if (colInfo != null) {
        buffer.write(_getCastExpression(colInfo));
      } else {
        buffer.write('CAST($cleanCol AS VARCHAR(MAX)) AS $cleanCol');
      }
    }

    return Success('SELECT ${buffer.toString()} FROM $tableName $restOfQuery');
  }

  Future<Result<String>> _applyCastToAllColumns(
    String tableName,
    String restOfQuery,
  ) async {
    final cacheResult = await _MetadataCache.getCached(metadata, tableName);
    if (cacheResult.isError()) {
      return Failure(
        cacheResult.exceptionOrNull() ??
            Exception('Erro ao obter colunas da tabela $tableName'),
      );
    }

    final entry = cacheResult.getOrThrow();
    final columns = entry.columns;

    if (columns.isEmpty) {
      return Success('SELECT * FROM $tableName $restOfQuery');
    }

    final buffer = StringBuffer();
    for (var i = 0; i < columns.length; i++) {
      if (i > 0) buffer.write(', ');
      buffer.write(_getCastExpression(columns[i]));
    }

    return Success('SELECT ${buffer.toString()} FROM $tableName $restOfQuery');
  }

  String _getCastExpression(Map<String, dynamic> col) {
    final name = col['name'] as String;
    final type = col['type'] as String;
    final typeInfo = _TypeCache.getTypeInfo(type);

    if (typeInfo.isBinary) {
      return 'CAST($name AS VARCHAR(MAX)) AS $name';
    }

    if (typeInfo.isUnicode) {
      final size = _getVarcharSize(col);
      return 'CAST($name AS NVARCHAR($size)) AS $name';
    }

    if (typeInfo.isString) {
      final size = _getVarcharSize(col);
      return 'CAST($name AS VARCHAR($size)) AS $name';
    }

    final size = _getVarcharSize(col);
    return 'CAST($name AS VARCHAR($size)) AS $name';
  }

  String _getVarcharSize(Map<String, dynamic> col) {
    final type = col['type'] as String;
    final typeInfo = _TypeCache.getTypeInfo(type);

    if (typeInfo.isBinary) {
      return 'MAX';
    }

    final rawLength = col['length'];
    final length = rawLength is int
        ? rawLength
        : int.tryParse(rawLength?.toString() ?? '');

    if (length != null && length > 0) {
      return length.toString();
    }

    switch (typeInfo.lowerType) {
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
      case 'nvarchar':
      case 'varchar':
      case 'nchar':
      case 'char':
      case 'text':
      case 'ntext':
        return 'MAX';
      default:
        return '2000';
    }
  }
}
