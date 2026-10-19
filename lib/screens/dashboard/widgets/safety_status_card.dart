import 'package:flutter/material.dart';
import '../../../core/services/safety_zone_service.dart';
import '../../../core/theme/app_theme.dart';

class SafetyStatusCard extends StatelessWidget {
  final RiskTier riskTier;
  final String subtitle;
  final String evidenceSummary;
  final LiveWeatherSummary? weather;
  final DateTime? evaluatedAt;
  final bool gpsActive;
  final VoidCallback? onViewDetails;

  const SafetyStatusCard({
    super.key,
    this.riskTier = RiskTier.low,
    this.subtitle = 'No active geofence or severe weather hazard matched at current coordinates.',
    this.evidenceSummary =
        'Checked: Curated Geofence Advisory Dataset + Open-Meteo Live Weather.',
    this.weather,
    this.evaluatedAt,
    this.gpsActive = true,
    this.onViewDetails,
  });

  List<Color> _gradientColors() {
    if (!gpsActive) {
      return [const Color(0xFF475569), const Color(0xFF64748B)];
    }
    switch (riskTier) {
      case RiskTier.highRisk:
        return [const Color(0xFF991B1B), const Color(0xFFDC2626)];
      case RiskTier.caution:
        return [const Color(0xFFB45309), const Color(0xFFD97706)];
      case RiskTier.low:
        return [AppTheme.tealDark, AppTheme.teal];
    }
  }

  IconData _statusIcon() {
    if (!gpsActive) return Icons.location_disabled;
    switch (riskTier) {
      case RiskTier.highRisk:
        return Icons.warning_amber_rounded;
      case RiskTier.caution:
        return Icons.report_problem_outlined;
      case RiskTier.low:
        return Icons.shield_outlined;
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = _gradientColors();
    final headline = !gpsActive
        ? 'Location Services Unavailable'
        : riskTier.headline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_statusIcon(), color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Safety & Hazard Assessment',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (evaluatedAt != null)
                Text(
                  'Updated ${_formatTime(evaluatedAt!)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatChip(
                label: 'Risk Tier',
                value: gpsActive ? riskTier.badgeLabel : 'UNKNOWN',
              ),
              StatChip(
                label: 'GPS',
                value: gpsActive ? 'Available' : 'Unavailable',
              ),
              if (weather != null)
                StatChip(
                  label: 'Weather',
                  value:
                      '${weather!.temperatureCelsius.toStringAsFixed(0)}°C • ${weather!.conditionText}',
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            evidenceSummary,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          if (onViewDetails != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onViewDetails,
                icon: const Icon(Icons.info_outline, color: Colors.white, size: 16),
                label: const Text(
                  'View Sources & Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
