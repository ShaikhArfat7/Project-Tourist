import 'package:flutter/material.dart';

class QuickActionsGrid extends StatelessWidget {
  final ValueChanged<String>? onActionTap;

  final List<Map<String, dynamic>> _actions = const [
    {'icon': Icons.sos, 'label': 'SOS Alert', 'color': Color(0xFFDC2626)},
    {'icon': Icons.map, 'label': 'Safe Map', 'color': Color(0xFF0891B2)},
    {'icon': Icons.local_hospital, 'label': 'Hospitals', 'color': Color(0xFF16A34A)},
    {'icon': Icons.local_police, 'label': 'Police', 'color': Color(0xFF7C2D12)},
  ];

  const QuickActionsGrid({super.key, this.onActionTap});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: _actions.map((a) {
        final label = a['label'] as String;
        final color = a['color'] as Color;
        final icon = a['icon'] as IconData;

        return GestureDetector(
          onTap: () {
            if (onActionTap != null) {
              onActionTap!(label);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
