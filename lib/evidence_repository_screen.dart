import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/repository_service.dart';
import 'package:pdh/models/repository_goal.dart';

class EvidenceRepositoryScreen extends StatefulWidget {
  const EvidenceRepositoryScreen({super.key});

  @override
  State<EvidenceRepositoryScreen> createState() =>
      _EvidenceRepositoryScreenState();
}

class _EvidenceRepositoryScreenState extends State<EvidenceRepositoryScreen> {
  String _searchQuery = '';
  String _sortBy = 'date'; // 'date' or 'title'

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Please sign in to view your evidence.'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search evidence or goal title...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _sortBy,
                items: const [
                  DropdownMenuItem(value: 'date', child: Text('Sort by Date')),
                  DropdownMenuItem(
                    value: 'title',
                    child: Text('Sort by Title'),
                  ),
                ],
                onChanged: (v) => setState(() => _sortBy = v ?? 'date'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<RepositoryGoal>>(
            stream: RepositoryService.getRepositoryGoalsStream(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final goals = snapshot.data ?? const <RepositoryGoal>[];

              // explode evidence items
              final items = <_EvidenceItem>[];
              for (final g in goals) {
                for (final ev in g.evidence) {
                  items.add(
                    _EvidenceItem(
                      goalTitle: g.goalTitle,
                      evidenceText: ev,
                      completedDate: g.completedDate,
                    ),
                  );
                }
              }

              // filter
              final filtered = items.where((e) {
                if (_searchQuery.isEmpty) return true;
                final t = e.goalTitle.toLowerCase();
                final et = e.evidenceText.toLowerCase();
                return t.contains(_searchQuery) || et.contains(_searchQuery);
              }).toList();

              // sort
              filtered.sort((a, b) {
                if (_sortBy == 'title') {
                  return a.goalTitle.toLowerCase().compareTo(
                    b.goalTitle.toLowerCase(),
                  );
                }
                final ad =
                    a.completedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
                final bd =
                    b.completedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
                return bd.compareTo(ad); // newest first
              });

              if (filtered.isEmpty) {
                return const Center(child: Text('No evidence found.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return Card(
                    elevation: 2,
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(item.evidenceText),
                      subtitle: Text(
                        '${item.goalTitle} • ${_formatDate(item.completedDate)}',
                      ),
                      trailing: TextButton.icon(
                        onPressed: () =>
                            _openEvidence(context, item.evidenceText),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('View'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _openEvidence(BuildContext context, String urlOrText) {
    // For now, attempt to launch as URL; otherwise show dialog with the text
    // A fuller implementation can use url_launcher and file viewers
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Evidence'),
        content: SelectableText(urlOrText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return '${date.year}-${_two(date.month)}-${_two(date.day)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}

class _EvidenceItem {
  final String goalTitle;
  final String evidenceText;
  final DateTime? completedDate;

  _EvidenceItem({
    required this.goalTitle,
    required this.evidenceText,
    required this.completedDate,
  });
}
