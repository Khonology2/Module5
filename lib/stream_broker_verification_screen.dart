import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/audit_service.dart';
import 'package:pdh/models/audit_entry.dart';
import 'package:pdh/widgets/custom_logo_loader.dart';

class StreamBrokerVerificationScreen extends StatefulWidget {
  const StreamBrokerVerificationScreen({super.key});

  @override
  State<StreamBrokerVerificationScreen> createState() =>
      _StreamBrokerVerificationScreenState();
}

class _StreamBrokerVerificationScreenState
    extends State<StreamBrokerVerificationScreen> {
  List<AuditEntry> _entries = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in required';
      });
      return;
    }

    try {
      final stream = AuditService.getEmployeeAuditEntriesStream();
      final first = await stream.first;
      if (!mounted) return;
      setState(() {
        _entries = first;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit stream verification')),
      body: _loading
          ? const CustomLogoLoader(centerInViewport: true)
          : _error != null
          ? Center(child: Text(_error!))
          : ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                return ListTile(
                  title: Text(entry.goalTitle),
                  subtitle: Text(entry.status),
                );
              },
            ),
    );
  }
}
