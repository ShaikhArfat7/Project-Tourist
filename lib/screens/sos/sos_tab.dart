import 'package:flutter/material.dart';
import '../../core/services/firebase_user_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/url_launcher_helper.dart';
import 'widgets/emergency_contact_tile.dart';

class SOSTab extends StatefulWidget {
  const SOSTab({super.key});

  @override
  State<SOSTab> createState() => _SOSTabState();
}

class _SOSTabState extends State<SOSTab> with SingleTickerProviderStateMixin {
  final FirebaseUserService _userService = FirebaseUserService();
  final LocationService _locationService = LocationService();

  bool _triggered = false;
  String? _dispatchedCoordinates;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _userService.addListener(_onUserUpdated);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _userService.removeListener(_onUserUpdated);
    _pulse.dispose();
    super.dispose();
  }

  void _onUserUpdated() {
    if (mounted) setState(() {});
  }

  /// Safeguard #1:
  /// Requires explicit user confirmation before activating SOS.
  Future<void> _confirmAndTriggerSOS() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sos, color: AppTheme.highRiskRed),
            SizedBox(width: 8),
            Expanded(child: Text('Confirm Emergency SOS')),
          ],
        ),
        content: const Text(
          'Do you want to activate Emergency SOS mode and prepare your live GPS coordinates for emergency dispatch?\n\n'
          'Note: For immediate voice contact with Indian emergency services, tap "Dial 112" after confirming.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.highRiskRed),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Confirm SOS'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _triggered = true);

    final locResult = await _locationService.determinePosition();
    double? lat;
    double? lon;
    String addr = 'Unknown GPS coordinates';

    if (locResult.position != null) {
      lat = locResult.position!.latitude;
      lon = locResult.position!.longitude;
      addr = await _locationService.getAddressFromCoordinates(lat, lon);
    }

    await _userService.logConfirmedSosIncident(
      latitude: lat,
      longitude: lon,
      address: addr,
      reason: 'User explicitly confirmed SOS on Emergency SOS screen',
    );

    if (!mounted) return;
    setState(() {
      _dispatchedCoordinates = lat != null && lon != null
          ? '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)} ($addr)'
          : 'GPS unavailable — dial 112 directly';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.highRiskRed,
        content: Text('SOS Mode Active. Use quick-dial buttons below to reach 112 or your emergency contact.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _resetSOS() {
    setState(() {
      _triggered = false;
      _dispatchedCoordinates = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS mode deactivated.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _userService.currentProfile;
    final hasPersonalContact = profile != null &&
        profile.emergencyContactPhone.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        actions: [
          if (_triggered)
            IconButton(
              tooltip: 'Reset SOS',
              icon: const Icon(Icons.refresh),
              onPressed: _resetSOS,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Transform.scale(
                scale: _triggered ? 1.0 + _pulse.value * 0.05 : 1.0,
                child: child,
              ),
              child: GestureDetector(
                onTap: _triggered ? null : _confirmAndTriggerSOS,
                onLongPress: _confirmAndTriggerSOS,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _triggered
                        ? AppTheme.highRiskRed
                        : const Color(0xFFB91C1C),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.highRiskRed.withValues(alpha: 0.38),
                        blurRadius: _triggered ? 36 : 18,
                        spreadRadius: _triggered ? 10 : 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sos, color: Colors.white, size: 58),
                      const SizedBox(height: 8),
                      Text(
                        _triggered ? 'SOS ACTIVE' : 'TAP OR HOLD FOR SOS',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_triggered)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.highRiskRed.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    const Text(
                      '🚨 SOS Mode Confirmed',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.highRiskRed,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Location Snapshot: ${_dispatchedCoordinates ?? "Acquiring GPS..."}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.highRiskRed,
                          ),
                          onPressed: () => UrlLauncherHelper.callNumber(context, '112'),
                          icon: const Icon(Icons.call, size: 18),
                          label: const Text('Call 112 Now'),
                        ),
                        TextButton.icon(
                          onPressed: _resetSOS,
                          icon: const Icon(Icons.cancel_outlined, color: AppTheme.muted),
                          label: const Text(
                            'Deactivate SOS',
                            style: TextStyle(color: AppTheme.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              const Text(
                'Tap or hold the SOS button and confirm to log your emergency coordinates and access one-tap emergency dialing.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted, fontSize: 13),
              ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            if (hasPersonalContact) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Your Personal Emergency Contact',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              EmergencyContactTile(
                icon: Icons.contact_phone,
                label: profile.emergencyContactName.isNotEmpty
                    ? profile.emergencyContactName
                    : 'Saved Emergency Contact',
                number: profile.emergencyContactPhone,
              ),
              const SizedBox(height: 12),
            ],

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Official National Emergency Helplines (India)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const EmergencyContactTile(
              icon: Icons.emergency,
              label: 'National Emergency Response (ERSS)',
              number: '112',
            ),
            const EmergencyContactTile(
              icon: Icons.local_police,
              label: 'Police Control Room',
              number: '100',
            ),
            const EmergencyContactTile(
              icon: Icons.local_hospital,
              label: 'Medical Ambulance Service',
              number: '108',
            ),
            const EmergencyContactTile(
              icon: Icons.fire_truck,
              label: 'Fire & Rescue Services',
              number: '101',
            ),
            const EmergencyContactTile(
              icon: Icons.support_agent,
              label: 'Ministry of Tourism Helpline',
              number: '1363',
            ),
          ],
        ),
      ),
    );
  }
}
