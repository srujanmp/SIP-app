import 'package:flutter/material.dart';

import '../app.dart';
import '../services/models.dart';
import '../services/sip_service.dart';

class CallLogScreen extends StatefulWidget {
  const CallLogScreen({super.key});

  @override
  State<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen> {
  final SipService _sipService = SipService.instance;
  late Future<List<CallLogEntry>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = _sipService.fetchCallLogs();
  }

  Future<void> _refresh() async {
    final next = _sipService.fetchCallLogs();
    setState(() => _logsFuture = next);
    await next;
  }

  String _label(CallLogType type) {
    switch (type) {
      case CallLogType.incoming:
        return 'Incoming';
      case CallLogType.outgoing:
        return 'Outgoing';
      case CallLogType.missed:
        return 'Missed';
    }
  }

  String _durationText(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  String _timeText(DateTime timestamp) {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Logs'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.dialpad),
            icon: const Icon(Icons.dialpad),
            tooltip: 'Dialpad',
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<CallLogEntry>>(
          future: _logsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load call logs',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            }

            final logs = snapshot.data ?? <CallLogEntry>[];
            if (logs.isEmpty) {
              return const Center(child: Text('No calls yet'));
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final isMissed = log.type == CallLogType.missed;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isMissed
                          ? Theme.of(context).colorScheme.errorContainer
                          : Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        isMissed ? Icons.call_missed : Icons.call,
                        color: isMissed
                            ? Theme.of(context).colorScheme.onErrorContainer
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text('Extension ${log.number}'),
                    subtitle: Text('${_label(log.type)} • ${_timeText(log.timestamp)}'),
                    trailing: Text(_durationText(log.durationSeconds)),
                  );
                },
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: logs.length,
              ),
            );
          },
        ),
      ),
    );
  }
}
