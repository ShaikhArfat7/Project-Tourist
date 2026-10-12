import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/url_launcher_helper.dart';

class NearbyCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String dist;
  final String type;
  final Color color;
  final String? phoneNumber;

  const NearbyCard({
    super.key,
    required this.icon,
    required this.name,
    required this.dist,
    required this.type,
    required this.color,
    this.phoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    final phone = phoneNumber ?? (type == 'Police' ? '100' : '108');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          '$type • $dist',
          style: const TextStyle(fontSize: 12, color: AppTheme.muted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.call, color: color, size: 20),
              tooltip: 'Call $name',
              onPressed: () => UrlLauncherHelper.callNumber(context, phone),
            ),
            IconButton(
              icon: Icon(Icons.directions, color: color, size: 20),
              tooltip: 'Get Directions',
              onPressed: () => UrlLauncherHelper.openMapDirections(context, name),
            ),
          ],
        ),
      ),
    );
  }
}
