import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/unified_milestone_audit.dart';

/// Test page to verify milestone audit functionality
class MilestoneAuditTestPage extends StatefulWidget {
  const MilestoneAuditTestPage({super.key});

  @override
  State<MilestoneAuditTestPage> createState() => _MilestoneAuditTestPageState();
}

class _MilestoneAuditTestPageState extends State<MilestoneAuditTestPage> {
  bool _isLoading = false;
  String _status = 'Ready to test';
  final List<String> _testResults = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Milestone Audit Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Status: $_status', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _isLoading ? null : _testAuditStream,
              child: Text(_isLoading ? 'Testing...' : 'Test Audit Stream'),
            ),

            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: _isLoading ? null : _testBackfill,
              child: Text(_isLoading ? 'Testing...' : 'Test Backfill'),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: _testResults.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(_testResults[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testAuditStream() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing audit stream...';
      _testResults.clear();
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _status = 'Error: User not authenticated';
          _testResults.add('❌ User not authenticated');
        });
        return;
      }

      // Test getting goals first
      final goalsStream = DatabaseService.getUserGoalsStream(user.uid);

      await for (final goals in goalsStream) {
        if (goals.isNotEmpty) {
          final testGoal = goals.first;
          _testResults.add('✅ Found goal: ${testGoal.title}');

          // Test milestone audit stream
          final auditStream = UnifiedMilestoneAudit.getMilestoneAuditStream(
            testGoal.id,
          );

          await for (final auditEntries in auditStream) {
            if (auditEntries.isNotEmpty) {
              _testResults.add('✅ Found ${auditEntries.length} audit entries');

              for (final entry in auditEntries) {
                final action = entry['action'] ?? 'unknown';
                final timestamp = entry['timestamp'] as Timestamp?;
                _testResults.add(
                  '📝 $action at ${timestamp?.toDate() ?? 'unknown time'}',
                );
              }

              break; // Test first batch only
            } else {
              _testResults.add('ℹ️  No audit entries found for this goal');
              break;
            }
          }

          setState(() {
            _status = 'Audit stream test completed';
            _testResults.add(
              '📋 Test completed - service pending implementation',
            );
          });
          return;
        } else {
          setState(() {
            _status = 'No goals found to test with';
            _testResults.add('ℹ️ No goals found');
          });
          return;
        }
      }
    } catch (e, stackTrace) {
      setState(() {
        _status = 'Test failed: $e';
        _testResults.add('❌ Error: $e');
        _testResults.add('Stack trace: $stackTrace');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testBackfill() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing backfill...';
      _testResults.clear();
    });

    try {
      _testResults.add('🔄 Starting backfill test...');

      // Test milestone backfill
      await UnifiedMilestoneAudit.backfillExistingMilestones();

      _testResults.add('✅ Milestone backfill completed successfully');

      setState(() {
        _status = 'Backfill test completed';
        _testResults.add('📋 Test completed - service pending implementation');
      });
    } catch (e, stackTrace) {
      setState(() {
        _status = 'Backfill test failed: $e';
        _testResults.add('❌ Backfill error: $e');
        _testResults.add('Stack trace: $stackTrace');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
