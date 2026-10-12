import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/alert_card.dart';
import 'widgets/quick_actions_grid.dart';
import 'widgets/safety_status_card.dart';

class DashboardTab extends StatelessWidget {
  final ValueChanged<int>? onNavigateTab;

  const DashboardTab({super.key, this.onNavigateTab});

  void _handleQuickAction(BuildContext context, String actionLabel) {
    switch (actionLabel) {
      case 'SOS Alert':
        onNavigateTab?.call(2); // SOS tab
        break;
      case 'Safe Map':
        onNavigateTab?.call(1); // Tracking tab
        break;
      case 'Hospitals':
      case 'Police':
        onNavigateTab?.call(3); // Nearby tab
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Tourist Safety Monitor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'New Panvel • AIKTC',
              style: TextStyle(fontSize: 11, color: Color(0xFFF3C9A8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No new safety notifications at this time.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Safety Status Card
            const SafetyStatusCard(),
            const SizedBox(height: 16),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 10),
            QuickActionsGrid(
              onActionTap: (label) => _handleQuickAction(context, label),
            ),
            const SizedBox(height: 16),

            // Active Alerts
            const Text(
              'Active Alerts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 10),
            AlertCard(
              icon: Icons.warning_amber_rounded,
              title: 'High Crowd Density',
              subtitle: 'Gateway Area — 0.8 km away',
              color: Colors.orange,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('High Crowd Density Alert'),
                    content: const Text(
                      'Gateway Area is currently experiencing elevated pedestrian density (approx 0.8 km away). Please stay with your group and safeguard personal belongings.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            AlertCard(
              icon: Icons.info_outline,
              title: 'Zone Advisory',
              subtitle: 'Night travel not recommended after 10 PM',
              color: Colors.blue,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Zone Travel Advisory'),
                    content: const Text(
                      'Local administration recommends avoiding solitary travel in remote parts of Sector 5 after 10:00 PM. Registered tourist shuttles remain operational.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
