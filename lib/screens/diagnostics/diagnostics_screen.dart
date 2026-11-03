import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import '../../services/log_service.dart';
import '../../services/firebase_service.dart';
import '../../services/orders_service.dart';
import '../../config/app_config.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  late final OrdersService _orders;
  final Set<String> _selectedCategories = {};
  List<LogEntry> _lastLogs = const [];

  @override
  void initState() {
    super.initState();
    _orders = OrdersService.instance;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Clear Logs',
            onPressed: () => setState(() => LogService.instance.clear()),
            icon: const Icon(Icons.delete_sweep),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: LogService.instance.stream,
        initialData: LogService.instance.entries,
        builder: (context, snap) {
          final logs = (snap.data ?? []) as List;
          _lastLogs = logs.whereType<LogEntry>().toList();
          final categories = {..._lastLogs.map((e) => e.category)}
            ..removeWhere((e) => e.isEmpty);
          final filtered = _selectedCategories.isEmpty
              ? _lastLogs
              : _lastLogs
                    .where((e) => _selectedCategories.contains(e.category))
                    .toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _sectionHeader('User'),
              Card(
                child: ListTile(
                  title: Text(user?.uid ?? 'Guest'),
                  subtitle: Text(
                    user == null
                        ? 'Not signed in'
                        : '${user.email ?? 'no-email'}\nPhone: ${user.phoneNumber ?? '-'}',
                  ),
                  trailing: Text(
                    FirebaseService.user == null ? '—' : 'Signed In',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _sectionHeader('Device / Build'),
              Card(
                child: ListTile(
                  title: Text(Platform.operatingSystem),
                  subtitle: Text(
                    'Locale: ${Localizations.localeOf(context)}\nDart: ${Platform.version.split(" ").first}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _sectionHeader('Config & Flags'),
              Card(
                child: ListTile(
                  title: const Text('Cloud Orders Enabled'),
                  subtitle: Text(AppConfig.enableCloudOrders.toString()),
                ),
              ),
              const SizedBox(height: 12),
              _sectionHeader('Orders (local cached)'),
              Card(
                child: ListTile(
                  title: Text('${_orders.orders.length} orders cached'),
                  subtitle: Text('Pending ops: ${_orders.pendingCount.value}'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _sectionHeader(
                    'Recent Logs (${filtered.length}/${_lastLogs.length})',
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Copy filtered logs',
                    onPressed: filtered.isEmpty ? null : _copyFiltered,
                    icon: const Icon(Icons.copy_all, size: 18),
                  ),
                ],
              ),
              if (categories.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: -6,
                  children: categories.map((c) {
                    final active = _selectedCategories.contains(c);
                    return FilterChip(
                      selected: active,
                      label: Text(c),
                      onSelected: (_) {
                        setState(() {
                          if (active) {
                            _selectedCategories.remove(c);
                          } else {
                            _selectedCategories.add(c);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 8),
              if (filtered.isEmpty) const Text('No logs (after filter).'),
              ...filtered.map((e) => _logTile(e)).take(200),
              const SizedBox(height: 48),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: Colors.amber, letterSpacing: 1.1),
    ),
  );

  Widget _logTile(dynamic raw) {
    if (raw is! LogEntry) return const SizedBox.shrink();
    final time = _fmt(raw.timestamp);
    return Card(
      child: ListTile(
        dense: true,
        title: Text('[${raw.category}] ${raw.message}'),
        subtitle: raw.error != null ? Text(raw.error!) : null,
        trailing: Text(time, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

  Future<void> _copyFiltered() async {
    final buffer = StringBuffer();
    for (final e
        in (_selectedCategories.isEmpty
            ? _lastLogs
            : _lastLogs.where(
                (e) => _selectedCategories.contains(e.category),
              ))) {
      buffer.writeln(
        '[${e.timestamp.toIso8601String()}][${e.category}] ${e.message}${e.error != null ? ' | error=${e.error}' : ''}',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logs copied to clipboard')));
    }
  }
}
