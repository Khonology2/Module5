import 'package:flutter/material.dart';
import 'package:pdh/widgets/messages_icon.dart';
import 'package:pdh/widgets/notifications_bell.dart';

class HeaderActionIcons extends StatelessWidget {
  const HeaderActionIcons({
    super.key,
    this.onNotificationTap,
  });

  static const double kIconGap = 0;

  final VoidCallback? onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MessagesIcon(),
        const SizedBox(width: kIconGap),
        NotificationsBell(onTap: onNotificationTap),
      ],
    );
  }
}
