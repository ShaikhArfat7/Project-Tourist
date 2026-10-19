import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/emergency_service_place.dart';
import '../core/services/destination_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/safety_zone_service.dart';
import '../core/theme/app_theme.dart';
import '../core/services/firebase_user_service.dart';
import '../core/utils/url_launcher_helper.dart';
import 'auth/auth_screen.dart';
import 'dashboard/dashboard_tab.dart';
import 'dashboard/widgets/emergency_alert_modal.dart';
import 'nearby/nearby_tab.dart';
import 'profile/profile_tab.dart';
import 'sos/sos_tab.dart';
import 'tracking/tracking_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  EmergencyCategory _nearbyCategory = EmergencyCategory.all;
  TouristDestination? _browsedDestination;
  bool _hasCheckedStartupAuth = false;
  final SafetyZoneService _safetyZoneService = SafetyZoneService();

  @override
  void initState() {
    super.initState();
    _safetyZoneService.addListener(_onSafetyZoneChanged);
    NotificationService.onNotificationPayload.addListener(_onNotificationPayloadReceived);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermissionsOnStartup();
      _checkStartupAuth();
      _checkInitialHighRisk();
    });
  }

  @override
  void dispose() {
    _safetyZoneService.removeListener(_onSafetyZoneChanged);
    NotificationService.onNotificationPayload.removeListener(_onNotificationPayloadReceived);
    super.dispose();
  }

  void _onSafetyZoneChanged() {
    if (!mounted) return;
    setState(() {});
    final highZone = _safetyZoneService.activeHighRiskZone;
    if (highZone != null && !_safetyZoneService.hasAcknowledgedZone(highZone.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        EmergencyAlertModal.show(
          context,
          zone: highZone,
          onNavigateTab: _onNavigateTab,
        );
      });
    }
  }

  void _onNotificationPayloadReceived() {
    final payload = NotificationService.onNotificationPayload.value;
    if (payload == 'high_risk' && mounted) {
      _onNavigateTab(2); // Direct to SOS
      final highZone = _safetyZoneService.activeHighRiskZone;
      if (highZone != null) {
        EmergencyAlertModal.show(
          context,
          zone: highZone,
          onNavigateTab: _onNavigateTab,
        );
      }
    }
  }

  void _checkInitialHighRisk() {
    final highZone = _safetyZoneService.activeHighRiskZone;
    if (highZone != null && !_safetyZoneService.hasAcknowledgedZone(highZone.id)) {
      EmergencyAlertModal.show(
        context,
        zone: highZone,
        onNavigateTab: _onNavigateTab,
      );
    }
  }

  Future<void> _requestNotificationPermissionsOnStartup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyRequested = prefs.getBool('pref_notification_permission_requested') ?? false;
      if (!alreadyRequested) {
        await NotificationService().requestPermissions();
      }
    } catch (_) {}
  }

  void _checkStartupAuth() {
    if (_hasCheckedStartupAuth) return;
    _hasCheckedStartupAuth = true;
    final userService = FirebaseUserService();
    if (!userService.isSignedIn) {
      _showStartupSignInDialog();
    }
  }

  void _showStartupSignInDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.tealTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shield_outlined, color: AppTheme.tealDark, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome Tourist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Safety & Hazard Monitor', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sign in with your Tourist account to sync real-time emergency contacts, geofence alerts, and profile preferences.',
                style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textDark),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In / Register Account'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.tealDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Continue as Guest / Skip'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    FirebaseUserService().signInAsGuest();
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onNavigateTab(int index) {
    if (index >= 0 && index < 5) {
      setState(() => _currentIndex = index);
    }
  }

  void _onSelectNearbyCategory(EmergencyCategory category) {
    setState(() => _nearbyCategory = category);
  }

  void _onDestinationChanged(TouristDestination? destination) {
    setState(() => _browsedDestination = destination);
  }

  Widget _buildPersistentHighRiskBanner(HazardZone zone) {
    return Material(
      color: AppTheme.highRiskRed,
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'HIGH RISK HAZARD ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    zone.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.highRiskRed,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => UrlLauncherHelper.callNumber(context, '112'),
              child: const Text('112', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7F1D1D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _onNavigateTab(2), // SOS tab
              child: const Text('SOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white, size: 20),
              tooltip: 'View Hazard Details',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => EmergencyAlertModal.show(
                context,
                zone: zone,
                onNavigateTab: _onNavigateTab,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardTab(
        onNavigateTab: _onNavigateTab,
        onSelectNearbyCategory: _onSelectNearbyCategory,
        browsedDestination: _browsedDestination,
        onDestinationChanged: _onDestinationChanged,
      ),
      TrackingTab(
        browsedDestination: _browsedDestination,
        onDestinationChanged: _onDestinationChanged,
      ),
      const SOSTab(),
      NearbyTab(
        initialCategory: _nearbyCategory,
        browsedDestination: _browsedDestination,
        onDestinationChanged: _onDestinationChanged,
      ),
      ProfileTab(onNavigateTab: _onNavigateTab),
    ];

    final activeHighRisk = _safetyZoneService.activeHighRiskZone;

    return Scaffold(
      body: SafeArea(
        top: activeHighRisk != null,
        bottom: false,
        child: Column(
          children: [
            if (activeHighRisk != null) _buildPersistentHighRiskBanner(activeHighRisk),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onNavigateTab,
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.tealTint,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppTheme.tealDark),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: AppTheme.tealDark),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.sos_outlined),
            selectedIcon: Icon(Icons.sos, color: AppTheme.highRiskRed),
            label: 'SOS',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_hospital_outlined),
            selectedIcon: Icon(Icons.local_hospital, color: AppTheme.tealDark),
            label: 'Nearby',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppTheme.tealDark),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
