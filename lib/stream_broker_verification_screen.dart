import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/firestore_stream_broker.dart';
import 'package:pdh/models/audit_entry.dart';
import 'dart:developer' as developer;

class StreamBrokerTestScreen extends StatefulWidget {
  const StreamBrokerTestScreen({super.key});

  @override
  State<StreamBrokerTestScreen> createState() => _StreamBrokerTestScreenState();
}

class _StreamBrokerTestScreenState extends State<StreamBrokerTestScreen> {
  final List<String> _testResults = [];
  bool _isLoading = false;

  void _addLog(String message) {
    setState(() {
      _testResults.add('${DateTime.now().millisecondsSinceEpoch}: $message');
      if (_testResults.length > 50) _testResults.removeAt(0);
    });
    developer.log(message);
  }

  Future<void> _testStreamBroker() async {
    setState(() => _isLoading = true);
    _addLog('🔄 Testing Firestore Stream Broker...');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addLog('❌ No user logged in');
        return;
      }

      final broker = FirestoreStreamBroker();
      final stream = broker.getAuditEntriesStream(
        userId: user.uid,
        isManager: false, // Test as employee
        limit: 10,
      );

      _addLog('📡 Created stream for user: ${user.uid}');

      final subscription = stream.listen(
        (snapshot) {
          _addLog('📦 Stream received ${snapshot.docs.length} documents');
          
          var auditCount = 0;
          var statusCounts = <String, int>{};
          
          for (final doc in snapshot.docs) {
            try {
              final entry = AuditEntry.fromFirestore(doc);
              auditCount++;
              
              // Count by status
              final status = entry.status;
              statusCounts[status] = (statusCounts[status] ?? 0) + 1;
              
              _addLog('📄 Entry: ${entry.goalTitle} - Status: ${entry.status}');
            } catch (e) {
              _addLog('❌ Error parsing entry: $e');
            }
          }
          
          _addLog('📊 Summary: $auditCount total entries');
          statusCounts.forEach((status, count) {
            _addLog('  $status: $count');
          });
        },
        onError: (error) {
          _addLog('❌ Stream error: $error');
        },
      );

      // Listen for 10 seconds then stop
      await Future.delayed(const Duration(seconds: 10));
      await subscription.cancel();
      _addLog('⏹️ Test completed');

    } catch (e, stackTrace) {
      _addLog('❌ Test failed: $e');
      _addLog('📋 Stack: $stackTrace');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stream Broker Test'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _testStreamBroker,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Test Stream Broker'),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: ListView.builder(
                itemCount: _testResults.length,
                itemBuilder: (context, index) {
                  final log = _testResults[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
