import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/nearby_card.dart';

class NearbyTab extends StatelessWidget {
  const NearbyTab({super.key});

  final List<Map<String, dynamic>> _places = const [
    {
      'icon': Icons.local_hospital,
      'name': 'New Panvel General Hospital',
      'dist': '1.2 km',
      'type': 'Hospital',
      'color': Color(0xFF16A34A),
      'phone': '02227451234',
    },
    {
      'icon': Icons.local_police,
      'name': 'Panvel Police Station',
      'dist': '0.8 km',
      'type': 'Police',
      'color': Color(0xFF1D4ED8),
      'phone': '100',
    },
    {
      'icon': Icons.local_fire_department,
      'name': 'Fire Brigade — Sector 12',
      'dist': '2.1 km',
      'type': 'Fire',
      'color': Color(0xFFDC2626),
      'phone': '101',
    },
    {
      'icon': Icons.local_pharmacy,
      'name': '24hr MedPlus Pharmacy',
      'dist': '0.3 km',
      'type': 'Pharmacy',
      'color': Color(0xFF0891B2),
      'phone': '02227459876',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Help')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Emergency Services Near You',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppTheme.textDark,
              ),
            ),
          ),
          ..._places.map(
            (p) => NearbyCard(
              icon: p['icon'] as IconData,
              name: p['name'] as String,
              dist: p['dist'] as String,
              type: p['type'] as String,
              color: p['color'] as Color,
              phoneNumber: p['phone'] as String?,
            ),
          ),
        ],
      ),
    );
  }
}
