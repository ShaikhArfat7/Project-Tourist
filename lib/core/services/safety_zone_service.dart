import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Three-tier risk classification:
/// - LOW: No known hazard identified by available data (never claims "definitively safe")
/// - CAUTION: Display potential hazard and recommended precautions
/// - HIGH_RISK: Prominent warning with option to view details or contact emergency services
///   (SOS is NEVER triggered automatically; tourist must explicitly confirm)
enum RiskTier {
  low,
  caution,
  highRisk,
}

extension RiskTierExtension on RiskTier {
  String get badgeLabel {
    switch (this) {
      case RiskTier.low:
        return 'LOW';
      case RiskTier.caution:
        return 'CAUTION';
      case RiskTier.highRisk:
        return 'HIGH RISK';
    }
  }

  String get headline {
    switch (this) {
      case RiskTier.low:
        return 'LOW: No Known Hazard Identified';
      case RiskTier.caution:
        return 'CAUTION: Advisory in Your Area';
      case RiskTier.highRisk:
        return 'HIGH RISK: Hazard Zone Detected';
    }
  }
}

class HazardZone {
  final String id;
  final String name;
  final String city;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final RiskTier riskTier;
  final String dataCategory; // GENERAL_SAFETY_ADVISORY, LIVE_WEATHER_METEOROLOGICAL, DEMONSTRATION_DATA
  final String source;
  final String hazardType;
  final String warningMessage;
  final String recommendedAction;
  final double? distanceMeters;

  const HazardZone({
    required this.id,
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.riskTier,
    required this.dataCategory,
    required this.source,
    required this.hazardType,
    required this.warningMessage,
    required this.recommendedAction,
    this.distanceMeters,
  });

  bool get isDemoData => dataCategory == 'DEMONSTRATION_DATA';

  String get categoryBadgeLabel {
    switch (dataCategory) {
      case 'DEMONSTRATION_DATA':
        return 'DEMO / SIMULATION DATA';
      case 'LIVE_WEATHER_METEOROLOGICAL':
        return 'LIVE METEOROLOGICAL DATA';
      default:
        return 'GENERAL SAFETY ADVISORY';
    }
  }

  HazardZone copyWithDistance(double meters) => HazardZone(
        id: id,
        name: name,
        city: city,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        riskTier: riskTier,
        dataCategory: dataCategory,
        source: source,
        hazardType: hazardType,
        warningMessage: warningMessage,
        recommendedAction: recommendedAction,
        distanceMeters: meters,
      );

  factory HazardZone.fromJson(Map<String, dynamic> json) {
    final rawRisk = (json['riskLevel'] as String? ?? 'CAUTION').toUpperCase();
    final RiskTier tier;
    if (rawRisk == 'HIGH_RISK' || rawRisk == 'DANGER') {
      tier = RiskTier.highRisk;
    } else if (rawRisk == 'CAUTION') {
      tier = RiskTier.caution;
    } else {
      tier = RiskTier.low;
    }

    return HazardZone(
      id: json['id'] as String? ?? 'unknown',
      name: json['name'] as String? ?? 'Safety Advisory Zone',
      city: json['city'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radiusMeters'] as num).toDouble(),
      riskTier: tier,
      dataCategory: json['dataCategory'] as String? ?? 'GENERAL_SAFETY_ADVISORY',
      source: json['source'] as String? ?? 'Curated Tourist Safety Advisory Dataset',
      hazardType: json['hazardType'] as String? ?? 'Local Safety Precaution',
      warningMessage: json['warningMessage'] as String? ?? '',
      recommendedAction: json['recommendedAction'] as String? ?? '',
    );
  }
}

class LiveWeatherSummary {
  final double temperatureCelsius;
  final double windSpeedKmh;
  final double precipitationMm;
  final int weatherCode;
  final String conditionText;
  final RiskTier weatherRisk;
  final String? advisoryMessage;
  final DateTime fetchedAt;

  const LiveWeatherSummary({
    required this.temperatureCelsius,
    required this.windSpeedKmh,
    required this.precipitationMm,
    required this.weatherCode,
    required this.conditionText,
    required this.weatherRisk,
    this.advisoryMessage,
    required this.fetchedAt,
  });
}

class SafetyEvaluationResult {
  final RiskTier overallTier;
  final List<HazardZone> activeZones; // Zones the user is currently inside
  final List<HazardZone> nearbyZones; // Zones within 15 km for awareness
  final LiveWeatherSummary? weather;
  final DateTime evaluatedAt;
  final String evidenceSummary;

  const SafetyEvaluationResult({
    required this.overallTier,
    required this.activeZones,
    required this.nearbyZones,
    this.weather,
    required this.evaluatedAt,
    required this.evidenceSummary,
  });
}

class SafetyZoneService extends ChangeNotifier {
  static final SafetyZoneService _instance = SafetyZoneService._internal();
  factory SafetyZoneService() => _instance;
  SafetyZoneService._internal();

