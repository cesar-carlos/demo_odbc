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
  Future<Result<String>> getSafeColumns(String tableName, {String? alias, int maxLobSize = 4000}) async {
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
    return (await getSafeColumns(tableName, maxLobSize: maxLobSize)).map((cols) {
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
  Future<Result<String>> buildSafely(String tableName, {int maxLobSize = 4000, bool withNoLock = false}) async {
    return (await getSafeColumns(tableName, maxLobSize: maxLobSize))
        .map((cols) => 'SELECT $cols FROM $tableName${withNoLock ? ' WITH (NOLOCK)' : ''}');
  }

  String _buildColumnsString(List<Map<String, dynamic>> columns, int maxLobSize, String? alias) {
    if (columns.isEmpty) {
      return alias != null ? '$alias.*' : '*'; // Fallback
    }

    final prefix = alias != null ? '$alias.' : '';

    return columns
        .where((col) {
          final type = (col['type'] as String).toLowerCase();
          // Excluir colunas binárias da seleção automática para evitar HY001
          // O usuário deve buscar estas colunas explicitamente se necessário
          return type != 'image' && type != 'varbinary'; 
        })
        .map((col) {
          final name = col['name'] as String;
          final type = (col['type'] as String).toLowerCase();
            
          final rawLength = col['length'];
          final length = rawLength is int 
              ? rawLength 
              : int.tryParse(rawLength?.toString() ?? '');

          // Identifica Texto Longo para aplicar CAST 
          // Inclui XML, Text, NText e Varchar(MAX)
          final isTextLob = type == 'text' || 
                            type == 'ntext' || 
                            type == 'xml' ||
                            (type.contains('varchar') && (length == -1 || (length != null && length > 8000)));

          if (isTextLob) {
            // Cast para limitar o tamanho de textos gigantes e evitar HY001
            return 'CAST($prefix$name AS VARCHAR($maxLobSize)) AS $name';
          } else {
            return '$prefix$name';
          }
        }).join(', ');
  }
}
