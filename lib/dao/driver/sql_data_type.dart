import 'dart:core';

/// Enum representing supported SQL data types.
///
/// **Database compatibility:**
/// - **SQL Server**: Supports all types. `nvarchar` and `datetime2` are SQL Server specific.
/// - **Sybase Anywhere**: Supports types similar to SQL Server. `nvarchar` and `nchar` are supported.
/// - **PostgreSQL**:
///   - Does not have `nvarchar` or `nchar` natively (uses `varchar`/`char` with UTF-8 encoding).
///   - Does not have `datetime2` (uses `timestamp` or `timestamp with time zone`).
///   - Does not have `image` (uses `bytea` for large binary data).
///   - `money` exists, but recommended to use `numeric` or `decimal`.
///
/// Note: The mapping to ODBC `ColumnType` is universal and works with all supported databases.
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
