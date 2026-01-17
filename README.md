# demo_odbc

Biblioteca Flutter/Dart para acesso a bancos de dados via ODBC, fornecendo uma camada de abstração limpa e segura para operações SQL com suporte a SQL Server, PostgreSQL, Sybase Anywhere e outros bancos compatíveis com ODBC.

## 📋 Índice

- [Características](#características)
- [Requisitos](#requisitos)
- [Instalação](#instalação)
- [Configuração](#configuração)
- [Uso Básico](#uso-básico)
- [Componentes Principais](#componentes-principais)
- [Exemplos](#exemplos)
- [Arquitetura](#arquitetura)
- [Boas Práticas](#boas-práticas)
- [Dependências](#dependências)
- [Estrutura do Projeto](#estrutura-do-projeto)

## ✨ Características

- ✅ **Acesso ODBC**: Conexão com bancos de dados via ODBC
- ✅ **Múltiplos Bancos**: Suporte para SQL Server, PostgreSQL, Sybase Anywhere
- ✅ **Queries Parametrizadas**: Proteção contra SQL Injection
- ✅ **Transações**: Suporte completo a transações com commit/rollback
- ✅ **Connection Pooling**: Gerenciamento eficiente de conexões
- ✅ **Safe Select Builder**: Construção segura de queries evitando erros com colunas binárias
- ✅ **Table Metadata**: Consulta de metadados de tabelas
- ✅ **Error Handling**: Tratamento de erros usando `result_dart`
- ✅ **Type Safety**: Tipagem forte para parâmetros e campos
- ✅ **Clean Architecture**: Estrutura organizada seguindo princípios SOLID

## 📦 Requisitos

- Flutter SDK 3.5.4 ou superior
- Dart SDK 3.5.4 ou superior
- Driver ODBC instalado no sistema (ex: SQL Server Native Client)
- Windows (suporte para outros sistemas pode variar)

## 🚀 Instalação

1. Adicione as dependências ao seu `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  dart_odbc: ^6.2.0
  result_dart: ^2.1.1
  uuid: ^4.5.2
```

2. Execute:

```bash
flutter pub get
```

## ⚙️ Configuração

### Configurar Driver ODBC

Antes de usar, certifique-se de que o driver ODBC está instalado e configurado no sistema:

- **SQL Server**: Instale o SQL Server Native Client ou ODBC Driver for SQL Server
- **PostgreSQL**: Instale o PostgreSQL ODBC Driver (psqlODBC)
- **Sybase Anywhere**: Instale o driver ODBC do Sybase

## 📖 Uso Básico

### 1. Configurar Conexão

```dart
import 'package:demo_odbc/dao/config/database_config.dart';

final config = DatabaseConfig.sqlServer(
  driverName: 'SQL Server Native Client 11.0',
  username: 'sa',
  password: 'password',
  database: 'database_name',
  server: 'SERVER_NAME',
  port: 1433,
);
```

### 2. Executar SELECT

```dart
import 'package:demo_odbc/dao/sql_command.dart';
import 'package:result_dart/result_dart.dart';

final query = SqlCommand(config);

final result = await query.connect().flatMap((_) async {
  query.commandText = '''
    SELECT CodCliente, Nome, Observacao 
    FROM Cliente WITH (NOLOCK)
    WHERE CodCliente > :CodCliente
  ''';
  
  query.param('CodCliente').asInt = 1;
  
  return await query.open();
});

result.fold(
  (success) {
    while (!query.eof) {
      print(query.field("CodCliente").asInt);
      print(query.field("Nome").asString);
      query.next();
    }
  },
  (failure) {
    print('Erro: $failure');
  },
);

await query.close();
```

### 3. Executar INSERT/UPDATE/DELETE

```dart
final query = SqlCommand(config);

await query.connect().flatMap((_) {
  query.commandText = '''
    UPDATE Cliente 
    SET Observacao = :observacao 
    WHERE CodCliente = :codCliente
  ''';
  
  query.param('codCliente').asInt = 1;
  query.param('observacao').asString = 'Nova observação';
  
  return query.execute();
}).fold(
  (success) => print('Update realizado com sucesso!'),
  (failure) => print('Erro: $failure'),
);

await query.close();
```

## 🧩 Componentes Principais

### DatabaseConfig

Configuração de conexão com o banco de dados.

```dart
// SQL Server
final config = DatabaseConfig.sqlServer(
  driverName: 'SQL Server Native Client 11.0',
  username: 'sa',
  password: 'password',
  database: 'database_name',
  server: 'SERVER_NAME',
  port: 1433,
);

// PostgreSQL
final config = DatabaseConfig.postgresql(
  driverName: 'PostgreSQL Unicode',
  username: 'postgres',
  password: 'password',
  database: 'database_name',
  server: 'localhost',
  port: 5432,
);

// Sybase Anywhere
final config = DatabaseConfig.sybaseAnywhere(
  driverName: 'Sybase Anywhere',
  username: 'dba',
  password: 'password',
  database: 'database_name',
  server: 'SERVER_NAME',
  port: 2638,
);
```

### SqlCommand

Classe principal para execução de comandos SQL.

**Métodos principais:**
- `connect()`: Conecta ao banco de dados
- `open()`: Executa SELECT e abre cursor
- `execute()`: Executa INSERT/UPDATE/DELETE
- `param(name)`: Define parâmetro para query
- `field(name)`: Acessa campo do registro atual
- `next()`: Move para próximo registro
- `close()`: Fecha conexão e libera recursos

**Tipos de parâmetros:**
```dart
query.param('id').asInt = 1;
query.param('name').asString = 'John';
query.param('price').asDouble = 99.99;
query.param('active').asBool = true;
query.param('date').asDateTime = DateTime.now();
```

**Tipos de campos:**
```dart
int id = query.field('id').asInt;
String name = query.field('name').asString;
double price = query.field('price').asDouble;
bool active = query.field('active').asBool;
DateTime date = query.field('date').asDateTime;
```

### SqlTransaction

Gerenciamento de transações.

```dart
final transaction = SqlTransaction(query.odbc);

await transaction.start();
try {
  // Executar comandos
  await query.execute();
  await transaction.commit();
} catch (e) {
  await transaction.rollback();
  rethrow;
}
```

### SafeSelectBuilder

Constrói queries SELECT seguras, evitando erros com colunas binárias (IMAGE, VARBINARY) e aplicando CAST em colunas LOB grandes.

```dart
final metadata = TableMetadata(query.odbc);
final safeBuilder = SafeSelectBuilder(metadata);

// Obter colunas seguras (exclui IMAGE/VARBINARY automaticamente)
final safeColsResult = await safeBuilder.getSafeColumns('Cliente');
if (safeColsResult.isError()) throw safeColsResult.exceptionOrNull()!;
final safeCols = safeColsResult.getOrThrow();

// Usar em query
query.commandText = 'SELECT $safeCols FROM Cliente';

// Ou usar método de conveniência
final queryResult = await safeBuilder.buildSafely('Cliente', withNoLock: true);
if (queryResult.isSuccess()) {
  query.commandText = queryResult.getOrThrow();
}

// Paginação (SQL Server 2012+)
final paginatedResult = await safeBuilder.buildPaginated(
  'Cliente',
  orderBy: 'CodCliente',
  page: 1,
  pageSize: 100,
  withNoLock: true,
);
```

### TableMetadata

Consulta metadados de tabelas.

```dart
final metadata = TableMetadata(query.odbc);
final columnsResult = await metadata.getColumns('Cliente');

columnsResult.fold(
  (columns) {
    for (final column in columns) {
      print('${column['name']}: ${column['type']}');
    }
  },
  (failure) {
    print('Erro: $failure');
  },
);
```

### OdbcConnectionPool

Pool de conexões para melhor performance.

```dart
final pool = OdbcConnectionPool();
pool.init(config, maxSize: 10);

// Adquirir conexão
final driverResult = await pool.acquire();
driverResult.fold(
  (driver) {
    // Usar driver
    final query = SqlCommand.fromDriver(driver);
    // ... operações
    // Liberar conexão
    pool.release(driver);
  },
  (failure) {
    print('Erro ao adquirir conexão: $failure');
  },
);

// Fechar todas as conexões
await pool.closeAll();
```

## 💡 Exemplos

### Exemplo Completo: SELECT com Safe Builder

```dart
import 'package:demo_odbc/dao/sql_command.dart';
import 'package:demo_odbc/dao/config/database_config.dart';
import 'package:demo_odbc/dao/safe_select_builder.dart';
import 'package:demo_odbc/dao/table_metadata.dart';
import 'package:result_dart/result_dart.dart';

Future<void> exemploSelect() async {
  final config = DatabaseConfig.sqlServer(
    driverName: 'SQL Server Native Client 11.0',
    username: 'sa',
    password: 'password',
    database: 'NSE',
    server: 'SERVER_NAME',
    port: 1433,
  );

  final query = SqlCommand(config);

  final result = await query.connect().flatMap((_) async {
    // Usar Safe Select Builder
    final metadata = TableMetadata(query.odbc);
    final safeBuilder = SafeSelectBuilder(metadata);

    final safeColsResult = await safeBuilder.getSafeColumns('Cliente');
    if (safeColsResult.isError()) {
      throw safeColsResult.exceptionOrNull()!;
    }
    final safeCols = safeColsResult.getOrThrow();

    query.commandText = '''
      SELECT $safeCols 
      FROM Cliente WITH (NOLOCK)
      WHERE CodCliente > :CodCliente
    ''';

    query.param('CodCliente').asInt = 1;

    return await query.open();
  });

  result.fold(
    (success) {
      while (!query.eof) {
        print('ID: ${query.field("CodCliente").asInt}');
        print('Nome: ${query.field("Nome").asString}');
        query.next();
      }
      print('Total: ${query.recordCount}');
    },
    (failure) {
      print('Erro: $failure');
    },
  );

  await query.close();
}
```

### Exemplo: Transação

```dart
Future<void> exemploTransacao() async {
  final config = DatabaseConfig.sqlServer(/* ... */);
  final query = SqlCommand(config);

  await query.connect().flatMap((_) async {
    final transaction = query.transaction!;
    
    await transaction.start();
    
    try {
      // Primeiro comando
      query.commandText = '''
        UPDATE Cliente 
        SET Observacao = :obs 
        WHERE CodCliente = :id
      ''';
      query.param('id').asInt = 1;
      query.param('obs').asString = 'Atualizado';
      await query.execute();

      // Segundo comando
      query.commandText = '''
        INSERT INTO Log (Mensagem, Data) 
        VALUES (:msg, :data)
      ''';
      query.param('msg').asString = 'Cliente atualizado';
      query.param('data').asDateTime = DateTime.now();
      await query.execute();

      await transaction.commit();
      return Success.unit();
    } catch (e) {
      await transaction.rollback();
      return Failure(Exception(e.toString()));
    }
  }).fold(
    (success) => print('Transação concluída'),
    (failure) => print('Erro: $failure'),
  );

  await query.close();
}
```

### Exemplo: Paginação

```dart
Future<void> exemploPaginacao() async {
  final config = DatabaseConfig.sqlServer(/* ... */);
  final query = SqlCommand(config);

  await query.connect().flatMap((_) async {
    final metadata = TableMetadata(query.odbc);
    final safeBuilder = SafeSelectBuilder(metadata);

    final paginatedResult = await safeBuilder.buildPaginated(
      'Cliente',
      orderBy: 'CodCliente',
      page: 1,
      pageSize: 50,
      withNoLock: true,
    );

    if (paginatedResult.isError()) {
      throw paginatedResult.exceptionOrNull()!;
    }

    query.commandText = paginatedResult.getOrThrow();
    return await query.open();
  }).fold(
    (success) {
      while (!query.eof) {
        print(query.field("Nome").asString);
        query.next();
      }
    },
    (failure) => print('Erro: $failure'),
  );

  await query.close();
}
```

## 🏗️ Arquitetura

O projeto segue os princípios de Clean Architecture e SOLID:

- **DAO Pattern**: Abstração de acesso a dados
- **Strategy Pattern**: Diferentes drivers de banco
- **Object Pool Pattern**: Gerenciamento de conexões
- **Builder Pattern**: Construção segura de queries
- **Result Pattern**: Tratamento de erros funcional

### Estrutura de Camadas

```
lib/
├── dao/
│   ├── config/          # Configuração de conexão
│   ├── driver/          # Drivers ODBC
│   ├── pool/            # Connection pooling
│   ├── utils/           # Utilitários
│   ├── sql_command.dart      # Comandos SQL
│   ├── sql_transaction.dart  # Transações
│   ├── safe_select_builder.dart  # Builder seguro
│   └── table_metadata.dart      # Metadados
└── main.dart            # Exemplos
```

## ✅ Boas Práticas

### 1. Sempre use queries parametrizadas

```dart
// ✅ Correto
query.commandText = 'SELECT * FROM Users WHERE Id = :id';
query.param('id').asInt = userId;

// ❌ Incorreto (SQL Injection)
query.commandText = 'SELECT * FROM Users WHERE Id = $userId';
```

### 2. Sempre feche conexões

```dart
try {
  await query.connect();
  // ... operações
} finally {
  await query.close();
}
```

### 3. Use SafeSelectBuilder para evitar erros com colunas binárias

```dart
final safeBuilder = SafeSelectBuilder(metadata);
final safeCols = await safeBuilder.getSafeColumns('TableName');
```

### 4. Use Result pattern para tratamento de erros

```dart
final result = await query.open();
result.fold(
  (success) { /* sucesso */ },
  (failure) { /* erro */ },
);
```

### 5. Use transações para operações múltiplas

```dart
await transaction.start();
try {
  // múltiplas operações
  await transaction.commit();
} catch (e) {
  await transaction.rollback();
}
```

## 📚 Dependências

- **dart_odbc** (^6.2.0): Driver ODBC para Dart
- **result_dart** (^2.1.1): Tratamento funcional de erros
- **uuid** (^4.5.2): Geração de UUIDs

## 📁 Estrutura do Projeto

```
demo_odbc/
├── lib/
│   ├── dao/
│   │   ├── config/
│   │   │   ├── database_config.dart
│   │   │   └── database_type.dart
│   │   ├── driver/
│   │   │   ├── database_driver.dart
│   │   │   ├── database_error.dart
│   │   │   ├── my_odbc.dart
│   │   │   ├── smart_prepared_statement.dart
│   │   │   └── sql_data_type.dart
│   │   ├── pool/
│   │   │   └── odbc_connection_pool.dart
│   │   ├── utils/
│   │   │   └── schema_utils.dart
│   │   ├── safe_select_builder.dart
│   │   ├── sql_command.dart
│   │   ├── sql_transaction.dart
│   │   ├── sql_type_command.dart
│   │   ├── sql_valid_command.dart
│   │   └── table_metadata.dart
│   └── main.dart
├── pubspec.yaml
└── README.md
```

## 🔧 Troubleshooting

### Erro HY001 com colunas IMAGE/VARBINARY

Use `SafeSelectBuilder` para excluir automaticamente essas colunas:

```dart
final safeBuilder = SafeSelectBuilder(metadata);
final safeCols = await safeBuilder.getSafeColumns('TableName');
```

### Erro de conexão

Verifique:
- Driver ODBC instalado
- Credenciais corretas
- Servidor acessível
- Porta correta

### Performance

Use `OdbcConnectionPool` para múltiplas operações:

```dart
final pool = OdbcConnectionPool();
pool.init(config, maxSize: 10);
```

## 📝 Licença

Este projeto é fornecido como está, para uso educacional e de demonstração.

## 👤 Autor

Cesar Carlos

## 🔗 Links

- [dart_odbc](https://pub.dev/packages/dart_odbc)
- [result_dart](https://pub.dev/packages/result_dart)
- [Flutter](https://flutter.dev)
