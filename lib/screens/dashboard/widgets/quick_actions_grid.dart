import 'package:flutter/material.dart';

class QuickActionsGrid extends StatelessWidget {
  final ValueChanged<String>? onActionTap;

  final List<Map<String, dynamic>> _actions = const [
    {
      'icon': Icons.local_police_outlined,
      'label': 'Nearby Police',
      'color': Color(0xFF1D4ED8),
    },
    {
      'icon': Icons.local_hospital_outlined,
      'label': 'Nearby Hospitals',
      'color': Color(0xFFDC2626),
    },
    {
      'icon': Icons.local_pharmacy_outlined,
      'label': 'Pharmacies',
      'color': Color(0xFF0891B2),
    },
    {
      'icon': Icons.emergency_outlined,
      'label': 'Emergency Services',
      'color': Color(0xFF0F766E),
    },
  ];

  const QuickActionsGrid({super.key, this.onActionTap});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 2.4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: _actions.map((a) {
        final label = a['label'] as String;
        final color = a['color'] as Color;
        final icon = a['icon'] as IconData;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onActionTap?.call(label),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: color.withValues(alpha: 0.6)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