  List<HazardZone> _bundledZones = [];
  bool _loaded = false;
  bool _panvelDemoEnabled = false;
  bool _nerulDemoEnabled = false;

  /// Tracks zone IDs that have already shown a popup dialog during this session
  /// so the user is never spammed with repeated dialogs.
  final Set<String> _acknowledgedZoneIds = {};

  SafetyEvaluationResult? _currentEvaluation;
  SafetyEvaluationResult? get currentEvaluation => _currentEvaluation;

  static HazardZone get panvelDemoZone => _panvelDemoZone;
  static HazardZone get nerulDemoZone => _nerulDemoZone;

  HazardZone? get activeHighRiskZone {
    final active = _currentEvaluation?.activeZones;
    if (active == null || active.isEmpty) return null;
    for (final z in active) {
      if (z.riskTier == RiskTier.highRisk) return z;
    }
    return null;
  }

  bool get isHighRiskActive => activeHighRiskZone != null;

  bool get panvelDemoEnabled => _panvelDemoEnabled;
  bool get nerulDemoEnabled => _nerulDemoEnabled;

  static const HazardZone _panvelDemoZone = HazardZone(
    id: 'dz_panvel_demo_simulation',
    name: 'Panvel Geofence Simulation Zone (High Alert)',
    city: 'Panvel',
    latitude: 18.9894,
    longitude: 73.1175,
    radiusMeters: 8000,
    riskTier: RiskTier.highRisk,
    dataCategory: 'DEMONSTRATION_DATA',
    source: '[DEMO DATA] Presentation Geofence Demo (High Risk / Red Alert)',
    hazardType: 'Simulated High-Risk Geofence Zone (Presentation Demo)',
    warningMessage:
        'DEMONSTRATION ONLY: Your GPS coordinates matched the Panvel 8 km Red Geofence boundary configured for project evaluation.',
    recommendedAction:
        'Demonstrates how an immediate HIGH RISK RED ALERT popup appears with 112 quick dial and SOS action.',
  );

  static const HazardZone _nerulDemoZone = HazardZone(
    id: 'dz_nerul_demo_simulation',
    name: 'Nerul Geofence Simulation Zone (Medium Alert)',
    city: 'Nerul, Navi Mumbai',
    latitude: 19.0330,
    longitude: 73.0197,
    radiusMeters: 8000,
    riskTier: RiskTier.caution,
    dataCategory: 'DEMONSTRATION_DATA',
    source: '[DEMO DATA] Presentation Geofence Demo (Medium Risk / Caution Alert)',
    hazardType: 'Simulated Moderate / Caution Geofence Zone (Presentation Demo)',
    warningMessage:
        'DEMONSTRATION ONLY: Your GPS coordinates matched the Nerul 8 km Medium-Risk Geofence boundary configured for project evaluation.',
    recommendedAction:
        'Demonstrates how a CAUTION / MEDIUM RISK advisory popup appears when a tourist enters a cautionary zone.',
  );

  Future<void> loadZones({bool forceReload = false}) async {
    if (_loaded && !forceReload) return;
    try {
      final raw = await rootBundle.loadString('assets/data/danger_zones.json');
      final decoded = jsonDecode(raw) as List<dynamic>;
      _bundledZones = decoded
          .map((e) => HazardZone.fromJson(e as Map<String, dynamic>))
          .toList();
      _loaded = true;
    } catch (e) {
      debugPrint('Error loading danger_zones.json: $e');
      _bundledZones = [];
      _loaded = true;
    }
  }

  void setPanvelDemoEnabled(bool enabled) {
    _panvelDemoEnabled = enabled;
    _acknowledgedZoneIds.remove(_panvelDemoZone.id);
    notifyListeners();
  }

  void setNerulDemoEnabled(bool enabled) {
    _nerulDemoEnabled = enabled;
    _acknowledgedZoneIds.remove(_nerulDemoZone.id);
    notifyListeners();
  }

  bool hasAcknowledgedZone(String zoneId) => _acknowledgedZoneIds.contains(zoneId);

  void markZoneAcknowledged(String zoneId) {
    _acknowledgedZoneIds.add(zoneId);
  }

  void clearAcknowledgedZone(String zoneId) {
    _acknowledgedZoneIds.remove(zoneId);
  }

  void resetAllZoneAcknowledgments() {
    _acknowledgedZoneIds.clear();
    notifyListeners();
  }

  List<HazardZone> get allConfiguredZones {
    final list = List<HazardZone>.from(_bundledZones);
    if (_panvelDemoEnabled && !list.any((z) => z.id == _panvelDemoZone.id)) {
      list.insert(0, _panvelDemoZone);
    }
    if (_nerulDemoEnabled && !list.any((z) => z.id == _nerulDemoZone.id)) {
      list.insert(0, _nerulDemoZone);
    }
    return list;
  }

