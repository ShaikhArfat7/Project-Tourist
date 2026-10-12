import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/url_launcher_helper.dart';

class EmergencyContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String number;

  const EmergencyContactTile({
    super.key,
    required this.icon,
    required this.label,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.orangeTint,
        child: Icon(icon, color: AppTheme.orange),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: ElevatedButton(
        onPressed: () => UrlLauncherHelper.callNumber(context, number),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.orange,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(number),
      ),
    );
  }
}
