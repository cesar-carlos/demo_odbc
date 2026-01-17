import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/driver/database_driver.dart';

class SqlTransaction {
  bool _autoCommit = true;
  bool _isOpen = false;
  int _transactionDepth = 0;
  final DatabaseDriver _connection;

  SqlTransaction(this._connection);

  void onAutoCommit() {
    _autoCommit = true;
  }

  void offAutoCommit() {
    _autoCommit = false;
  }

  bool get autoCommit => _autoCommit;

  bool isOpen() {
    return _isOpen;
  }

  Future<Result<Unit>> start({bool isSelect = false}) async {
    if (isSelect) {
      return Success.unit();
    }

    if (_transactionDepth == 0) {
      final result = await _connection.startTransaction();
      if (result.isError()) {
        return result;
      }
      _isOpen = true;
    }

    _transactionDepth++;
    return Success.unit();
  }

  Future<Result<Unit>> commit() async {
    if (_transactionDepth > 0) {
      _transactionDepth--;
    }

    if (_transactionDepth == 0 && _isOpen) {
      final result = await _connection.commitTransaction();
      if (result.isSuccess()) {
        _isOpen = false;
      }
      return result;
    }

    return Success.unit();
  }

  Future<Result<Unit>> rollback() async {
    if (_isOpen) {
      final result = await _connection.rollbackTransaction();

      _isOpen = false;
      _transactionDepth = 0;
      return result;
    }
    return Success.unit();
  }

  Future<Result<Unit>> doAutoCommit() async {
    if (_autoCommit && _isOpen) {
      return commit();
    }
    return Success.unit();
  }

  Future<Result<Unit>> doAutoRollback() async {
    if (_autoCommit && _isOpen) {
      return rollback();
    }
    return Success.unit();
  }
}
