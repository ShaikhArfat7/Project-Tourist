import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

enum LocationServiceStatus {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

class LocationResult {
  final LocationServiceStatus status;
  final Position? position;
  final String? errorMessage;

  LocationResult({
    required this.status,
    this.position,
    this.errorMessage,
  });
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _cachedPosition;
  DateTime? _cachedPositionTime;

  Position? get lastKnownPosition => _cachedPosition;

  void updateCachedPosition(Position pos) {
    _cachedPosition = pos;
    _cachedPositionTime = DateTime.now();
  }

  /// Checks location services and permissions, returning current position if available.
  Future<LocationResult> determinePosition({bool forceFresh = false}) async {
    // Return fresh cached position instantly to prevent UI reload lag across tabs
    if (!forceFresh &&
        _cachedPosition != null &&
        _cachedPositionTime != null &&
        DateTime.now().difference(_cachedPositionTime!) < const Duration(seconds: 45)) {
      return LocationResult(
        status: LocationServiceStatus.ready,
        position: _cachedPosition,
      );
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          status: LocationServiceStatus.serviceDisabled,
          errorMessage: 'Device location services (GPS) are turned off.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            status: LocationServiceStatus.permissionDenied,
            errorMessage: 'Location permission was denied by the user.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          status: LocationServiceStatus.permissionDeniedForever,
          errorMessage:
              'Location permission is permanently denied. Please enable it in system settings.',
        );
      }

      // Quick check for platform last known position to eliminate delay
      final quickLast = await Geolocator.getLastKnownPosition();
      if (quickLast != null && _cachedPosition == null) {
        _cachedPosition = quickLast;
        _cachedPositionTime = DateTime.now();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      _cachedPosition = position;
      _cachedPositionTime = DateTime.now();

      return LocationResult(
        status: LocationServiceStatus.ready,
        position: position,
      );
    } catch (e) {
      if (_cachedPosition != null) {
        return LocationResult(
          status: LocationServiceStatus.ready,
          position: _cachedPosition,
        );
      }
      debugPrint('Error getting location: $e');
      return LocationResult(
        status: LocationServiceStatus.error,
        errorMessage: 'Failed to obtain GPS fix: $e',
      );
    }
  }

  /// Live GPS position stream with high-precision navigation accuracy
  Stream<Position> getPositionStream({int distanceFilter = 2}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter,
      ),
    );
  }

  /// Reverse geocoding to obtain detailed human-readable street address on both Web and Mobile
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    final coordsText = '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    if (!kIsWeb) {
      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(latitude, longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final rawParts = <String?>[
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
          ];
          final parts = <String>[];
          for (final part in rawParts) {
            final trimmed = part?.trim() ?? '';
            if (trimmed.isNotEmpty && !parts.contains(trimmed)) {
              parts.add(trimmed);
            }
          }
          if (parts.isNotEmpty) {
            return '${parts.join(', ')} ($coordsText)';
          }
        }
      } catch (e) {
        debugPrint('Native geocoding error: $e');
      }
    }

    // Web & Fallback reverse geocoding via OpenStreetMap Nominatim
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: {'Accept-Language': 'en'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.trim().isNotEmpty) {
          return displayName;
        }
      }
    } catch (e) {
      debugPrint('Web reverse geocoding error: $e');
    }

    return 'GPS: $coordsText';
  }

  /// Calculates distance in kilometers between two coordinate pairs
  double distanceInKm(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    final meters = Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
    return meters / 1000.0;
  }

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
