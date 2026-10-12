import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SafetyStatusCard extends StatelessWidget {
  final String statusText;
  final String statusSubtitle;
  final String zone;
  final String risk;
  final String tracking;

  const SafetyStatusCard({
    super.key,
    this.statusText = 'You are SAFE',
    this.statusSubtitle = 'No threats detected in your area',
    this.zone = 'Safe',
    this.risk = 'Low',
    this.tracking = 'ON',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.orangeDark, AppTheme.orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.orange.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('Safety Status', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(statusSubtitle, style: const TextStyle(color: Color(0xFFF3C9A8), fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            children: [
              StatChip(label: 'Zone', value: zone),
              const SizedBox(width: 10),
              StatChip(label: 'Risk', value: risk),
              const SizedBox(width: 10),
              StatChip(label: 'Tracking', value: tracking),
            ],
          ),
        ],
      ),
    );
  }
}

class StatChip extends StatelessWidget {
  final String label, value;
  const StatChip({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
