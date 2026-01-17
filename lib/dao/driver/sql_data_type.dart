import 'dart:core';

/// Enum que representa os tipos de dados SQL suportados.
///
/// **Compatibilidade entre bancos:**
/// - **SQL Server**: Suporta todos os tipos. `nvarchar` e `datetime2` são específicos do SQL Server.
/// - **Sybase Anywhere**: Suporta tipos similares ao SQL Server. `nvarchar` e `nchar` são suportados.
/// - **PostgreSQL**:
///   - Não possui `nvarchar` ou `nchar` nativamente (usa `varchar`/`char` com encoding UTF-8).
///   - Não possui `datetime2` (usa `timestamp` ou `timestamp with time zone`).
///   - Não possui `image` (usa `bytea` para dados binários grandes).
///   - `money` existe, mas recomendado usar `numeric` ou `decimal`.
///
/// Nota: O mapeamento para `ColumnType` ODBC é universal e funciona com todos os bancos suportados.
enum SqlDataType {
  varchar,
  nvarchar,
  char,
  nchar,
  datetime,
  datetime2,
  date,
  decimal,
  numeric,
  integer,
  bigint,
  bit,
  float,
  money,
  binary,
  varbinary,
  image,
  unknown;

  static SqlDataType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'varchar':
        return SqlDataType.varchar;
      case 'nvarchar':
        return SqlDataType.nvarchar;
      case 'char':
        return SqlDataType.char;
      case 'nchar':
        return SqlDataType.nchar;
      case 'datetime':
        return SqlDataType.datetime;
      case 'datetime2':
        return SqlDataType.datetime2;
      case 'date':
        return SqlDataType.date;
      case 'decimal':
        return SqlDataType.decimal;
      case 'numeric':
        return SqlDataType.numeric;
      case 'int':
        return SqlDataType.integer;
      case 'bigint':
        return SqlDataType.bigint;
      case 'bit':
        return SqlDataType.bit;
      case 'float':
        return SqlDataType.float;
      case 'money':
        return SqlDataType.money;
      case 'binary':
        return SqlDataType.binary;
      case 'varbinary':
        return SqlDataType.varbinary;
      case 'image':
        return SqlDataType.image;
      default:
        return SqlDataType.unknown;
    }
  }

}
