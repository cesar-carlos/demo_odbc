import 'package:flutter/foundation.dart';
import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/table_metadata.dart';
import 'package:demo_odbc/dao/config/database_type.dart';

class _CacheConstants {
  static const Duration cacheExpiration = Duration(minutes: 8);
  static const int minQueryLength = 10;
  static const int maxSqlLengthWarning = 10000;
  static const int maxColumnsWarning = 500;
}

class _VarcharSizeConstants {
  static const String intSize = '11';
  static const String bigintSize = '20';
  static const String smallintSize = '6';
  static const String tinyintSize = '3';
  static const String bitSize = '1';
  static const String moneySize = '50';
  static const String decimalSize = '50';
  static const String floatSize = '50';
  static const String datetimeSize = '50';
  static const String dateSize = '10';
  static const String timeSize = '16';
  static const String maxSize = 'MAX';
  static const String defaultSize = '2000';
  static const String maxSafeSize = '8000';
}

class _SelectInfo {
  final bool isSelectAll;
  final List<String> columns;
  final String tableName;
  final String restOfQuery;
  final String? topClause;

  _SelectInfo({
    required this.isSelectAll,
    required this.columns,
    required this.tableName,
    required this.restOfQuery,
    this.topClause,
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
    return DateTime.now().difference(timestamp) <
        _CacheConstants.cacheExpiration;
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
    isUnicode =
        lowerType == 'nvarchar' || lowerType == 'nchar' || lowerType == 'ntext';
    isBinary = lowerType == 'image' ||
        lowerType == 'varbinary' ||
        lowerType == 'binary' ||
        lowerType == 'bytea';
    isString =
        lowerType == 'varchar' || lowerType == 'char' || lowerType == 'text';
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
    if (trimmedQuery.length < _CacheConstants.minQueryLength) {
      return Success(query);
    }

    try {
      final selectInfo = _parseSelect(trimmedQuery);
      if (selectInfo == null) {
        return Success(query);
      }

      final result = selectInfo.isSelectAll
          ? await _applyCastToAllColumns(
              selectInfo.tableName,
              selectInfo.restOfQuery,
              selectInfo.topClause,
            )
          : await _applyCastToColumns(
              selectInfo.columns,
              selectInfo.tableName,
              selectInfo.restOfQuery,
              selectInfo.topClause,
            );

      if (result.isSuccess()) {
        final interceptedQuery = result.getOrThrow();
        if (interceptedQuery.length > _CacheConstants.maxSqlLengthWarning) {
          debugPrint(
              'SqlSelectInterceptor: SQL gerado muito grande (${interceptedQuery.length} caracteres)');
        }
      }

      return result;
    } catch (e, stackTrace) {
      return Failure(
          Exception('Error intercepting SELECT: $e\nStack trace: $stackTrace'));
    }
  }

  _SelectInfo? _parseSelect(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < _CacheConstants.minQueryLength) return null;

    final upperQuery = trimmedQuery.toUpperCase();
    if (!upperQuery.startsWith('SELECT')) return null;

    String? topClause;
    String queryWithoutTop = trimmedQuery;

    final topMatch = RegExp(
      r'SELECT\s+(TOP\s+\d+)\s+',
      caseSensitive: false,
    ).firstMatch(trimmedQuery);

    if (topMatch != null) {
      topClause = topMatch.group(1);
      queryWithoutTop = trimmedQuery.replaceFirst(
        RegExp(r'SELECT\s+TOP\s+\d+\s+', caseSensitive: false),
        'SELECT ',
      );
    }

    final selectMatch = RegExp(
      r'SELECT\s+(.+?)\s+FROM\s+(\w+(?:\.\w+)?)(?:\s+(?:WITH\s*\([^)]+\)))?(.*)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(queryWithoutTop);

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
      topClause: topClause,
    );
  }

  bool _hasCast(String column) {
    final upperColumn = column.toUpperCase();
    return upperColumn.contains('CAST(') || upperColumn.contains('CONVERT(');
  }

  bool _isAggregateFunction(String column) {
    final upperColumn = column.toUpperCase().trim();
    final aggregateFunctions = [
      'COUNT(',
      'SUM(',
      'AVG(',
      'MAX(',
      'MIN(',
      'STDEV(',
      'STDEVP(',
      'VAR(',
      'VARP(',
    ];
    
    for (final func in aggregateFunctions) {
      if (upperColumn.startsWith(func)) {
        return true;
      }
    }
    
    return false;
  }

  Future<Result<String>> _applyCastToColumns(
    List<String> columns,
    String tableName,
    String restOfQuery,
    String? topClause,
  ) async {
    if (columns.length > _CacheConstants.maxColumnsWarning) {
      debugPrint(
          'SqlSelectInterceptor: AVISO - Query com ${columns.length} colunas (pode ser lento)');
    }

    final cacheResult = await _MetadataCache.getCached(metadata, tableName);
    if (cacheResult.isError()) {
      return Failure(
        cacheResult.exceptionOrNull() ??
            Exception('Error getting columns from table $tableName'),
      );
    }

    final entry = cacheResult.getOrThrow();
    final columnMap = entry.columnMap;

    final buffer = StringBuffer();
    for (var i = 0; i < columns.length; i++) {
      if (i > 0) buffer.write(', ');

      final cleanCol = columns[i].trim();

      if (_hasCast(cleanCol)) {
        buffer.write(cleanCol);
        continue;
      }

      if (_isAggregateFunction(cleanCol)) {
        buffer.write(cleanCol);
        continue;
      }

      final columnName = _extractColumnName(cleanCol);
      final colInfo = columnMap[columnName];

      if (colInfo != null) {
        buffer.write(_getCastExpression(colInfo));
      } else {
        buffer.write(_getFallbackCast(cleanCol));
      }
    }

    final topPrefix = topClause != null ? '$topClause ' : '';
    final finalQuery =
        'SELECT $topPrefix${buffer.toString()} FROM $tableName $restOfQuery';
    return Success(finalQuery);
  }

