import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/destination_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/safety_zone_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/url_launcher_helper.dart';
import '../dashboard/widgets/emergency_alert_modal.dart';
import '../destinations/destinations_sheet.dart';
import 'widgets/info_tile.dart';

class TrackingTab extends StatefulWidget {
  final TouristDestination? browsedDestination;
  final ValueChanged<TouristDestination?>? onDestinationChanged;

  const TrackingTab({
    super.key,
    this.browsedDestination,
    this.onDestinationChanged,
  });

  @override
  State<TrackingTab> createState() => _TrackingTabState();
}

class _TrackingTabState extends State<TrackingTab> {
  final LocationService _locationService = LocationService();
  final SafetyZoneService _safetyZoneService = SafetyZoneService();
  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionStreamSubscription;

  LocationServiceStatus _status = LocationServiceStatus.ready;
  bool _isLoading = true;
  bool _mapReady = false;
  String? _statusMessage;

  Position? _currentPosition;
  String _address = 'Acquiring GPS location...';
  String _speedText = '0 km/h';
  String _accuracyText = '±--m';
  String _geofenceStatus = 'Detecting...';
  SafetyEvaluationResult? _safetyEval;

  @override
  void initState() {
    super.initState();
    _safetyZoneService.addListener(_onZonesChanged);
    _initializeLocation();
  }

