import 'package:result_dart/result_dart.dart';

class SmartPreparedStatement {
  final String _templateSql;
  final List<_ParamToken> _tokens;

  SmartPreparedStatement._(this._templateSql, this._tokens);

  static SmartPreparedStatement prepare(String sql) {
    final tokens = <_ParamToken>[];
    final regex = RegExp(r':(\w+)');

    final matches = regex.allMatches(sql);

    if (matches.isEmpty) {
      return SmartPreparedStatement._(sql, []);
    }

    for (var match in matches) {
      tokens.add(_ParamToken(match.group(1)!, match.start, match.end));
    }

    return SmartPreparedStatement._(sql, tokens);
  }

  Result<PreparedData> execute(Map<String, dynamic> params) {
    final buffer = StringBuffer();
    int lastEnd = 0;

    for (var token in _tokens) {
      buffer.write(_templateSql.substring(lastEnd, token.start));

      if (!params.containsKey(token.name)) {
        return Failure(
            Exception('Parâmetro obrigatório não fornecido: ${token.name}'));
      }

      // Interpolate value directly with proper escaping
      final val = params[token.name];
      buffer.write(_escapeValue(val));

      lastEnd = token.end;
    }

    if (lastEnd < _templateSql.length) {
      buffer.write(_templateSql.substring(lastEnd));
    }

    // Return SQL with interpolated values and empty params list
    return Success(PreparedData(buffer.toString(), []));
  }

  String _escapeValue(dynamic value) {
    if (value == null) {
      return 'NULL';
    }
    if (value is int || value is double) {
      return value.toString();
    }
    if (value is bool) {
      return value ? '1' : '0';
    }
    if (value is DateTime) {
      // Format: YYYY-MM-DD HH:MM:SS.mmm (milliseconds only for SQL Server DATETIME)
      final year = value.year.toString().padLeft(4, '0');
      final month = value.month.toString().padLeft(2, '0');
      final day = value.day.toString().padLeft(2, '0');
      final hour = value.hour.toString().padLeft(2, '0');
      final minute = value.minute.toString().padLeft(2, '0');
      final second = value.second.toString().padLeft(2, '0');
      final ms = value.millisecond.toString().padLeft(3, '0');
      return "'$year-$month-$day $hour:$minute:$second.$ms'";
    }
    // For strings, escape single quotes by doubling them
    return "'${value.toString().replaceAll("'", "''")}'";
  }
}

class PreparedData {
  final String sql;
  final List<dynamic> params;
  PreparedData(this.sql, this.params);
}

class _ParamToken {
  final String name;
  final int start;
  final int end;

  _ParamToken(this.name, this.start, this.end);
}
