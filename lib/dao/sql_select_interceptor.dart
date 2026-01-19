import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/table_metadata.dart';

class _CacheConstants {
  static const Duration cacheExpiration = Duration(minutes: 8);
  static const int minQueryLength = 10;
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
}

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
    return DateTime.now().difference(timestamp) < _CacheConstants.cacheExpiration;
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
    if (trimmedQuery.length < _CacheConstants.minQueryLength) {
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
    if (trimmedQuery.length < _CacheConstants.minQueryLength) return null;

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

  bool _hasCast(String column) {
    final upperColumn = column.toUpperCase();
    return upperColumn.contains('CAST(') || upperColumn.contains('CONVERT(');
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

      if (_hasCast(cleanCol)) {
        buffer.write(cleanCol);
        continue;
      }

      final columnName = _extractColumnName(cleanCol);
      final colInfo = columnMap[columnName];

      if (colInfo != null) {
        buffer.write(_getCastExpression(colInfo));
      } else {
        buffer.write('CAST($cleanCol AS VARCHAR(${_VarcharSizeConstants.maxSize})) AS $cleanCol');
      }
    }

    return Success('SELECT ${buffer.toString()} FROM $tableName $restOfQuery');
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
      return 'CAST($name AS VARBINARY(${_VarcharSizeConstants.maxSize})) AS $name';
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
