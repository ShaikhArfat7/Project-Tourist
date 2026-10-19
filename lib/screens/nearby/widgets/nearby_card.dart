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
  final String? address;

  const NearbyCard({
    super.key,
    required this.icon,
    required this.name,
    required this.dist,
    required this.type,
    required this.color,
    this.phoneNumber,
    this.address,
  });

  @override
  Widget build(BuildContext context) {
    final phone = phoneNumber ?? (type == 'Police' ? '112' : (type == 'Hospital' ? '108' : (type == 'Fire' ? '101' : '112')));

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '$type • $dist',
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
            if (address != null && address!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                address!,
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.call, color: color, size: 21),
              tooltip: 'Call $name ($phone)',
              onPressed: () => UrlLauncherHelper.callNumber(context, phone),
            ),
            IconButton(
              icon: Icon(Icons.directions, color: color, size: 21),
              tooltip: 'Get Directions',
              onPressed: () => UrlLauncherHelper.openMapDirections(context, name),
            ),
          ],
        ),
      ),
    );
  }
}
