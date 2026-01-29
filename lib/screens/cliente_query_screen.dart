import 'package:flutter/material.dart';
import 'package:result_dart/result_dart.dart';

import 'package:demo_odbc/dao/config/database_config.dart';
import 'package:demo_odbc/dao/sql_command.dart';

/// Tela com formulário de conexão, editor de consulta (SELECT) e grid dinâmica
/// com o resultado e métricas.
class ClienteQueryScreen extends StatefulWidget {
  const ClienteQueryScreen({super.key});

  @override
  State<ClienteQueryScreen> createState() => _ClienteQueryScreenState();
}

class _ClienteQueryScreenState extends State<ClienteQueryScreen> {
  // Conexão
  final _driverController = TextEditingController(
    text: 'SQL Server Native Client 11.0',
  );
  final _serverController = TextEditingController(text: r'CESAR_CARLOS\DATA7');
  final _portController = TextEditingController(text: '1433');
  final _databaseController = TextEditingController(text: 'Estacao');
  final _usernameController = TextEditingController(text: 'sa');
  final _passwordController = TextEditingController(text: '123abc.');

  // Consulta
  final _queryController = TextEditingController(
    text: 'SELECT TOP 500 * FROM Cliente ORDER BY 1',
  );

  SqlCommand? _command;
  List<Map<String, dynamic>> _rows = [];
  List<String> _columnNames = [];
  bool _loading = false;
  String? _error;
  int _connectionTimeMs = 0;
  int _queryTimeMs = 0;
  bool _connectionExpanded = true;

  static const _pageSizeOptions = [50, 100, 200, 500];
  int _pageSize = 50;
  int _pageIndex = 0;

  late final ScrollController _gridVerticalScrollController;
  late final ScrollController _gridHorizontalScrollController;

  @override
  void initState() {
    super.initState();
    _gridVerticalScrollController = ScrollController();
    _gridHorizontalScrollController = ScrollController();
  }

  int get _totalPages => _rows.isEmpty ? 0 : (_rows.length / _pageSize).ceil();

  List<Map<String, dynamic>> get _displayedRows {
    if (_rows.isEmpty) return [];
    final start = _pageIndex * _pageSize;
    if (start >= _rows.length) return [];
    final end = (start + _pageSize).clamp(0, _rows.length);
    return _rows.sublist(start, end);
  }

  @override
  void dispose() {
    _driverController.dispose();
    _serverController.dispose();
    _portController.dispose();
    _databaseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _queryController.dispose();
    _gridVerticalScrollController.dispose();
    _gridHorizontalScrollController.dispose();
    _command?.close();
    super.dispose();
  }

  DatabaseConfig _buildConfig() {
    final port = int.tryParse(_portController.text.trim()) ?? 1433;
    return DatabaseConfig.sqlServer(
      driverName: _driverController.text.trim(),
      server: _serverController.text.trim(),
      port: port,
      database: _databaseController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      maxResultBufferBytes: 64 * 1024 * 1024,
    );
  }

  static const _timeoutSeconds = 90;

