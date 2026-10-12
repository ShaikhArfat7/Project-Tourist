import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/url_launcher_helper.dart';
import '../../core/utils/web_map_checker.dart';
import 'widgets/info_tile.dart';

class TrackingTab extends StatefulWidget {
  const TrackingTab({super.key});

  @override
  State<TrackingTab> createState() => _TrackingTabState();
}

class _TrackingTabState extends State<TrackingTab> {
  final LocationService _locationService = LocationService();

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStreamSubscription;

  LocationServiceStatus _status = LocationServiceStatus.ready;
  bool _isLoading = true;
  String? _statusMessage;

  Position? _currentPosition;
  String _address = 'Acquiring GPS location...';
  String _speedText = '0 km/h';
  String _accuracyText = '±--m';
  String _geofenceStatus = 'Detecting...';

  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to GPS satellites...';
    });

    final result = await _locationService.determinePosition();

    if (!mounted) return;

    if (result.status != LocationServiceStatus.ready || result.position == null) {
      setState(() {
        _isLoading = false;
        _status = result.status;
        _statusMessage = result.errorMessage ?? 'Unable to determine location.';
        _geofenceStatus = 'Offline';
      });
      return;
    }

    final pos = result.position!;
    _updatePositionData(pos);

    setState(() {
      _isLoading = false;
      _status = LocationServiceStatus.ready;
    });

    // Start real-time position updates
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

    // Calculate speed in km/h
    final kmh = pos.speed < 0 ? 0.0 : pos.speed * 3.6;
    _speedText = '${kmh.toStringAsFixed(0)} km/h';
    _accuracyText = '±${pos.accuracy.toStringAsFixed(0)}m';
    _geofenceStatus = 'Active (Safe)';

    final latLng = LatLng(pos.latitude, pos.longitude);

    // Update map marker
    _markers
      ..clear()
      ..add(
        Marker(
          markerId: const MarkerId('current_location_marker'),
          position: latLng,
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Tourist Safety Active',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );

    setState(() {});

    // Animate camera to follow on map
    _animateCameraToPosition(latLng);

    // Reverse geocode to resolve address
    _locationService.getAddressFromCoordinates(pos.latitude, pos.longitude).then((addr) {
      if (mounted) {
        setState(() => _address = addr);
      }
    });
  }

  void _animateCameraToPosition(LatLng latLng) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: latLng,
          zoom: 16.5,
          tilt: 0,
        ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentPosition != null) {
      _animateCameraToPosition(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Location',
            onPressed: _initializeLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          // Upper Section (flex: 3): Interactive Map or Graceful State Fallback
          Expanded(
            flex: 3,
            child: _buildMapSection(),
          ),

          // Lower Section (flex: 2): Telemetry Panel
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Location',
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
                        label: 'Geo-Fence',
                        value: _geofenceStatus,
                        icon: Icons.fence,
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
                      label: const Text('Share Live Location'),
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
        color: const Color(0xFFE8D5C4),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.orange),
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

    if (_status == LocationServiceStatus.serviceDisabled) {
      return _buildNoticeCard(
        icon: Icons.location_off_rounded,
        title: 'Location Services Disabled',
        description:
            'Please turn on your device GPS location to view your real-time tracking map and safety perimeter.',
        buttonLabel: 'Enable Location',
        onPressed: () async {
          await _locationService.openLocationSettings();
          _initializeLocation();
        },
      );
    }

    if (_status == LocationServiceStatus.permissionDenied) {
      return _buildNoticeCard(
        icon: Icons.location_searching_rounded,
        title: 'Location Permission Needed',
        description:
            'Tourist Safety Monitor requires location permissions to display live tracking and monitor safe zones.',
        buttonLabel: 'Grant Permission',
        onPressed: _initializeLocation,
      );
    }

    if (_status == LocationServiceStatus.permissionDeniedForever) {
      return _buildNoticeCard(
        icon: Icons.lock_outline_rounded,
        title: 'Permission Permanently Denied',
        description:
            'Location access is blocked in Android settings. Please enable location permissions in App Info.',
        buttonLabel: 'Open App Settings',
        onPressed: () async {
          await _locationService.openAppSettings();
          _initializeLocation();
        },
      );
    }

    if (_currentPosition == null) {
      return _buildNoticeCard(
        icon: Icons.gps_off_rounded,
        title: 'No GPS Fix',
        description: 'Unable to acquire satellite coordinates. Please retry.',
        buttonLabel: 'Retry GPS',
        onPressed: _initializeLocation,
      );
    }

    // Graceful Web Handling:
    // If running in Chrome and Google Maps JS SDK is not yet loaded or initialized,
    // render an interactive Web preview card to prevent browser crashes.
    if (kIsWeb && !isGoogleMapsWebReady()) {
      return _buildWebFallbackCard();
    }

    // Real Google Map
    final initialTarget = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: 16.5,
          ),
          onMapCreated: _onMapCreated,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          markers: _markers,
        ),
        // Floating Recenter Button
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'tracking_recenter_fab',
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.orangeDark,
            elevation: 3,
            tooltip: 'Center on my location',
            onPressed: () {
              if (_currentPosition != null) {
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

  Widget _buildWebFallbackCard() {
    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;

    return Container(
      width: double.infinity,
      color: const Color(0xFFE8D5C4),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map_outlined, size: 52, color: AppTheme.orange),
              const SizedBox(height: 12),
              const Text(
                'Live GPS Active (Web Preview)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Real coordinates: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}\n\n'
                '• Android is your primary target and runs native Google Maps.\n'
                '• To view embedded maps in Chrome, add your Google Maps Web API key to web/index.html.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      UrlLauncherHelper.openMapDirections(
                        context,
                        _address,
                        lat: lat,
                        lng: lng,
                      );
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open in Google Maps'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _initializeLocation,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.orangeDark,
                      side: const BorderSide(color: AppTheme.orange),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
      color: const Color(0xFFE8D5C4),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 52, color: AppTheme.orange),
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
              ElevatedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(buttonLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