  Future<HazardZone?> evaluateCoordinatesForHazard(
    double lat,
    double lon, {
    double radiusExtensionMeters = 1500,
  }) async {
    await loadZones();
    for (final zone in allConfiguredZones) {
      final dist = Geolocator.distanceBetween(
        lat,
        lon,
        zone.latitude,
        zone.longitude,
      );
      if (dist <= zone.radiusMeters + radiusExtensionMeters) {
        return zone.copyWithDistance(dist);
      }
    }
    return null;
  }

  Future<SafetyEvaluationResult> evaluateLocation(
    double latitude,
    double longitude, {
    bool fetchWeather = true,
  }) async {
    await loadZones();
    final now = DateTime.now();
    final zones = allConfiguredZones;

    final active = <HazardZone>[];
    final nearby = <HazardZone>[];

    for (final zone in zones) {
      final distMeters = Geolocator.distanceBetween(
        latitude,
        longitude,
        zone.latitude,
        zone.longitude,
      );
      final withDist = zone.copyWithDistance(distMeters);
      if (distMeters <= zone.radiusMeters) {
        active.add(withDist);
      } else if (distMeters <= 25000) {
        nearby.add(withDist);
      }
    }

    active.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
    nearby.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));

    LiveWeatherSummary? weather;
    if (fetchWeather) {
      weather = await _fetchLiveWeather(latitude, longitude);
    }

    RiskTier overall = RiskTier.low;
    for (final z in active) {
      if (z.riskTier == RiskTier.highRisk) {
        overall = RiskTier.highRisk;
        break;
      } else if (z.riskTier == RiskTier.caution && overall == RiskTier.low) {
        overall = RiskTier.caution;
      }
    }

    if (weather != null) {
      if (weather.weatherRisk == RiskTier.highRisk) {
        overall = RiskTier.highRisk;
      } else if (weather.weatherRisk == RiskTier.caution && overall == RiskTier.low) {
        overall = RiskTier.caution;
      }
    }

    final checkedSources = <String>[
      'Curated Geofence Advisory Dataset (${zones.length} zones checked)',
      if (weather != null) 'Open-Meteo Live Weather Telemetry',
    ];

    final evidence = active.isEmpty && (weather == null || weather.weatherRisk == RiskTier.low)
        ? 'No active hazards matched at (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}). '
            'Checked: ${checkedSources.join(" + ")}. '
            'Note: Absence of mapped advisories does not guarantee complete safety—always check official IMD (mausam.imd.gov.in) and NDMA Sachet (sachet.ndma.gov.in) alerts.'
        : 'Matched ${active.length} active zone(s) at current coordinates. Checked: ${checkedSources.join(" + ")}.';

    final result = SafetyEvaluationResult(
      overallTier: overall,
      activeZones: active,
      nearbyZones: nearby,
      weather: weather,
      evaluatedAt: now,
      evidenceSummary: evidence,
    );

    _currentEvaluation = result;
    return result;
  }

  Future<LiveWeatherSummary?> _fetchLiveWeather(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${lat.toStringAsFixed(4)}&longitude=${lon.toStringAsFixed(4)}'
        '&current=temperature_2m,precipitation,weather_code,wind_speed_10m',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>?;
      if (current == null) return null;

      final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 28.0;
      final precip = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
      final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;
      final code = (current['weather_code'] as num?)?.toInt() ?? 0;

      final condition = _wmoConditionText(code);
      RiskTier tier = RiskTier.low;
      String? advisory;

      if (code >= 95 || precip >= 15.0 || wind >= 60.0 || temp >= 43.0) {
        tier = RiskTier.highRisk;
        advisory =
            'Severe weather conditions detected ($condition, ${temp.toStringAsFixed(1)}°C, wind ${wind.toStringAsFixed(0)} km/h). Check official IMD warnings at mausam.imd.gov.in.';
      } else if (code >= 63 || precip >= 5.0 || wind >= 40.0 || temp >= 40.0) {
        tier = RiskTier.caution;
        advisory =
            'Moderate weather advisory ($condition, ${temp.toStringAsFixed(1)}°C). Exercise caution on outdoor trails and coastal roads.';
      }

      return LiveWeatherSummary(
        temperatureCelsius: temp,
        windSpeedKmh: wind,
        precipitationMm: precip,
        weatherCode: code,
        conditionText: condition,
        weatherRisk: tier,
        advisoryMessage: advisory,
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Live weather check failed: $e');
      return null;
    }
  }

  String _wmoConditionText(int code) {
    if (code == 0) return 'Clear sky';
    if (code <= 3) return 'Partly cloudy';
    if (code == 45 || code == 48) return 'Fog / Reduced visibility';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 65) return 'Rain';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Variable weather';
  }
}
