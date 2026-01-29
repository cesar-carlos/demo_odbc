# demo_odbc

Biblioteca Flutter/Dart para acesso a bancos de dados via ODBC, fornecendo uma camada de abstração limpa e segura para operações SQL com suporte a SQL Server, PostgreSQL, Sybase Anywhere e outros bancos compatíveis com ODBC.

## 📋 Índice

- [Características](#características)
- [Requisitos](#requisitos)
- [Instalação](#instalação)
- [Configuração](#configuração)
- [Uso Básico](#uso-básico)
- [Componentes Principais](#componentes-principais)
- [Exemplos Completos](#exemplos-completos)
  - [1. SELECT - Consultas](#1-select---consultas)
  - [2. INSERT - Inserção de Dados](#2-insert---inserção-de-dados)
  - [3. UPDATE - Atualização de Dados](#3-update---atualização-de-dados)
  - [4. DELETE - Exclusão de Dados](#4-delete---exclusão-de-dados)
  - [5. CREATE TABLE - Criação de Tabelas](#5-create-table---criação-de-tabelas)
  - [6. ALTER TABLE - Alteração de Tabelas](#6-alter-table---alteração-de-tabelas)
  - [7. Transações](#7-transações)
  - [8. Verificações de Schema](#8-verificações-de-schema)
  - [9. SELECT com Paginação](#9-select-com-paginação-sql-server-2012)
  - [10. Consulta de Metadados](#10-consulta-de-metadados)
  - [11. Exemplos Avançados](#11-exemplos-avançados)
  - [12. Operações DDL Adicionais](#12-operações-ddl-adicionais)
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
- ✅ **Table Metadata**: Consulta de metadados de tabelas
- ✅ **Error Handling**: Tratamento de erros usando `result_dart`
- ✅ **Type Safety**: Tipagem forte para parâmetros e campos
- ✅ **Clean Architecture**: Estrutura organizada seguindo princípios SOLID
- ✅ **Performance Otimizado**: Motor ODBC nativo (odbc_fast) com streaming e pooling

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
  odbc_fast: ^0.3.0
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
    SELECT *
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
      print(query.field("DataCadastro").asString); // DATETIME convertido para VARCHAR(50)
      query.next();
    }
  },
  (failure) {
    print('Erro: $failure');
  },
);

await query.close();
```

**O que acontece automaticamente:**

- `SELECT *` → Todas as colunas recebem CAST inteligente baseado em metadados
- Colunas Unicode (NVARCHAR/NCHAR) → `CAST(coluna AS NVARCHAR(tamanho))`
- Colunas não-Unicode (VARCHAR/CHAR) → `CAST(coluna AS VARCHAR(tamanho))`
- Colunas binárias (IMAGE/VARBINARY) → `CAST(coluna AS VARCHAR(MAX))`
- Tipos numéricos/temporais → `CAST(coluna AS VARCHAR(tamanho_otimizado))`
- Cache de metadados (8 minutos) para máxima performance

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

## 💡 Exemplos Completos

### 1. SELECT - Consultas

#### SELECT com Interceptor Automático (Recomendado)

O interceptor funciona automaticamente, aplicando CAST inteligente em todos os SELECTs:

O interceptor funciona automaticamente, aplicando CAST inteligente em todos os SELECTs:

```dart
import 'package:demo_odbc/dao/sql_command.dart';
import 'package:demo_odbc/dao/config/database_config.dart';
import 'package:result_dart/result_dart.dart';

Future<void> exemploSelectAutomatico() async {
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
    // SELECT * - Interceptor aplica CAST automaticamente em todas as colunas
    query.commandText = '''
      SELECT *
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
        print('Data: ${query.field("DataCadastro").asString}');
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

**Vantagens:**

- ✅ Não precisa mudar seu código
- ✅ CAST automático baseado em metadados
- ✅ Cache de metadados (8 minutos) para performance
- ✅ Suporte Unicode (NVARCHAR) preservado
- ✅ Evita erros com colunas binárias

### Exemplo: SELECT com Colunas Específicas

O interceptor também funciona com SELECTs que especificam colunas:

```dart
final result = await query.connect().flatMap((_) async {
  // SELECT com colunas específicas - Interceptor aplica CAST inteligente
  query.commandText = '''
    SELECT Nome, Email, DataCadastro, Foto
    FROM Cliente
    WHERE CodCliente = :id
  ''';

  query.param('id').asInt = 1;
  return await query.open();
});

result.fold(
  (success) {
    while (!query.eof) {
      print('Nome: ${query.field("Nome").asString}');      // NVARCHAR preservado
      print('Email: ${query.field("Email").asString}');    // VARCHAR
      print('Data: ${query.field("DataCadastro").asString}'); // DATETIME → VARCHAR(50)
      print('Foto: ${query.field("Foto").asString}');      // IMAGE → VARCHAR(MAX)
      query.next();
    }
  },
  (failure) => print('Erro: $failure'),
);
```

#### SELECT com TOP (Limitar Resultados)

```dart
final result = await query.connect().flatMap((_) async {
  query.commandText = '''
    SELECT TOP 100
      CodProduto,
      Nome,
      DataCadastro
    FROM Produto
    ORDER BY CodProduto
  ''';

  return await query.open();
});

result.fold(
  (success) {
    while (!query.eof) {
      print('Produto: ${query.field("Nome").asString}');
      query.next();
    }
  },
  (failure) => print('Erro: $failure'),
);
```

#### SELECT com JOIN

```dart
final result = await query.connect().flatMap((_) async {
  query.commandText = '''
    SELECT
      c.CodCliente,
      c.Nome,
      p.CodProduto,
      p.NomeProduto
    FROM Cliente c
    INNER JOIN Pedido ped ON c.CodCliente = ped.CodCliente
    INNER JOIN Produto p ON ped.CodProduto = p.CodProduto
    WHERE c.CodCliente = :id
  ''';

  query.param('id').asInt = 1;
  return await query.open();
});

result.fold(
  (success) {
    while (!query.eof) {
      print('Cliente: ${query.field("Nome").asString}');
      print('Produto: ${query.field("NomeProduto").asString}');
      query.next();
    }
  },
  (failure) => print('Erro: $failure'),
);
```

#### SELECT com Stream (Grandes Volumes)

Para grandes volumes de dados, use `stream()` para processar linha a linha sem carregar tudo na memória:

```dart
import 'package:flutter/foundation.dart';

final result = await query.connect().flatMap((_) async {
  query.commandText = '''
    SELECT
      CodProduto,
      Nome,
      CodTipoProduto,
      CodUnidadeMedida,
      DataCadastro
    FROM Produto
  ''';

  return await query.stream(); // Retorna Stream ao invés de carregar tudo
});

try {
  result.fold(
    (stream) async {
      int recordCount = 0;

      await for (final record in stream) {
        recordCount++;

        // Processa cada registro individualmente
        final codProduto = record['CodProduto']?.toString();
        final nome = record['Nome']?.toString();

        // Exibe progresso a cada 1000 registros
        if (recordCount % 1000 == 0) {
          debugPrint('Processados $recordCount registros...');
        }
      }

      debugPrint('Total de registros processados: $recordCount');
    },
    (failure) {
      debugPrint('Erro no SELECT: $failure');
    },
  );
} catch (e, stackTrace) {
  debugPrint('Erro fatal durante processamento: $e');
  debugPrint('Stack trace: $stackTrace');
} finally {
  await query.close();
  debugPrint('Conexão fechada.');
}
```

**Vantagens do `stream()`:**

- ✅ Não carrega todos os resultados na memória de uma vez
- ✅ Processa linha por linha de forma assíncrona
- ✅ Mais eficiente para grandes volumes de dados
- ✅ Não precisa usar `query.next()` ou verificar `query.eof`

### 2. INSERT - Inserção de Dados

#### INSERT Simples

```dart
final result = await query.connect().flatMap((_) {
  query.commandText = '''
    INSERT INTO Cliente (Nome, Email, DataCadastro)
    VALUES (:nome, :email, :data)
  ''';

  query.param('nome').asString = 'João Silva';
  query.param('email').asString = 'joao@email.com';
  query.param('data').asDateTime = DateTime.now();

  return query.execute();
});

result.fold(
  (success) => print('Cliente inserido com sucesso!'),
  (failure) => print('Erro: $failure'),
);

await query.close();
```

#### INSERT com Retorno de ID (SQL Server)

```dart
final result = await query.connect().flatMap((_) async {
  query.commandText = '''
    INSERT INTO Cliente (Nome, Email, DataCadastro)
    OUTPUT INSERTED.CodCliente
    VALUES (:nome, :email, :data)
  ''';

  query.param('nome').asString = 'Maria Santos';
  query.param('email').asString = 'maria@email.com';
  query.param('data').asDateTime = DateTime.now();

  return await query.open();
});

result.fold(
  (success) {
    if (!query.eof) {
      final novoId = query.field('CodCliente').asInt;
      print('Novo cliente criado com ID: $novoId');
    }
  },
  (failure) => print('Erro: $failure'),
);
```

#### Bulk Insert (Inserção em Lote)

Para inserir múltiplos registros de uma vez:

```dart
final query = SqlCommand(config);
await query.connect();

final registros = [
  {'Nome': 'Cliente 1', 'Email': 'cliente1@email.com', 'Ativo': true},
  {'Nome': 'Cliente 2', 'Email': 'cliente2@email.com', 'Ativo': true},
  {'Nome': 'Cliente 3', 'Email': 'cliente3@email.com', 'Ativo': false},
];

final result = await query.bulkInsert('Cliente', registros, batchSize: 1000);

result.fold(
  (totalInseridos) => print('$totalInseridos registros inseridos com sucesso!'),
  (failure) => print('Erro: $failure'),
);

await query.close();
```

### 3. UPDATE - Atualização de Dados

#### UPDATE Simples

```dart
final result = await query.connect().flatMap((_) {
  query.commandText = '''
    UPDATE Cliente
    SET Nome = :nome,
        Email = :email,
        Observacao = :obs
    WHERE CodCliente = :id
  ''';

  query.param('id').asInt = 1;
  query.param('nome').asString = 'João Silva Atualizado';
  query.param('email').asString = 'joao.novo@email.com';
  query.param('obs').asString = 'Cliente atualizado em ${DateTime.now()}';

  return query.execute();
});

result.fold(
  (success) => print('Cliente atualizado com sucesso!'),
  (failure) => print('Erro: $failure'),
);

await query.close();
```

#### UPDATE com Múltiplas Condições

```dart
final result = await query.connect().flatMap((_) {
  query.commandText = '''
    UPDATE Produto
    SET PrecoVenda = :preco,
        DataPrecoVenda = :data
    WHERE CodProduto = :id
      AND Ativo = 1
      AND PrecoVenda <> :preco
  ''';

  query.param('id').asInt = 100;
  query.param('preco').asDouble = 99.99;
  query.param('data').asDateTime = DateTime.now();

  return query.execute();
});

result.fold(
  (success) => print('Preço atualizado!'),
  (failure) => print('Erro: $failure'),
);
```

### 4. DELETE - Exclusão de Dados

#### DELETE Simples

```dart
final result = await query.connect().flatMap((_) {
  query.commandText = '''
    DELETE FROM Cliente
    WHERE CodCliente = :id
  ''';

  query.param('id').asInt = 1;

  return query.execute();
});

result.fold(
  (success) => print('Cliente excluído com sucesso!'),
  (failure) => print('Erro: $failure'),
);

await query.close();
```

#### DELETE com Condições Múltiplas

```dart
final result = await query.connect().flatMap((_) {
  query.commandText = '''
    DELETE FROM Log
    WHERE Data < :dataLimite
      AND Tipo = :tipo
  ''';

  query.param('dataLimite').asDateTime = DateTime.now().subtract(Duration(days: 30));
  query.param('tipo').asString = 'INFO';

  return query.execute();
});

result.fold(
  (success) => print('Logs antigos excluídos!'),
  (failure) => print('Erro: $failure'),
);
```

### 5. CREATE TABLE - Criação de Tabelas

#### Criar Tabela Simples

```dart
final query = SqlCommand(config);
await query.connect();

final schema = SchemaUtils(query.odbc);

final result = await schema.createTable(
  'MinhaTabela',
  '''
  (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nome NVARCHAR(100) NOT NULL,
    Email VARCHAR(200),
    DataCadastro DATETIME DEFAULT GETDATE(),
    Ativo BIT DEFAULT 1
  )
  ''',
);

result.fold(
  (success) => print('Tabela criada com sucesso!'),
  (failure) => print('Erro: $failure'),
);

await query.close();
```

#### Verificar e Criar Tabela (Se Não Existir)

```dart
final schema = SchemaUtils(query.odbc);

final existeResult = await schema.tableExists('MinhaTabela');
existeResult.fold(
  (existe) async {
    if (!existe) {
      final createResult = await schema.createTable(
        'MinhaTabela',
        '(Id INT PRIMARY KEY, Nome VARCHAR(100))',
      );
      createResult.fold(
        (success) => print('Tabela criada!'),
        (failure) => print('Erro ao criar: $failure'),
      );
    } else {
      print('Tabela já existe!');
    }
  },
  (failure) => print('Erro ao verificar: $failure'),
);
```

### 6. ALTER TABLE - Alteração de Tabelas

#### Adicionar Coluna

```dart
final schema = SchemaUtils(query.odbc);

final result = await schema.ensureColumn(
  'Cliente',
  'Telefone',
  'VARCHAR(20) NULL',
);

result.fold(
  (success) => print('Coluna adicionada (ou já existia)!'),
  (failure) => print('Erro: $failure'),
);
```

#### Adicionar Coluna com Verificação Manual

```dart
final schema = SchemaUtils(query.odbc);

final existeResult = await schema.columnExists('Cliente', 'Telefone');
existeResult.fold(
  (existe) async {
    if (!existe) {
      final query = SqlCommand(config);
      await query.connect();

      final alterResult = await query.odbc.execute(
        'ALTER TABLE Cliente ADD Telefone VARCHAR(20) NULL',
      );

      alterResult.fold(
        (success) => print('Coluna adicionada!'),
        (failure) => print('Erro: $failure'),
      );

      await query.close();
    } else {
      print('Coluna já existe!');
    }
  },
  (failure) => print('Erro ao verificar: $failure'),
);
```

#### Modificar Tipo de Coluna

```dart
final query = SqlCommand(config);
await query.connect();

final result = await query.odbc.execute(
  'ALTER TABLE Cliente ALTER COLUMN Observacao NVARCHAR(MAX)',
);

result.fold(
  (success) => print('Coluna modificada!'),
  (failure) => print('Erro: $failure'),
);

await query.close();
```

#### Remover Coluna

```dart
final query = SqlCommand(config);
await query.connect();

final result = await query.odbc.execute(
  'ALTER TABLE Cliente DROP COLUMN Telefone',
);

result.fold(
  (success) => print('Coluna removida!'),
  (failure) => print('Erro: $failure'),
);

await query.close();
```

### 7. Transações

#### Transação Simples

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

#### Transação com Auto-Commit

```dart
final query = SqlCommand(config);
await query.connect();

query.onAutoCommit();

try {
  query.commandText = 'UPDATE Cliente SET Nome = :nome WHERE CodCliente = :id';
  query.param('id').asInt = 1;
  query.param('nome').asString = 'Novo Nome';
  await query.execute();

  query.commandText = 'INSERT INTO Log (Mensagem) VALUES (:msg)';
  query.param('msg').asString = 'Cliente atualizado';
  await query.execute();

  print('Operações concluídas com auto-commit!');
} finally {
  query.offAutoCommit();
  await query.close();
}
```

### 8. Verificações de Schema

#### Verificar se Tabela Existe

```dart
final schema = SchemaUtils(query.odbc);

final result = await schema.tableExists('Cliente');
result.fold(
  (existe) {
    if (existe) {
      print('Tabela Cliente existe!');
    } else {
      print('Tabela Cliente não existe!');
    }
  },
  (failure) => print('Erro: $failure'),
);
```

#### Verificar se Coluna Existe

```dart
final schema = SchemaUtils(query.odbc);

final result = await schema.columnExists('Cliente', 'Email');
result.fold(
  (existe) {
    if (existe) {
      print('Coluna Email existe!');
    } else {
      print('Coluna Email não existe!');
    }
  },
  (failure) => print('Erro: $failure'),
);
```

#### Verificar se View Existe

```dart
final schema = SchemaUtils(query.odbc);

final result = await schema.viewExists('VwClientesAtivos');
result.fold(
  (existe) => print(existe ? 'View existe!' : 'View não existe!'),
  (failure) => print('Erro: $failure'),
);
```

#### Verificar se Procedure Existe

```dart
final schema = SchemaUtils(query.odbc);

final result = await schema.procedureExists('sp_ObterCliente');
result.fold(
  (existe) => print(existe ? 'Procedure existe!' : 'Procedure não existe!'),
  (failure) => print('Erro: $failure'),
);
```

### 9. SELECT com Paginação (SQL Server 2012+)

```dart
final query = SqlCommand(config);
await query.connect();

query.commandText = '''
  SELECT CodCliente, Nome, Email
  FROM Cliente WITH (NOLOCK)
  ORDER BY CodCliente
  OFFSET 0 ROWS FETCH NEXT 50 ROWS ONLY
''';

final result = await query.open();
result.fold(
  (success) {
    while (!query.eof) {
      print(query.field("Nome").asString);
      query.next();
    }
  },
  (failure) => print('Erro: $failure'),
);

await query.close();
```

### 10. Consulta de Metadados

#### Obter Todas as Colunas de uma Tabela

```dart
final metadata = TableMetadata(query.odbc);

final result = await metadata.getColumns('Cliente');
result.fold(
  (columns) {
    for (final column in columns) {
      print('Coluna: ${column['name']}');
      print('Tipo: ${column['type']}');
      print('Tamanho: ${column['length']}');
      print('---');
    }
  },
  (failure) => print('Erro: $failure'),
);
```

### 11. Exemplos Avançados

#### SELECT com Subquery

```dart
final result = await query.connect().flatMap((_) async {
  query.commandText = '''
    SELECT
      c.CodCliente,
      c.Nome,
      (SELECT COUNT(*) FROM Pedido WHERE CodCliente = c.CodCliente) AS TotalPedidos
    FROM Cliente c
    WHERE c.Ativo = 1
  ''';

  return await query.open();
});

result.fold(
  (success) {
    while (!query.eof) {
      print('Cliente: ${query.field("Nome").asString}');
      print('Pedidos: ${query.field("TotalPedidos").asInt}');
      query.next();
    }
  },
  (failure) => print('Erro: $failure'),
);
```

#### SELECT com GROUP BY e HAVING

```dart
final result = await query.connect().flatMap((_) async {
  query.commandText = '''
    SELECT
      CodCliente,
      COUNT(*) AS TotalPedidos,
      SUM(Valor) AS ValorTotal
    FROM Pedido
    GROUP BY CodCliente
    HAVING COUNT(*) > :minPedidos
  ''';

  query.param('minPedidos').asInt = 5;
  return await query.open();
});

result.fold(
  (success) {
    while (!query.eof) {
      print('Cliente: ${query.field("CodCliente").asInt}');
      print('Pedidos: ${query.field("TotalPedidos").asInt}');
      print('Total: ${query.field("ValorTotal").asDouble}');
      query.next();
    }
  },
  (failure) => print('Erro: $failure'),
);
```

#### SELECT com ORDER BY e CASE

```dart
final result = await query.connect().flatMap((_) async {
  query.commandText = '''
    SELECT
      CodProduto,
      Nome,
      CASE
        WHEN PrecoVenda < 50 THEN 'Barato'
        WHEN PrecoVenda < 200 THEN 'Médio'
        ELSE 'Caro'
      END AS Categoria
    FROM Produto
    ORDER BY PrecoVenda DESC
  ''';

  return await query.open();
});

result.fold(
  (success) {
    while (!query.eof) {
      print('${query.field("Nome").asString}: ${query.field("Categoria").asString}');
      query.next();
    }
  },
  (failure) => print('Erro: $failure'),
);
```

### 12. Operações DDL Adicionais

#### DROP TABLE (Remover Tabela)

```dart
final query = SqlCommand(config);
await query.connect();

final result = await query.odbc.execute('DROP TABLE MinhaTabela');

result.fold(
  (success) => print('Tabela removida com sucesso!'),
  (failure) => print('Erro: $failure'),
);

await query.close();
```

#### CREATE INDEX (Criar Índice)

```dart
final query = SqlCommand(config);
await query.connect();

final result = await query.odbc.execute(
  'CREATE INDEX IX_Cliente_Nome ON Cliente(Nome)',
);

result.fold(
  (success) => print('Índice criado com sucesso!'),
  (failure) => print('Erro: $failure'),
);

await query.close();
```

#### CREATE VIEW (Criar View)

```dart
final query = SqlCommand(config);
await query.connect();

final result = await query.odbc.execute('''
  CREATE VIEW VwClientesAtivos AS
  SELECT CodCliente, Nome, Email
  FROM Cliente
  WHERE Ativo = 1
''');

result.fold(
  (success) => print('View criada com sucesso!'),
  (failure) => print('Erro: $failure'),
);

await query.close();
```

#### DROP VIEW (Remover View)

```dart
final query = SqlCommand(config);
await query.connect();

final result = await query.odbc.execute('DROP VIEW VwClientesAtivos');

result.fold(
  (success) => print('View removida com sucesso!'),
  (failure) => print('Erro: $failure'),
);

await query.close();
```

#### CREATE PROCEDURE (Criar Stored Procedure)

```dart
final query = SqlCommand(config);
await query.connect();

final result = await query.odbc.execute('''
  CREATE PROCEDURE sp_ObterCliente
    @CodCliente INT
  AS
  BEGIN
    SELECT * FROM Cliente WHERE CodCliente = @CodCliente
  END
''');

result.fold(
  (success) => print('Procedure criada com sucesso!'),
  (failure) => print('Erro: $failure'),
);

await query.close();
```

#### Executar Stored Procedure

```dart
final result = await query.connect().flatMap((_) async {
  query.commandText = 'EXEC sp_ObterCliente @CodCliente = :id';
  query.param('id').asInt = 1;
  return await query.open();
});

result.fold(
  (success) {
    while (!query.eof) {
      print('Cliente: ${query.field("Nome").asString}');
      query.next();
    }
  },
  (failure) => print('Erro: $failure'),
);
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

### 3. Use Result pattern para tratamento de erros

```dart
final result = await query.open();
result.fold(
  (success) { /* sucesso */ },
  (failure) { /* erro */ },
);
```

### 4. Use transações para operações múltiplas

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

- **odbc_fast** (^0.3.0): Plataforma ODBC com motor Rust nativo (buffer configurável via ConnectionOptions.maxResultBufferBytes)
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

### Erro de conexão

Verifique:

- Driver ODBC instalado
- Credenciais corretas
- Servidor acessível
- Porta correta

### Performance

**Connection Pooling:**
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
