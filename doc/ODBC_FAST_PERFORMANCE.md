# Melhorar tempos com odbc_fast – recomendações

Com base na [documentação do odbc_fast](https://pub.dev/packages/odbc_fast), seguem formas de melhorar tempos e o que o demo_odbc já faz ou pode fazer.

---

## 1. **maxResultBufferBytes** (já usado)

- **O que é:** Tamanho máximo do buffer de resultado por conexão (padrão 16 MB).
- **Uso:** Aumentar para result sets muito grandes evita erro "Buffer too small" e pode reduzir múltiplas leituras.
- **No projeto:** `DatabaseConfig.maxResultBufferBytes` é repassado ao `ConnectionOptions` na conexão. A tela de consulta usa 64 MB; testes podem usar o padrão ou configurar no `.env`/config se precisar.

---

## 2. **Bulk insert com protocolo binário** (maior ganho em INSERT)

- **O que é:** `BulkInsertBuilder` + `service.bulkInsert()` no odbc_fast – envio em binário em vez de SQL texto.
- **Vantagem:** Menos parsing e menos round-trips; tipicamente bem mais rápido que vários `INSERT INTO ... VALUES (...)`.
- **No projeto:** Implementado: `SqlCommand.bulkInsert()` tenta primeiro o **bulk insert nativo** (protocolo binário) quando o driver é MyOdbc ou PooledOdbcDriver; em caso de falha ou driver sem suporte, faz fallback para SQL texto em lotes. MyOdbc e PooledOdbcDriver expõem `bulkInsertNative(tableName, columnSpecs, rowValues)` usando `BulkInsertBuilder` + `service.bulkInsert()`.

---

## 3. **Streaming para SELECT grandes** (memória e throughput)

- **O que é:** `streamQueryBatched` (API de baixo nível) com `fetchSize` (linhas por lote) e `chunkSize` (tamanho do buffer em bytes).
- **Vantagem:** Não carrega todo o result set na memória de uma vez; pode melhorar tempo até a primeira linha e uso de memória em consultas muito grandes.
- **No projeto:** Consultas usam `executeQueryParams` (tudo em memória). Para a tela de consulta já há paginação (50/100/200/500 linhas por página), o que limita o impacto.
- **Melhoria possível:** Para relatórios ou exportações que leem muitas linhas, usar a API de streaming do odbc_fast (expor no driver um método que devolva `Stream` alimentado por `streamQueryBatched`) e consumir em lotes.

---

## 4. **Prepared statements** (queries repetidas)

- **O que é:** `service.prepare(connectionId, sql)` + `service.executePrepared(connectionId, stmtId, params)` para a mesma SQL com parâmetros diferentes.
- **Vantagem:** Evita reparse no servidor; ajuda em loops de INSERT/UPDATE/DELETE com a mesma estrutura.
- **No projeto:** Cada `execute()` / `executeQueryParams()` é uma chamada independente. Para o teste de performance, o UPDATE em massa é uma única execução; o INSERT em massa usa lotes de SQL texto.
- **Melhoria possível:** Em fluxos com muitas execuções da mesma SQL (mesma estrutura, parâmetros diferentes), usar prepare uma vez e várias vezes `executePrepared` pode reduzir tempo. O maior ganho continua sendo o bulk insert binário para INSERT em massa.

---

## 5. **Connection pooling** (já usado)

- **O que é:** `poolCreate` / `poolGetConnection` / `poolReleaseConnection` para reutilizar conexões.
- **Vantagem:** Elimina o custo de abrir/fechar conexão a cada requisição.
- **No projeto:** `OdbcConnectionPool` já usa o pool nativo do odbc_fast. Em cenários com muitas requisições curtas, isso já melhora os tempos.

---

## 6. **Backpressure e tamanho de lote em streaming**

- **O que é:** Ajustar `fetchSize` e `chunkSize` em `streamQueryBatched` conforme tamanho das linhas e capacidade do cliente.
- **Uso:** Valores maiores podem aumentar throughput e reduzir idas e voltas; valores menores reduzem pico de memória. Ajuste conforme o tipo de consulta e o hardware.

---

## 7. **Resumo prático**

| Onde quer melhorar       | Ação recomendada                                                                                                      |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| INSERT em massa          | Usar bulk insert binário do odbc_fast (`BulkInsertBuilder` + `bulkInsert`) em vez do `SqlCommand.bulkInsert()` atual. |
| SELECT com muitas linhas | Para relatórios/export, considerar streaming (`streamQueryBatched`) com `fetchSize`/`chunkSize` adequados.            |
| Result set muito grande  | Garantir `maxResultBufferBytes` suficiente na conexão (já feito na tela com 64 MB).                                   |
| Muitas requisições       | Usar pool de conexões (já feito com `OdbcConnectionPool`).                                                            |
| Mesma SQL repetida       | Avaliar prepare + executePrepared em loops (ganho menor que bulk insert binário).                                     |

A mudança com maior impacto nos tempos de **INSERT** no teste de performance é passar a usar o **bulk insert nativo** do odbc_fast quando possível; as demais otimizações ajudam em cenários específicos (grandes SELECTs, muitas conexões, mesma SQL repetida).
