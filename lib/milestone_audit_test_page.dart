import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/unified_milestone_audit.dart';
import 'package:pdh/services/database_service.dart';

/// Test page to verify milestone audit functionality
class MilestoneAuditTestPage extends StatefulWidget {
  const MilestoneAuditTestPage({Key? key}) : super(key: key);

  @override
  State<MilestoneAuditTestPage> createState() => _MilestoneAuditTestPageState();
}

class _MilestoneAuditTestPageState extends State<MilestoneAuditTestPage> {
  bool _isLoading = false;
  String _status = 'Ready to test';
  List<String> _testResults = [];

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

          // Test audit stream
          final auditStream = UnifiedMilestoneAudit.getMilestoneAuditStream(
            testGoal.id!,
          );

          await for (final audits in auditStream) {
            _testResults.add(
              '✅ Audit stream working: ${audits.length} entries found',
            );
            break; // Only test first batch
          }

          setState(() {
            _status = 'Audit stream test completed successfully';
            _testResults.add('🎉 All tests passed!');
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

      await UnifiedMilestoneAudit.backfillExistingMilestones();

      _testResults.add('✅ Backfill completed successfully');
      setState(() {
        _status = 'Backfill test completed successfully';
        _testResults.add('🎉 Backfill test passed!');
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