  String _extractColumnName(String column) {
    var result = column.trim();

    final aliasPattern = RegExp(r'\s+AS\s+\w+', caseSensitive: false);
    result = result.replaceAll(aliasPattern, '').trim();

    final dotIndex = result.lastIndexOf('.');
    if (dotIndex >= 0 && dotIndex < result.length - 1) {
      result = result.substring(dotIndex + 1).trim();
    }

    final words = result.split(RegExp(r'\s+'));
    if (words.length > 1) {
      final lastWord = words.last;
      if (!lastWord.contains('(') &&
          !lastWord.contains('[') &&
          !lastWord.contains(')') &&
          !lastWord.contains(']') &&
          !lastWord.contains('.')) {
        result = words.sublist(0, words.length - 1).join(' ').trim();
      }
    }

    return result;
  }

  Future<Result<String>> _applyCastToAllColumns(
    String tableName,
    String restOfQuery,
    String? topClause,
  ) async {
    final cacheResult = await _MetadataCache.getCached(metadata, tableName);
    if (cacheResult.isError()) {
      return Failure(
        cacheResult.exceptionOrNull() ??
            Exception('Error getting columns from table $tableName'),
      );
    }

    final entry = cacheResult.getOrThrow();
    final columns = entry.columns;

    if (columns.isEmpty) {
      final topPrefix = topClause != null ? '$topClause ' : '';
      return Success('SELECT $topPrefix* FROM $tableName $restOfQuery');
    }

    final buffer = StringBuffer();
    for (var i = 0; i < columns.length; i++) {
      if (i > 0) buffer.write(', ');
      buffer.write(_getCastExpression(columns[i]));
    }

    final topPrefix = topClause != null ? '$topClause ' : '';
    return Success(
        'SELECT $topPrefix${buffer.toString()} FROM $tableName $restOfQuery');
  }

  String _getCastExpression(Map<String, dynamic> col) {
    final name = col['name'] as String;
    final type = col['type'] as String;
    final typeInfo = _TypeCache.getTypeInfo(type);
    final dbType = metadata.driver.type;

    if (typeInfo.isBinary) {
      return _getBinaryCast(name, dbType);
    }

    if (typeInfo.isUnicode) {
      final size = _getVarcharSize(col);
      return _getUnicodeCast(name, size, dbType);
    }

    if (typeInfo.isString) {
      final size = _getVarcharSize(col);
      return 'CAST($name AS VARCHAR($size)) AS $name';
    }

    final size = _getVarcharSize(col);
    return 'CAST($name AS VARCHAR($size)) AS $name';
  }

  String _getBinaryCast(String name, DatabaseType dbType) {
    switch (dbType) {
      case DatabaseType.postgresql:
        return 'CAST($name AS BYTEA) AS $name';
      case DatabaseType.sqlServer:
      case DatabaseType.sybaseAnywhere:
        return 'CAST($name AS VARBINARY(${_VarcharSizeConstants.maxSize})) AS $name';
    }
  }

  String _getUnicodeCast(String name, String size, DatabaseType dbType) {
    switch (dbType) {
      case DatabaseType.postgresql:
        return 'CAST($name AS VARCHAR($size)) AS $name';
      case DatabaseType.sqlServer:
      case DatabaseType.sybaseAnywhere:
        return 'CAST($name AS NVARCHAR($size)) AS $name';
    }
  }

  String _getFallbackCast(String column) {
    final dbType = metadata.driver.type;
    switch (dbType) {
      case DatabaseType.postgresql:
        return 'CAST($column AS TEXT) AS $column';
      case DatabaseType.sqlServer:
      case DatabaseType.sybaseAnywhere:
        return 'CAST($column AS VARCHAR(${_VarcharSizeConstants.maxSafeSize})) AS $column';
    }
  }

  String _getVarcharSize(Map<String, dynamic> col) {
    final type = col['type'] as String;
    final typeInfo = _TypeCache.getTypeInfo(type);

    if (typeInfo.isBinary) {
      return _VarcharSizeConstants.maxSize;
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
        return _VarcharSizeConstants.intSize;
      case 'bigint':
        return _VarcharSizeConstants.bigintSize;
      case 'smallint':
        return _VarcharSizeConstants.smallintSize;
      case 'tinyint':
        return _VarcharSizeConstants.tinyintSize;
      case 'bit':
        return _VarcharSizeConstants.bitSize;
      case 'money':
      case 'smallmoney':
        return _VarcharSizeConstants.moneySize;
      case 'decimal':
      case 'numeric':
        return _VarcharSizeConstants.decimalSize;
      case 'float':
      case 'real':
        return _VarcharSizeConstants.floatSize;
      case 'datetime':
      case 'datetime2':
      case 'smalldatetime':
        return _VarcharSizeConstants.datetimeSize;
      case 'date':
        return _VarcharSizeConstants.dateSize;
      case 'time':
        return _VarcharSizeConstants.timeSize;
      case 'nvarchar':
      case 'varchar':
      case 'nchar':
      case 'char':
      case 'text':
      case 'ntext':
        return _VarcharSizeConstants.maxSize;
      default:
        return _VarcharSizeConstants.defaultSize;
    }
  }
}
