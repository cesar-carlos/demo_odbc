import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/config/database_type.dart';

abstract class DatabaseDriver {
  DatabaseType get type;
  Future<Result<Unit>> connect();

  /// Executa uma query SQL e retorna os resultados como uma lista.
  /// [params] is optional for native Prepared Statements usage (v6).
  Future<Result<List<Map<String, dynamic>>>> execute(String query,
      {List<dynamic>? params});

  /// Executa uma query SQL retornando um Stream para leitura linha-a-linha (Cursor).
  /// Ideal para grandes volumes de dados.
  Future<Result<Stream<Map<String, dynamic>>>> executeCursor(String query,
      {List<dynamic>? params});
  Future<Result<Unit>> disconnect();
  Future<Result<Unit>> startTransaction();
  Future<Result<Unit>> commitTransaction();
  Future<Result<Unit>> rollbackTransaction();
}
