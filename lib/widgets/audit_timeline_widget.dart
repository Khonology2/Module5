import 'package:flutter/material.dart';
import 'package:pdh/services/timeline_service.dart';
import 'package:pdh/models/audit_timeline_event.dart';

class AuditTimelineWidget extends StatelessWidget {
  final String goalId;

  const AuditTimelineWidget({super.key, required this.goalId});

  IconData _iconForType(String type) {
    switch (type) {
      case 'submission':
        return Icons.send_rounded;
      case 'verification':
        return Icons.verified_rounded;
      case 'rejection':
        return Icons.cancel_rounded;
      case 'milestone_created':
        return Icons.add_circle_rounded;
      case 'milestone_updated':
        return Icons.edit_rounded;
      case 'milestone_status_changed':
        return Icons.sync_rounded;
      case 'milestone_deleted':
        return Icons.delete_rounded;
      default:
        return Icons.update_rounded;
    }
  }

  Color _colorForType(BuildContext context, String type) {
    switch (type) {
      case 'submission':
        return Colors.blueAccent;
      case 'verification':
        return Colors.green;
      case 'rejection':
        return Colors.redAccent;
      case 'milestone_created':
        return Colors.purple;
      case 'milestone_updated':
        return Colors.orange;
      case 'milestone_status_changed':
        return Colors.teal;
      case 'milestone_deleted':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AuditTimelineEvent>>(
      stream: TimelineService.getTimelineStream(goalId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final events = snapshot.data ?? const <AuditTimelineEvent>[];
        if (events.isEmpty) {
          return const Center(child: Text('No timeline events yet'));
        }

        return ListView.separated(
          shrinkWrap: true,
          itemCount: events.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final event = events[index];
            final color = _colorForType(context, event.eventType);
            final icon = _iconForType(event.eventType);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color),
              ),
              title: Text(event.description),
              subtitle: Text(
                '${event.eventType} • ${event.actorName} • ${_formatDate(event.timestamp)}',
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${_two(date.month)}-${_two(date.day)} ${_two(date.hour)}:${_two(date.minute)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}
