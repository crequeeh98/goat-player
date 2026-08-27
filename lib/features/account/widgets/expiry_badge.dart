import 'package:flutter/material.dart';

class ExpiryBadge extends StatelessWidget {
  final int? expDateTimestamp;

  const ExpiryBadge({super.key, this.expDateTimestamp});

  @override
  Widget build(BuildContext context) {
    if (expDateTimestamp == null) {
      return const _Badge(
        label: 'Unlimited',
        color: Colors.green,
        icon: Icons.check_circle_outline,
      );
    }

    final expDate = DateTime.fromMillisecondsSinceEpoch(expDateTimestamp! * 1000);
    final isExpired = expDate.isBefore(DateTime.now());
    final isExpiringSoon = expDate.difference(DateTime.now()).inDays < 7;

    Color badgeColor = Colors.green;
    IconData badgeIcon = Icons.check_circle_outline;
    String label = 'Active';

    if (isExpired) {
      badgeColor = Colors.red;
      badgeIcon = Icons.error_outline;
      label = 'Expired';
    } else if (isExpiringSoon) {
      badgeColor = Colors.orange;
      badgeIcon = Icons.warning_amber_rounded;
      label = 'Expiring Soon';
    }

    return Tooltip(
      message: 'Expires: ${expDate.toLocal().toString().split('.')[0]}',
      child: _Badge(
        label: label,
        color: badgeColor,
        icon: badgeIcon,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Badge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