  void _runQuery() {
    final sql = _queryController.text.trim();
    if (sql.isEmpty) {
      setState(() => _error = 'Digite uma consulta SELECT.');
      return;
    }
    if (sql.toUpperCase().contains('DELETE') ||
        sql.toUpperCase().contains('UPDATE') ||
        sql.toUpperCase().contains('INSERT') ||
        sql.toUpperCase().contains('DROP')) {
      setState(
          () => _error = 'Apenas consultas SELECT são permitidas nesta tela.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _rows = [];
      _columnNames = [];
      _connectionTimeMs = 0;
      _queryTimeMs = 0;
    });

    // Executa a query após o próximo frame para a UI mostrar o loading antes de bloquear
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executeQuery(sql);
    });
  }

  Future<void> _executeQuery(String sql) async {
    SqlCommand? command;
    try {
      final config = _buildConfig();
      command = SqlCommand(config);
      command.commandText = sql;
      // Evita bloqueio na tabela: consulta roda com READ UNCOMMITTED (não adquire locks).
      command.enableReadUncommitted();

      final stopwatchConnect = Stopwatch()..start();
      final connectResult = await command.connect().timeout(
          const Duration(seconds: _timeoutSeconds),
          onTimeout: () => Failure(Exception(
              'Timeout de conexão (${_timeoutSeconds}s). Verifique servidor, rede e firewall.')));
      final connectionTimeMs = stopwatchConnect.elapsedMilliseconds;

      if (connectResult.isError()) {
        _setError(_userMessage(connectResult.exceptionOrNull()), command);
        return;
      }

      final stopwatchQuery = Stopwatch()..start();
      final openResult = await command.open().timeout(
          const Duration(seconds: _timeoutSeconds),
          onTimeout: () => Failure(Exception(
              'Timeout na consulta (${_timeoutSeconds}s). Reduza o resultado (ex: TOP 100) ou verifique a rede.')));
      final queryTimeMs = stopwatchQuery.elapsedMilliseconds;

      openResult.fold(
        (_) {
          List<String> columnNames = [];
          if (command!.rows.isNotEmpty) {
            columnNames = command.rows.first.keys
                .map((k) => k.toString())
                .where((k) => k.isNotEmpty)
                .toList();
          }
          if (mounted) {
            final oldCommand = _command;
            setState(() {
              _command = command;
              _rows = command!.rows;
              _columnNames = columnNames;
              _connectionTimeMs = connectionTimeMs;
              _queryTimeMs = queryTimeMs;
              _loading = false;
              _pageIndex = 0;
            });
            oldCommand?.close();
          }
        },
        (failure) async {
          _setError(_userMessage(failure), command);
          await command?.close();
        },
      );
    } catch (e, _) {
      _setError(_userMessage(e), command);
      await command?.close();
    }
  }

  String _userMessage(dynamic e) {
    if (e == null) return 'Erro desconhecido.';
    final s = e.toString();
    // Mostra só a primeira linha ou mensagem curta para o usuário
    final firstLine = s.split('\n').first.trim();
    if (firstLine.length > 200) return '${firstLine.substring(0, 197)}...';
    return firstLine;
  }

  void _setError(String message, SqlCommand? command) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Fechar',
          textColor: Theme.of(context).colorScheme.onError,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consulta ODBC'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 0,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildConnectionCard(),
                  _buildQueryCard(),
                  if (_error != null) _buildErrorBanner(),
                ],
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty && _error == null
                    ? _buildEmptyState()
                    : _error != null
                        ? _buildErrorView()
                        : _buildResultSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: ExpansionTile(
        initiallyExpanded: _connectionExpanded,
        onExpansionChanged: (v) => setState(() => _connectionExpanded = v),
        title: const Text('Dados da conexão',
            style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _driverController,
                    decoration: const InputDecoration(
                      labelText: 'Driver ODBC',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _serverController,
                    decoration: const InputDecoration(
                      labelText: 'Servidor',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Porta',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _databaseController,
                    decoration: const InputDecoration(
                      labelText: 'Database',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Usuário',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueryCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Consulta (SELECT)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 8),
            TextField(
              controller: _queryController,
              maxLines: 4,
              minLines: 2,
              decoration: const InputDecoration(
                hintText: 'SELECT * FROM SuaTabela ORDER BY 1',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _runQuery,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Executar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        border: Border.all(
          color: Theme.of(context).colorScheme.error,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _error = null),
            color: Theme.of(context).colorScheme.onErrorContainer,
            tooltip: 'Fechar',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_chart_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Preencha a conexão e a consulta e clique em Executar.',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _runQuery,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMetricsCard(),
        const SizedBox(height: 8),
        if (_rows.length > _pageSize) _buildPaginationBar(),
        const SizedBox(height: 4),
        Expanded(
          child: _buildGrid(),
        ),
      ],
    );
  }

  Widget _buildPaginationBar() {
    final start = _pageIndex * _pageSize + 1;
    final end = (start + _pageSize - 1).clamp(0, _rows.length);
    final canPrev = _pageIndex > 0;
    final canNext = _pageIndex < _totalPages - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(
            'Registros $start–$end de ${_rows.length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 16),
          DropdownButton<int>(
            value: _pageSize > 0 && _pageSizeOptions.contains(_pageSize)
                ? _pageSize
                : _pageSizeOptions.first,
            items: _pageSizeOptions
                .map((s) =>
                    DropdownMenuItem(value: s, child: Text('$s por página')))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                final newTotal = (_rows.length / v).ceil();
                _pageIndex = (_pageIndex * _pageSize ~/ v)
                    .clamp(0, newTotal > 0 ? newTotal - 1 : 0);
                _pageSize = v;
              });
            },
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: canPrev
                ? () => setState(() =>
                    _pageIndex = (_pageIndex - 1).clamp(0, _totalPages - 1))
                : null,
            tooltip: 'Página anterior',
          ),
          Text(
            'Página ${_pageIndex + 1} de $_totalPages',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: canNext
                ? () => setState(() =>
                    _pageIndex = (_pageIndex + 1).clamp(0, _totalPages - 1))
                : null,
            tooltip: 'Próxima página',
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _metricChip(Icons.table_rows, 'Registros', '${_rows.length}'),
            _metricChip(Icons.link, 'Conexão', '$_connectionTimeMs ms'),
            _metricChip(Icons.query_builder, 'Consulta', '$_queryTimeMs ms'),
            if (_queryTimeMs > 0 && _rows.isNotEmpty)
              _metricChip(
                Icons.speed,
                'Throughput',
                '${(_rows.length / (_queryTimeMs / 1000)).toStringAsFixed(1)}/s',
              ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(IconData icon, String label, String value) {
    return Chip(
      avatar:
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      label: Text('$label: $value'),
    );
  }

  Widget _buildGrid() {
    if (_columnNames.isEmpty) {
      return const Center(child: Text('Nenhuma coluna no resultado.'));
    }
    final rowsToShow = _displayedRows;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _gridHorizontalScrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _gridHorizontalScrollController,
          scrollDirection: Axis.horizontal,
          child: Scrollbar(
            controller: _gridVerticalScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _gridVerticalScrollController,
              scrollDirection: Axis.vertical,
              child: DataTable(
                columns: _columnNames
                    .map((name) => DataColumn(
                          label: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ))
                    .toList(),
                rows: rowsToShow
                    .map((row) => DataRow(
                          cells: _columnNames
                              .map((col) => DataCell(
                                    Tooltip(
                                      message: _cellText(row[col]),
                                      child: Text(
                                        _cellText(row[col]),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _cellText(dynamic value) {
    if (value == null) return '—';
    if (value is DateTime) return value.toIso8601String().split('.').first;
    return value.toString();
  }
}
