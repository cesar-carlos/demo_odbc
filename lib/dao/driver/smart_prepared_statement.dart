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
    final values = <dynamic>[];
    int lastEnd = 0;

    for (var token in _tokens) {
      buffer.write(_templateSql.substring(lastEnd, token.start));

      if (!params.containsKey(token.name)) {
        return Failure(
            Exception('Parâmetro obrigatório não fornecido: ${token.name}'));
      }

      buffer.write('?');

      final val = params[token.name];
      if (val is DateTime) {
        values.add(val.toIso8601String().replaceAll('T', ' '));
      } else {
        values.add(val);
      }

      lastEnd = token.end;
    }

    if (lastEnd < _templateSql.length) {
      buffer.write(_templateSql.substring(lastEnd));
    }

    return Success(PreparedData(buffer.toString(), values));
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
