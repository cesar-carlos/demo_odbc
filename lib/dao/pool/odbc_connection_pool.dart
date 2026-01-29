import 'package:odbc_fast/odbc_fast.dart' as odbc;
import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/config/database_config.dart';
import 'package:demo_odbc/dao/driver/database_driver.dart';
import 'package:demo_odbc/dao/driver/my_odbc.dart';
import 'package:demo_odbc/dao/driver/pooled_odbc_driver.dart';

/// Pool de conexões que usa o **pool nativo** do odbc_fast
/// (poolCreate / poolGetConnection / poolReleaseConnection / poolClose).
///
/// Inicialize com [init] (async), depois [acquire] para obter um [DatabaseDriver]
/// ([PooledOdbcDriver]) e [release] ou [driver.disconnect] para devolver ao pool.
/// Use [closeAll] ao encerrar o app ou quando não precisar mais do pool.
class OdbcConnectionPool {
  static final OdbcConnectionPool _instance = OdbcConnectionPool._internal();
  factory OdbcConnectionPool() => _instance;

  OdbcConnectionPool._internal();

  static bool _locatorInitialized = false;

  DatabaseConfig? _config;
  int _maxSize = 10;
  int? _poolId;
  odbc.OdbcService? _service;

  /// Inicializa o pool com a configuração e o tamanho máximo.
  /// Usa o pool nativo odbc_fast (async). Deve ser chamado antes de [acquire].
  Future<void> init(DatabaseConfig config, {int maxSize = 10}) async {
    _config = config;
    _maxSize = maxSize;
    if (!_locatorInitialized) {
      odbc.ServiceLocator().initialize(useAsync: true);
      _locatorInitialized = true;
    }
    _service = odbc.ServiceLocator().asyncService;
    await _service!.initialize();

    final connStr = MyOdbc.fromConfig(config).getConnectionString();
    final poolResult = await _service!.poolCreate(connStr, _maxSize);

    poolResult.fold(
      (poolId) {
        _poolId = poolId;
      },
      (_) {
        _poolId = null;
        throw StateError(
          'Falha ao criar pool de conexões odbc_fast. Verifique DSN e rede.',
        );
      },
    );
  }

  /// Obtém uma conexão do pool nativo odbc_fast.
  /// Retorna um [PooledOdbcDriver] que implementa [DatabaseDriver].
  Future<Result<DatabaseDriver>> acquire() async {
    if (_config == null || _service == null || _poolId == null) {
      return Failure(
        Exception('Pool não inicializado. Chame init() primeiro.'),
      );
    }

    final connResult = await _service!.poolGetConnection(_poolId!);

    return connResult.fold(
      (connection) => Success(
        PooledOdbcDriver(
          connectionId: connection.id,
          service: _service!,
          poolId: _poolId!,
          databaseType: _config!.databaseType,
        ),
      ),
      (e) => Failure(Exception(e.toString())),
    );
  }

  /// Devolve a conexão ao pool. [driver] deve ser o [PooledOdbcDriver]
  /// retornado por [acquire]. Alternativamente, chame [DatabaseDriver.disconnect]
  /// no driver (o mesmo efeito).
  Future<void> release(PooledOdbcDriver driver) async {
    if (_service != null) {
      await _service!.poolReleaseConnection(driver.connectionId);
    }
  }

  /// Fecha o pool e libera todas as conexões no motor odbc_fast.
  Future<void> closeAll() async {
    if (_service != null && _poolId != null) {
      await _service!.poolClose(_poolId!);
      _poolId = null;
    }
  }
}