  @override
  void didUpdateWidget(covariant TrackingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.browsedDestination?.id != oldWidget.browsedDestination?.id &&
        _mapReady) {
      if (widget.browsedDestination != null) {
        _animateCameraToPosition(
          LatLng(
            widget.browsedDestination!.latitude,
            widget.browsedDestination!.longitude,
          ),
          zoom: 13.5,
        );
      } else if (_currentPosition != null) {
        _animateCameraToPosition(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        );
      }
    }
  }

  @override
  void dispose() {
    _safetyZoneService.removeListener(_onZonesChanged);
    _positionStreamSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _onZonesChanged() {
    if (_currentPosition != null) {
      _evaluateGeofence(_currentPosition!);
    }
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to GPS satellites...';
    });

    await _safetyZoneService.loadZones();
    final result = await _locationService.determinePosition();

    if (!mounted) return;

    if (result.status != LocationServiceStatus.ready || result.position == null) {
      setState(() {
        _isLoading = false;
        _status = result.status;
        _statusMessage = result.errorMessage ?? 'Unable to determine location.';
        _geofenceStatus = 'Unavailable';
      });
      return;
    }

    final pos = result.position!;
    setState(() {
      _isLoading = false;
      _status = LocationServiceStatus.ready;
    });

    _updatePositionData(pos);
    _startPositionStreaming();
  }

  void _startPositionStreaming() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = _locationService.getPositionStream().listen(
      (Position pos) {
        if (!mounted) return;
        _updatePositionData(pos);
      },
      onError: (err) {
        debugPrint('Position stream error: $err');
      },
    );
  }

  void _updatePositionData(Position pos) {
    _currentPosition = pos;

    final kmh = pos.speed < 0 ? 0.0 : pos.speed * 3.6;
    _speedText = '${kmh.toStringAsFixed(0)} km/h';
    _accuracyText = '±${pos.accuracy.toStringAsFixed(0)}m';

    final latLng = LatLng(pos.latitude, pos.longitude);
    setState(() {});

    if (_mapReady && widget.browsedDestination == null) {
      _animateCameraToPosition(latLng);
    }

    _locationService.getAddressFromCoordinates(pos.latitude, pos.longitude).then((addr) {
      if (mounted) {
        setState(() => _address = addr);
      }
    });

    _evaluateGeofence(pos);
  }

  Future<void> _evaluateGeofence(Position pos) async {
    final eval = await _safetyZoneService.evaluateLocation(
      pos.latitude,
      pos.longitude,
      fetchWeather: false,
    );
    if (!mounted) return;
    setState(() {
      _safetyEval = eval;
      _geofenceStatus = eval.overallTier.badgeLabel;
    });

    for (final zone in eval.activeZones) {
      if (!_safetyZoneService.hasAcknowledgedZone(zone.id)) {
        _safetyZoneService.markZoneAcknowledged(zone.id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (zone.riskTier == RiskTier.highRisk) {
            _showHighRiskModal(zone);
          } else {
            _showCautionModal(zone);
          }
        });
        break;
      }
    }
  }

  void _showHighRiskModal(HazardZone zone) {
    EmergencyAlertModal.show(
      context,
      zone: zone,
    );
  }

  void _showCautionModal(HazardZone zone) {
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I Understand'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              UrlLauncherHelper.callNumber(context, '1363');
            },
            icon: const Icon(Icons.support_agent, size: 16),
            label: const Text('Tourist Helpline 1363'),
          ),
        ],
      ),
    );
  }

  void _animateCameraToPosition(LatLng latLng, {double zoom = 15.5}) {
    if (!_mapReady) return;
    try {
      _mapController.move(latLng, zoom);
    } catch (e) {
      debugPrint('Map move error: $e');
    }
  }

  void _openDestinationPicker() {
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

  @override
  Widget build(BuildContext context) {
    final dest = widget.browsedDestination;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Safety Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.travel_explore),
            tooltip: 'Browse Destination on Map',
            onPressed: _openDestinationPicker,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh GPS Location',
            onPressed: _initializeLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          if (dest != null)
            Container(
              width: double.infinity,
              color: const Color(0xFFFEF3C7),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.travel_explore, size: 18, color: Color(0xFF92400E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Viewing Destination: ${dest.name}, ${dest.state} (Not your live GPS)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onDestinationChanged?.call(null),
                    child: const Text('Return to Live GPS'),
                  ),
                ],
              ),
            ),

          // Upper Section: Interactive Map
          Expanded(
            flex: 3,
            child: _buildMapSection(),
          ),

          // Lower Section: Telemetry Panel
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Live GPS Telemetry',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      InfoTile(
                        label: 'Risk Tier',
                        value: _geofenceStatus,
                        icon: Icons.shield_outlined,
                      ),
                      const SizedBox(width: 12),
                      InfoTile(
                        label: 'Speed',
                        value: _speedText,
                        icon: Icons.speed,
                      ),
                      const SizedBox(width: 12),
                      InfoTile(
                        label: 'Accuracy',
                        value: _accuracyText,
                        icon: Icons.gps_fixed,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.share_location),
                      label: const Text('Share Live GPS Coordinates'),
                      onPressed: _currentPosition == null
                          ? null
                          : () {
                              final lat = _currentPosition!.latitude;
                              final lng = _currentPosition!.longitude;
                              final mapUrl = 'https://maps.google.com/?q=$lat,$lng';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Emergency GPS Link: $mapUrl\nAddress: $_address',
                                  ),
                                  duration: const Duration(seconds: 4),
                                  action: SnackBarAction(
                                    label: 'Open',
                                    textColor: Colors.white,
                                    onPressed: () {
                                      UrlLauncherHelper.openMapDirections(
                                        context,
                                        _address,
                                        lat: lat,
                                        lng: lng,
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    if (_isLoading) {
      return Container(
        color: AppTheme.surfaceBg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.teal),
              const SizedBox(height: 16),
              Text(
                _statusMessage ?? 'Detecting GPS coordinates...',
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if ((_status != LocationServiceStatus.ready || _currentPosition == null) &&
        widget.browsedDestination == null) {
      return _buildNoticeCard(
        icon: Icons.location_off_rounded,
        title: 'Location Access Required',
        description: _statusMessage ??
            'Enable device GPS to view your live safety map, or browse a tourist destination.',
        buttonLabel: 'Retry Live GPS',
        onPressed: _initializeLocation,
      );
    }

    final liveLatLng = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : null;
    final dest = widget.browsedDestination;
    final initialTarget = dest != null
        ? LatLng(dest.latitude, dest.longitude)
        : (liveLatLng ?? const LatLng(19.0760, 72.8777));

    final zones = _safetyZoneService.allConfiguredZones;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialTarget,
            initialZoom: dest != null ? 13.5 : 15.5,
            onMapReady: () {
              _mapReady = true;
              _animateCameraToPosition(initialTarget, zoom: dest != null ? 13.5 : 15.5);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.tourist_safety_app',
            ),
            CircleLayer(
              circles: [
                if (liveLatLng != null)
                  CircleMarker(
                    point: liveLatLng,
                    radius: 120,
                    useRadiusInMeter: true,
                    color: AppTheme.teal.withValues(alpha: 0.14),
                    borderColor: AppTheme.teal,
                    borderStrokeWidth: 2,
                  ),
                ...zones.map((z) {
                  final c = z.riskTier == RiskTier.highRisk
                      ? AppTheme.highRiskRed
                      : AppTheme.cautionAmber;
                  return CircleMarker(
                    point: LatLng(z.latitude, z.longitude),
                    radius: z.radiusMeters,
                    useRadiusInMeter: true,
                    color: c.withValues(alpha: 0.18),
                    borderColor: c,
                    borderStrokeWidth: 2,
                  );
                }),
              ],
            ),
            MarkerLayer(
              markers: [
                if (liveLatLng != null)
                  Marker(
                    point: liveLatLng,
                    width: 56,
                    height: 56,
                    child: Container(
                      padding: const EdgeInsets.all(6),
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
                if (dest != null)
                  Marker(
                    point: LatLng(dest.latitude, dest.longitude),
                    width: 52,
                    height: 52,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.cautionAmber,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: const Icon(
                        Icons.travel_explore,
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
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: _safetyEval?.overallTier == RiskTier.highRisk
                      ? AppTheme.highRiskRed
                      : AppTheme.teal,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Risk Tier: $_geofenceStatus',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '© OpenStreetMap contributors (ODbL)',
              style: TextStyle(fontSize: 10, color: AppTheme.muted),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'tracking_recenter_fab',
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.tealDark,
            elevation: 3,
            tooltip: 'Center on my live GPS location',
            onPressed: () {
              if (_currentPosition != null) {
                widget.onDestinationChanged?.call(null);
                _animateCameraToPosition(
                  LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                );
              }
            },
            child: const Icon(Icons.my_location, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      color: AppTheme.surfaceBg,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 52, color: AppTheme.teal),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.my_location, size: 18),
                    label: Text(buttonLabel),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openDestinationPicker,
                    icon: const Icon(Icons.travel_explore, size: 18),
                    label: const Text('Browse Destination'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
