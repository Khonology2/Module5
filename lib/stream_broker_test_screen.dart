import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/firestore_stream_broker.dart';
import 'dart:developer' as developer;

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
      if (_logs.length > 50) _logs.removeAt(0); // Keep last 50 logs
    });
    developer.log(message);
  }

  Future<void> _testStreamBroker() async {
    setState(() {
      _isLoading = true;
      _logs.clear();
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addLog('❌ No user logged in');
        return;
      }

      _addLog('✅ User logged in: ${user.uid}');
      _addLog('🔄 Testing stream broker...');

      final broker = FirestoreStreamBroker();
      
      // Test audit entries stream
      _addLog('📡 Getting audit entries stream...');
      final stream = broker.getAuditEntriesStream(
        userId: user.uid,
        isManager: false, // Test as employee first
        limit: 10,
      );

      _addLog('👂 Listening to stream...');
      
      final subscription = stream.listen(
        (snapshot) {
          _addLog('📦 Stream received ${snapshot.docs.length} documents');
          
          for (int i = 0; i < snapshot.docs.length && i < 3; i++) {
            final doc = snapshot.docs[i];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            _addLog('📄 Doc $i: ${data['goalTitle']} - ${data['status']}');
          }
        },
        onError: (error) {
          _addLog('❌ Stream error: $error');
        },
        onDone: () {
          _addLog('✅ Stream completed');
        },
      );

      // Cancel after 30 seconds
      await Future.delayed(const Duration(seconds: 30));
      await subscription.cancel();
      _addLog('⏹️ Test completed');

    } catch (e, stackTrace) {
      _addLog('❌ Test failed: $e');
      _addLog('📋 Stack trace: $stackTrace');
    } finally {
      setState(() {
        _isLoading = false;
      });
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
            padding: const EdgeInsets.all(16),
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
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _logs[index],
                      style: TextStyle(
                        color: Colors.grey[300],
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
