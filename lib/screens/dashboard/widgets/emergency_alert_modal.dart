import 'package:flutter/material.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/safety_zone_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/url_launcher_helper.dart';

class EmergencyAlertModal extends StatefulWidget {
  final HazardZone zone;
  final void Function(int tabIndex)? onNavigateTab;

  const EmergencyAlertModal({
    super.key,
    required this.zone,
    this.onNavigateTab,
  });

  static bool _isShowing = false;

  /// Presents the high-risk emergency alert dialog with audio and haptic feedback.
  static Future<void> show(
    BuildContext context, {
    required HazardZone zone,
    void Function(int tabIndex)? onNavigateTab,
  }) async {
    if (_isShowing) return;
    _isShowing = true;

    // Trigger audible alarm tone and urgent haptic vibration sequence
    NotificationService().triggerHighRiskSensoryFeedback(
      title: '🚨 HIGH RISK HAZARD ALERT: ${zone.name}',
      body: zone.warningMessage,
    );

    SafetyZoneService().markZoneAcknowledged(zone.id);

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => EmergencyAlertModal(
          zone: zone,
          onNavigateTab: onNavigateTab,
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<EmergencyAlertModal> createState() => _EmergencyAlertModalState();
}

class _EmergencyAlertModalState extends State<EmergencyAlertModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zone = widget.zone;

    return PopScope(
      canPop: true,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. High Urgency Animated Emergency Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                decoration: const BoxDecoration(
                  color: AppTheme.highRiskRed,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.gpp_bad_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '🚨 IMMEDIATE HIGH RISK GEOFENCE WARNING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      zone.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (zone.city.isNotEmpty)
                      Text(
                        zone.city,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),

              // 2. Body Details
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tag
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: zone.isDemoData
                                ? const Color(0xFFFEF3C7)
                                : AppTheme.highRiskRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: zone.isDemoData
                                  ? AppTheme.cautionAmber.withValues(alpha: 0.4)
                                  : AppTheme.highRiskRed.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            zone.categoryBadgeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: zone.isDemoData
                                  ? const Color(0xFF92400E)
                                  : AppTheme.highRiskRed,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            zone.hazardType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Hazard Warning Message
                    Text(
                      zone.warningMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textDark,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Mandatory Safety Advisory Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.highRiskRed.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.shield_outlined,
                                  color: AppTheme.highRiskRed, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Mandatory Tourist Action:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.highRiskRed,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            zone.recommendedAction,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textDark,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Official Source
                    Text(
                      'Official Source: ${zone.source}',
                      style: const TextStyle(fontSize: 10, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 16),

                    // 3. Urgent Action Buttons
                    // Primary Action: Call 112
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.highRiskRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.call, size: 20),
                        label: const Text(
                          'CALL ERSS 112 NOW',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        onPressed: () {
                          UrlLauncherHelper.callNumber(context, '112');
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Secondary Action: Activate SOS
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7F1D1D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.sos, size: 20),
                        label: const Text(
                          'ACTIVATE SOS & NOTIFY CONTACTS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onNavigateTab?.call(2); // Switch to SOS tab
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Tertiary Action: Nearby Help & Police
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.tealDark,
                              side: const BorderSide(color: AppTheme.teal),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.local_police_outlined, size: 16),
                            label: const Text('Find Police / Help',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onNavigateTab?.call(3); // Switch to Nearby tab
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Acknowledge'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
