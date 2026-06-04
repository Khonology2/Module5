import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/audit_service.dart';
import 'dart:developer' as developer;
import 'package:pdh/widgets/custom_logo_loader.dart';

class StreamBrokerTestScreen extends StatefulWidget {
  const StreamBrokerTestScreen({super.key});

  @override
  State<StreamBrokerTestScreen> createState() => _StreamBrokerTestScreenState();
}

class _StreamBrokerTestScreenState extends State<StreamBrokerTestScreen> {
  final List<String> _logs = [];
  bool _isLoading = false;

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().millisecondsSinceEpoch}: $message');
      if (_logs.length > 50) _logs.removeAt(0);
    });
    developer.log(message);
  }

  Future<void> _testAuditPolling() async {
    setState(() {
      _isLoading = true;
      _logs.clear();
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addLog('No user logged in');
        return;
      }

      _addLog('User logged in: ${user.uid}');
      _addLog('Polling audit entries via backend...');

      final stream = AuditService.getEmployeeAuditEntriesStream();

      final subscription = stream.listen(
        (entries) {
          _addLog('Received ${entries.length} audit entries');
          for (var i = 0; i < entries.length && i < 3; i++) {
            final entry = entries[i];
            _addLog('Entry $i: ${entry.goalTitle} - ${entry.status}');
          }
        },
        onError: (error) => _addLog('Stream error: $error'),
      );

      await Future.delayed(const Duration(seconds: 30));
      await subscription.cancel();
      _addLog('Test completed');
    } catch (e, stackTrace) {
      _addLog('Test failed: $e');
      _addLog('Stack trace: $stackTrace');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backend Stream Test')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _testAuditPolling,
              child: Text(_isLoading ? 'Running...' : 'Run audit polling test'),
            ),
          ),
          if (_isLoading) const CustomLogoLoader(),
          Expanded(
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(_logs[index], style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
