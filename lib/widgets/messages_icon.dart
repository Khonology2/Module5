import 'package:flutter/material.dart';
import 'package:pdh/services/role_service.dart';

class MessagesIcon extends StatelessWidget {
  const MessagesIcon({super.key, this.onTap});

  final VoidCallback? onTap;

  void _openMessages(BuildContext context) {
    final role = RoleService.instance.cachedRole;
    final route = role == 'admin'
        ? '/admin_inbox'
        : role == 'manager'
        ? '/manager_inbox'
        : '/team_chats';
    final current = ModalRoute.of(context)?.settings.name;
    if (current != route) {
      Navigator.pushNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => _openMessages(context),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Image.asset(
          'assets/message.png',
          width: 32,
          height: 32,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.message_outlined, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
