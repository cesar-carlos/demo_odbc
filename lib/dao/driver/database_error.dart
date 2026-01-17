sealed class DatabaseError implements Exception {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  DatabaseError(this.message, [this.originalError, this.stackTrace]);

  @override
  String toString() {
    if (originalError != null) {
      return '$runtimeType: $message\nOriginal error: $originalError';
    }
    return '$runtimeType: $message';
  }
}

class ConnectionError extends DatabaseError {
  ConnectionError(super.message, [super.originalError, super.stackTrace]);
}

class QueryError extends DatabaseError {
  final String? query;

  QueryError(String message,
      {this.query, Object? originalError, StackTrace? stackTrace})
      : super(message, originalError, stackTrace);

  @override
  String toString() {
    return '${super.toString()}\nQuery: $query';
  }
}

class TransactionError extends DatabaseError {
  TransactionError(super.message, [super.originalError, super.stackTrace]);
}
