import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/emergency_service_place.dart';
import '../../core/services/destination_service.dart';
import '../../core/services/firebase_user_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/safety_zone_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/url_launcher_helper.dart';
import '../crime_analysis/crime_analysis_screen.dart';
import '../destinations/destinations_sheet.dart';
import 'widgets/alert_card.dart';
import 'widgets/emergency_alert_modal.dart';
import 'widgets/quick_actions_grid.dart';
import 'widgets/safety_status_card.dart';

class DashboardTab extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  final ValueChanged<EmergencyCategory>? onSelectNearbyCategory;
  final TouristDestination? browsedDestination;
  final ValueChanged<TouristDestination?>? onDestinationChanged;

  const DashboardTab({
    super.key,
    this.onNavigateTab,
    this.onSelectNearbyCategory,
    this.browsedDestination,
    this.onDestinationChanged,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final LocationService _locationService = LocationService();
  final SafetyZoneService _safetyZoneService = SafetyZoneService();
  final FirebaseUserService _userService = FirebaseUserService();

  bool _isLoadingLocation = true;
  LocationServiceStatus _locationStatus = LocationServiceStatus.ready;
  Position? _livePosition;
  String _liveAddress = 'Detecting your current location...';
  SafetyEvaluationResult? _safetyEval;

  @override
  void initState() {
    super.initState();
    _safetyZoneService.addListener(_onSafetyServiceChanged);
    _userService.addListener(_onUserChanged);
    _refreshDashboardData();
  }

  @override
  void dispose() {
    _safetyZoneService.removeListener(_onSafetyServiceChanged);
    _userService.removeListener(_onUserChanged);
    super.dispose();
  }

  void _onSafetyServiceChanged() {
    if (mounted) {
      _refreshDashboardData();
    }
  }

  void _onUserChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshDashboardData() async {
    setState(() => _isLoadingLocation = true);

    final result = await _locationService.determinePosition();
    if (!mounted) return;

    if (result.status != LocationServiceStatus.ready || result.position == null) {
      setState(() {
        _isLoadingLocation = false;
        _locationStatus = result.status;
        _livePosition = null;
        _liveAddress = result.errorMessage ?? 'Location access unavailable.';
      });
      return;
    }

    final pos = result.position!;
    _livePosition = pos;
    _locationStatus = LocationServiceStatus.ready;

    _locationService.getAddressFromCoordinates(pos.latitude, pos.longitude).then((addr) {
      if (mounted) {
        setState(() => _liveAddress = addr);
      }
    });

    final eval = await _safetyZoneService.evaluateLocation(pos.latitude, pos.longitude);
    if (!mounted) return;

    setState(() {
      _isLoadingLocation = false;
      _safetyEval = eval;
    });

    _checkAndShowHighRiskDialogIfNeeded(eval);
  }

  /// Safeguard #1 & #5:
  /// - Never automatically dispatches SOS when entering a danger zone.
  /// - Displays a prominent warning dialog at most once per zone entry per session,
  ///   giving the user the choice to view details, find nearby help, or open the SOS tab.
  void _checkAndShowHighRiskDialogIfNeeded(SafetyEvaluationResult eval) {
    for (final zone in eval.activeZones) {
      if (!_safetyZoneService.hasAcknowledgedZone(zone.id)) {
        _safetyZoneService.markZoneAcknowledged(zone.id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (zone.riskTier == RiskTier.highRisk) {
            _showHighRiskWarningModal(zone);
          } else {
            _showCautionWarningModal(zone);
          }
        });
        break;
      }
    }
  }

  void _showHighRiskWarningModal(HazardZone zone) {
    EmergencyAlertModal.show(
      context,
      zone: zone,
      onNavigateTab: widget.onNavigateTab,
    );
  }

  void _showCautionWarningModal(HazardZone zone) {
    NotificationService().showMediumRiskNotification(
      title: '⚠️ CAUTION ADVISORY: ${zone.name}',
      body: zone.warningMessage,
    );
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.cautionAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppTheme.cautionAmber, size: 28),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CAUTION / MODERATE ALERT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: AppTheme.cautionAmber,
                    ),
                  ),
                  Text(
                    zone.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: zone.isDemoData
                    ? const Color(0xFFFEF3C7)
                    : AppTheme.cautionAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                zone.categoryBadgeLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: zone.isDemoData
                      ? const Color(0xFF92400E)
                      : AppTheme.cautionAmber,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              zone.warningMessage,
              style: const TextStyle(fontSize: 13, color: AppTheme.textDark, height: 1.35),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cautionAmber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cautionary Tourist Guidelines:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cautionAmber),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    zone.recommendedAction,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Official Source: ${zone.source}',
              style: const TextStyle(fontSize: 10, color: AppTheme.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I Understand'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.support_agent, size: 16),
            label: const Text('Helpline 1363'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.tealDark,
              side: const BorderSide(color: AppTheme.teal),
            ),
            onPressed: () {
              UrlLauncherHelper.callNumber(context, '1363');
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onSelectNearbyCategory?.call(EmergencyCategory.all);
              widget.onNavigateTab?.call(3); // Open Nearby tab
            },
            icon: const Icon(Icons.local_hospital_outlined, size: 16),
            label: const Text('Nearby Services'),
          ),
        ],
      ),
    );
  }

  void _handleQuickAction(String actionLabel) {
    switch (actionLabel) {
      case 'Nearby Police':
        widget.onSelectNearbyCategory?.call(EmergencyCategory.police);
        widget.onNavigateTab?.call(3);
        break;
      case 'Nearby Hospitals':
        widget.onSelectNearbyCategory?.call(EmergencyCategory.hospital);
        widget.onNavigateTab?.call(3);
        break;
      case 'Pharmacies':
        widget.onSelectNearbyCategory?.call(EmergencyCategory.pharmacy);
        widget.onNavigateTab?.call(3);
        break;
      case 'Emergency Services':
        widget.onSelectNearbyCategory?.call(EmergencyCategory.all);
        widget.onNavigateTab?.call(3);
        break;
    }
  }

  void _openDestinationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DestinationsSheet(
        currentSelection: widget.browsedDestination,
        onSelectDestination: (dest) {
          widget.onDestinationChanged?.call(dest);
        },
      ),
    );
  }

  Future<void> _openOfficialPortal(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final gpsAvailable =
        _locationStatus == LocationServiceStatus.ready && _livePosition != null;
    final eval = _safetyEval;
    final riskTier = eval?.overallTier ?? RiskTier.low;
    final profileName = _userService.currentProfile?.fullName;

    String statusSubtitle =
        'No active geofence or severe weather hazard identified at your coordinates.';
    if (!gpsAvailable) {
      statusSubtitle = _liveAddress;
    } else if (eval != null && eval.activeZones.isNotEmpty) {
      final topZone = eval.activeZones.first;
      statusSubtitle = '${topZone.name}: ${topZone.hazardType}';
    } else if (eval?.weather?.advisoryMessage != null) {
      statusSubtitle = eval!.weather!.advisoryMessage!;
    }

    return Scaffold(
      // 1. Simple Header with App Name and Profile/Avatar Button
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tourist Safety Monitor',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              profileName != null && profileName.isNotEmpty
                  ? 'Signed in as $profileName'
                  : 'Real-Time Emergency & Hazard Companion',
              style: const TextStyle(fontSize: 11, color: AppTheme.tealTint),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Public Safety & Crime Analytics',
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CrimeAnalysisScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Explore Destinations (Maharashtra & India)',
            icon: const Icon(Icons.travel_explore),
            onPressed: _openDestinationSheet,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => widget.onNavigateTab?.call(4),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppTheme.tealTint,
                child: Icon(
                  _userService.isSignedIn ? Icons.verified_user : Icons.person_outline,
                  size: 20,
                  color: AppTheme.tealDark,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 2. Location Card + Visible GPS Availability Status
              _buildCurrentLocationCard(gpsAvailable),
              const SizedBox(height: 12),

              // Optional Destination Browse Banner (Separated from Live GPS)
              if (widget.browsedDestination != null) ...[
                _buildDestinationBrowseCard(widget.browsedDestination!),
                const SizedBox(height: 12),
              ],

              // 3. Prominent SOS Emergency Button (Explicit user action required)
              _buildProminentSosCard(),
              const SizedBox(height: 14),

              // 4. Clear Safety-Status Section (LOW / CAUTION / HIGH RISK)
              SafetyStatusCard(
                riskTier: riskTier,
                subtitle: statusSubtitle,
                evidenceSummary: eval?.evidenceSummary ??
                    'Checking live coordinates against hazard advisories and weather telemetry...',
                weather: eval?.weather,
                evaluatedAt: eval?.evaluatedAt,
                gpsActive: gpsAvailable,
              ),
              const SizedBox(height: 18),

              // 5. Quick-Access Cards (Nearby Police, Hospitals, Pharmacies, Emergency Services)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Quick Emergency Access',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openDestinationSheet,
                    icon: const Icon(Icons.travel_explore, size: 16),
                    label: const Text('Browse India Cities', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              QuickActionsGrid(onActionTap: _handleQuickAction),
              const SizedBox(height: 18),

              // 6. Small Map Preview / Location Shortcut
              _buildMiniMapPreview(gpsAvailable),
              const SizedBox(height: 18),

              // Crime Analytics Card (State & Maharashtra District Level)
              _buildCrimeAnalyticsCard(),
              const SizedBox(height: 18),

              // 7. Active Hazard Advisories & Official Indian Safety Sources
              const Text(
                'Safety Advisories & Official Sources',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 10),
              if (eval != null && eval.activeZones.isNotEmpty)
                ...eval.activeZones.map(
                  (z) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AlertCard(
                      icon: z.riskTier == RiskTier.highRisk
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline,
                      title: '[${z.categoryBadgeLabel}] ${z.name}',
                      subtitle: '${z.hazardType} — Tap for precautions & source',
                      color: z.riskTier == RiskTier.highRisk
                          ? AppTheme.highRiskRed
                          : AppTheme.cautionAmber,
                      onTap: () => _showHighRiskWarningModal(z),
                    ),
                  ),
                ),
              if (eval != null && eval.nearbyZones.isNotEmpty)
                ...eval.nearbyZones.take(2).map(
                  (z) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AlertCard(
                      icon: Icons.place_outlined,
                      title:
                          'Regional Advisory (${((z.distanceMeters ?? 0) / 1000).toStringAsFixed(1)} km away): ${z.name}',
                      subtitle: '${z.hazardType} (${z.categoryBadgeLabel})',
                      color: AppTheme.teal,
                      onTap: () => _showHighRiskWarningModal(z),
                    ),
                  ),
                ),

              // Official Indian Portals (IMD, NDMA Sachet, Tourist Helpline)
              _buildOfficialSourcesCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentLocationCard(bool gpsAvailable) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: gpsAvailable
              ? AppTheme.lowRiskGreen.withValues(alpha: 0.35)
              : AppTheme.highRiskRed.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: gpsAvailable
                ? AppTheme.lowRiskGreen.withValues(alpha: 0.12)
                : AppTheme.highRiskRed.withValues(alpha: 0.12),
            child: Icon(
              gpsAvailable ? Icons.my_location : Icons.location_off,
              color: gpsAvailable ? AppTheme.lowRiskGreen : AppTheme.highRiskRed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: gpsAvailable
                            ? AppTheme.lowRiskGreen
                            : AppTheme.highRiskRed,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      gpsAvailable
                          ? 'Live GPS Active'
                          : 'Location Services Unavailable',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: gpsAvailable
                            ? AppTheme.lowRiskGreen
                            : AppTheme.highRiskRed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _isLoadingLocation ? 'Refreshing GPS fix...' : _liveAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh GPS',
            icon: _isLoadingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, color: AppTheme.tealDark),
            onPressed: _isLoadingLocation ? null : _refreshDashboardData,
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationBrowseCard(TouristDestination dest) {
    return FutureBuilder<HazardZone?>(
      future: _safetyZoneService.evaluateCoordinatesForHazard(dest.latitude, dest.longitude),
      builder: (context, snapshot) {
        final hazard = snapshot.data;
        final isHighRisk = hazard?.riskTier == RiskTier.highRisk;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isHighRisk ? const Color(0xFFFEF2F2) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isHighRisk
                  ? AppTheme.highRiskRed.withValues(alpha: 0.45)
                  : AppTheme.cautionAmber.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isHighRisk ? Icons.gpp_bad_rounded : Icons.travel_explore,
                    color: isHighRisk ? AppTheme.highRiskRed : const Color(0xFF92400E),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isHighRisk
                          ? 'HIGH RISK DESTINATION: ${dest.name}, ${dest.state}'
                          : 'Browsing Destination: ${dest.name}, ${dest.state}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isHighRisk ? AppTheme.highRiskRed : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onDestinationChanged?.call(null),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              if (hazard != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isHighRisk
                        ? AppTheme.highRiskRed.withValues(alpha: 0.1)
                        : AppTheme.cautionAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: isHighRisk ? AppTheme.highRiskRed : AppTheme.cautionAmber,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${hazard.name}: ${hazard.warningMessage}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isHighRisk ? AppTheme.highRiskRed : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                dest.safetyAdvisory,
                style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.onSelectNearbyCategory?.call(EmergencyCategory.all);
                      widget.onNavigateTab?.call(3);
                    },
                    icon: const Icon(Icons.local_hospital_outlined, size: 16),
                    label: Text('Emergency Services in ${dest.name}', style: const TextStyle(fontSize: 12)),
                  ),
                  if (isHighRisk && hazard != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.highRiskRed,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        EmergencyAlertModal.show(
                          context,
                          zone: hazard,
                          onNavigateTab: widget.onNavigateTab,
                        );
                      },
                      icon: const Icon(Icons.shield_outlined, size: 16),
                      label: const Text('View Hazard Advisory', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProminentSosCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.highRiskRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppTheme.highRiskRed,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sos, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency SOS Assistance',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF991B1B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Requires explicit confirmation on the SOS screen or direct 112 dial.',
                  style: TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.highRiskRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => widget.onNavigateTab?.call(2),
            child: const Text(
              'SOS',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMapPreview(bool gpsAvailable) {
    final center = gpsAvailable
        ? LatLng(_livePosition!.latitude, _livePosition!.longitude)
        : (widget.browsedDestination != null
            ? LatLng(
                widget.browsedDestination!.latitude,
                widget.browsedDestination!.longitude,
              )
            : const LatLng(19.0760, 72.8777));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Icon(Icons.map_outlined, color: AppTheme.teal, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Live Safety Map Preview',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => widget.onNavigateTab?.call(1),
                  icon: const Icon(Icons.open_in_full, size: 15),
                  label: const Text('Full Map', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 150,
            child: Stack(
              children: [
                FlutterMap(
                  key: ValueKey('${center.latitude}_${center.longitude}'),
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 14.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                    onTap: (_, __) => widget.onNavigateTab?.call(1),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.tourist_safety_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: center,
                          width: 42,
                          height: 42,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.teal,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 9, color: AppTheme.muted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrimeAnalyticsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppTheme.tealDark,
            AppTheme.teal,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.tealDark.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crime Risk & Safety Analytics',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'NCRB & Maharashtra Police Datasets',
                      style: TextStyle(color: AppTheme.tealTint, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Pre-loaded official NCRB statistics across 36 Indian States & UTs (Level A), 43 Maharashtra Police units (Level B), and live Open-Meteo weather context.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.tealDark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.bar_chart, size: 18),
                label: const Text('Open Analytics Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CrimeAnalysisScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialSourcesCard() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Official Indian Hazard & Advisory Portals',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Verify severe weather, flood alerts, and official travel advisories directly from government agencies:',
            style: TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openOfficialPortal('https://mausam.imd.gov.in'),
                icon: const Icon(Icons.thunderstorm_outlined, size: 16),
                label: const Text('IMD Weather Alerts', style: TextStyle(fontSize: 11)),
              ),
              OutlinedButton.icon(
                onPressed: () => _openOfficialPortal('https://sachet.ndma.gov.in'),
                icon: const Icon(Icons.flood_outlined, size: 16),
                label: const Text('NDMA Sachet Disaster Portal', style: TextStyle(fontSize: 11)),
              ),
              OutlinedButton.icon(
                onPressed: () => _openOfficialPortal('https://112.gov.in'),
                icon: const Icon(Icons.local_police_outlined, size: 16),
                label: const Text('ERSS 112 Portal', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
