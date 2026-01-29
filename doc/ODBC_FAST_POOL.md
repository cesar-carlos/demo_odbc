# Controle de pool de conexões no odbc_fast

O pacote **odbc_fast** oferece **controle nativo de pool de conexões** na API de alto nível e wrappers de baixo nível.

---

## API de alto nível (OdbcService / IOdbcRepository)

Operações de pool retornam `Result<T>` (result_dart).

| Método                                             | Descrição                                                                                               |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `poolCreate(String connectionString, int maxSize)` | Cria um pool com DSN/connection string e tamanho máximo. Retorna `Result<int>` (pool ID).               |
| `poolGetConnection(int poolId)`                    | Obtém uma conexão do pool. Retorna `Result<Connection>`. Deve ser liberada com `poolReleaseConnection`. |
| `poolReleaseConnection(String connectionId)`       | Devolve a conexão ao pool (usa o `connection.id` retornado por `poolGetConnection`).                    |
| `poolHealthCheck(int poolId)`                      | Verifica saúde do pool. Retorna `Result<bool>`.                                                         |
| `poolGetState(int poolId)`                         | Retorna estado do pool: `Result<PoolState>` com `size` (total) e `idle` (disponíveis).                  |
| `poolClose(int poolId)`                            | Fecha o pool e libera todas as conexões.                                                                |

### Exemplo (README odbc_fast)

```dart
final poolIdResult = await service.poolCreate(dsn, 4);
await poolIdResult.fold((poolId) async {
  await service.poolHealthCheck(poolId);
  await service.poolGetState(poolId);
  // obter conexão
  final connResult = await service.poolGetConnection(poolId);
  await connResult.fold((connection) async {
    await service.executeQuery(connection.id, 'SELECT 1');
    await service.poolReleaseConnection(connection.id);
  }, (_) async {});
  await service.poolClose(poolId);
}, (_) async {});
```

---

## Entidade PoolState

- **size**: total de conexões no pool (ativas + idle).
- **idle**: conexões ociosas disponíveis para uso.

---

## API de baixo nível (ConnectionPool wrapper)

Wrapper imperativo sobre o backend nativo:

- `ConnectionPool(backend, poolId)` — construtor.
- `getConnection()` → `int` (connection ID; 0 em falha).
- `releaseConnection(int connectionId)` → `bool`.
- `healthCheck()` → `bool`.
- `getState()` → `({int size, int idle})?`.
- `close()` → `bool`.

Uso típico: `NativeOdbcConnection.createConnectionPool(dsn, maxSize)` retorna um `ConnectionPool` já criado.

---

## Uso no demo_odbc (migração concluída)

O **OdbcConnectionPool** do demo_odbc passou a usar o **pool nativo** do odbc_fast.

### Componentes

- **OdbcConnectionPool** — singleton que chama `poolCreate` / `poolGetConnection` / `poolReleaseConnection` / `poolClose` do odbc_fast.
- **PooledOdbcDriver** — implementação de [DatabaseDriver] que usa uma conexão obtida do pool; `disconnect()` devolve a conexão ao pool.
- **SqlCommand.withDriver(driver)** — construtor para usar com driver do pool (ex.: [PooledOdbcDriver]).

### Uso típico

```dart
final pool = OdbcConnectionPool();

// Uma vez na inicialização (ex.: no main ou no initState)
await pool.init(config, maxSize: 10);

// Por requisição ou tela
final driverResult = await pool.acquire();
await driverResult.fold((driver) async {
  final command = SqlCommand.withDriver(driver);
  command.commandText = 'SELECT * FROM Cliente';
  final openResult = await command.open();
  // ... usar command.rows ...
  await command.close();  // chama driver.disconnect() → devolve ao pool
  // ou: await pool.release(driver);
}, (e) async { /* tratar erro */ });

// Ao encerrar o app
await pool.closeAll();
```

### Diferenças em relação à versão anterior

| Antes (pool próprio)                | Agora (pool odbc_fast)                                                |
| ----------------------------------- | --------------------------------------------------------------------- |
| `init(config, maxSize)` síncrono    | `init(config, maxSize)` **async** — deve ser `await pool.init(...)`   |
| `release(DatabaseDriver)` síncrono  | `release(PooledOdbcDriver)` **async** — `await pool.release(driver)`  |
| acquire retornava `MyOdbc`          | acquire retorna `PooledOdbcDriver` (mesma interface [DatabaseDriver]) |
| closeAll() desconectava cada driver | closeAll() chama `poolClose(poolId)` no motor odbc_fast               |

---

## Referências

- [odbc_fast no pub.dev](https://pub.dev/packages/odbc_fast) — Features: _Connection pooling helpers (create/get/release/health/state/close)_.
- Repositório: `domain/repositories/odbc_repository.dart` (interface), `domain/entities/pool_state.dart`, `infrastructure/native/wrappers/connection_pool.dart`.
