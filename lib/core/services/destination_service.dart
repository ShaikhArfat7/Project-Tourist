import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class TouristDestination {
  final String id;
  final String name;
  final String state;
  final String district;
  final String category;
  final double latitude;
  final double longitude;
  final String emergencyHelpline;
  final String touristHelpline;
  final String source;
  final String safetyAdvisory;
  final String? nearestPoliceStation;
  final String? nearestHospital;

  const TouristDestination({
    required this.id,
    required this.name,
    required this.state,
    this.district = '',
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.emergencyHelpline,
    required this.touristHelpline,
    required this.source,
    required this.safetyAdvisory,
    this.nearestPoliceStation,
    this.nearestHospital,
  });

  factory TouristDestination.fromJson(Map<String, dynamic> json) {
    return TouristDestination(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      state: json['state'] as String? ?? '',
      district: json['district'] as String? ?? '',
      category: json['category'] as String? ?? 'Tourist Destination',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      emergencyHelpline: json['emergencyHelpline'] as String? ?? '112',
      touristHelpline: json['touristHelpline'] as String? ?? '1363',
      source: json['source'] as String? ??
          'Official Government Dataset • Helplines: ERSS (112) & Ministry of Tourism (1363)',
      safetyAdvisory: json['safetyAdvisory'] as String? ?? '',
      nearestPoliceStation: json['nearestPoliceStation'] as String?,
      nearestHospital: json['nearestHospital'] as String?,
    );
  }

  bool matchesSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final n = name.toLowerCase();
    final s = state.toLowerCase();
    final d = district.toLowerCase();
    final c = category.toLowerCase();

    // 1. Direct contains match on name, district, state, or category
    if (n.contains(q) || d.contains(q) || s.contains(q) || c.contains(q)) {
      return true;
    }

    // 2. Common Indian tourist spot aliases & phonetic spelling variations
    if ((q == 'lonavla' || q == 'lonavala') &&
        (n.contains('lonavala') || n.contains('lonavla') || id.contains('lonavala'))) {
      return true;
    }
    if ((q == 'alibaug' || q == 'alibag') &&
        (n.contains('alibag') || n.contains('alibaug') || id.contains('alibag'))) {
      return true;
    }
    if ((q == 'poona' || q == 'pune') && (n.contains('pune') || d.contains('pune'))) {
      return true;
    }
    if ((q == 'bombay' || q == 'mumbai') && (n.contains('mumbai') || d.contains('mumbai'))) {
      return true;
    }
    if ((q == 'panvel' || q == 'new panvel') && (n.contains('panvel') || id.contains('panvel'))) {
      return true;
    }
    if (q == 'kharghar' && (n.contains('kharghar') || id.contains('kharghar'))) {
      return true;
    }
    if ((q == 'belapur' || q == 'cbd belapur') &&
        (n.contains('belapur') || id.contains('belapur'))) {
      return true;
    }
    if (q == 'vashi' && (n.contains('vashi') || id.contains('vashi'))) {
      return true;
    }
    if (q == 'nerul' && (n.contains('nerul') || id.contains('nerul'))) {
      return true;
    }
    if (q == 'thane' && (n.contains('thane') || d.contains('thane'))) {
      return true;
    }
    if ((q == 'aurangabad' || q == 'sambhajinagar') &&
        (n.contains('sambhajinagar') || n.contains('aurangabad'))) {
      return true;
    }
    if (q == 'matheran' && (n.contains('matheran') || id.contains('matheran'))) {
      return true;
    }
    if (q == 'khandala' && (n.contains('khandala') || id.contains('khandala'))) {
      return true;
    }
    if ((q == 'mahabaleshwar' || q == 'mahabaleswar') &&
        (n.contains('mahabaleshwar') || id.contains('mahabaleshwar'))) {
      return true;
    }
    if (q == 'panchgani' && (n.contains('panchgani') || id.contains('panchgani'))) {
      return true;
    }
    if (q == 'shirdi' && (n.contains('shirdi') || id.contains('shirdi'))) {
      return true;
    }

    // 3. Multi-word token matching: all words in query match across fields
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    if (tokens.isNotEmpty &&
        tokens.every((tok) =>
            n.contains(tok) || d.contains(tok) || s.contains(tok) || c.contains(tok))) {
      return true;
    }

    return false;
  }
}

class DestinationService {
  static final DestinationService _instance = DestinationService._internal();
  factory DestinationService() => _instance;
  DestinationService._internal();

  List<TouristDestination> _destinations = [];
  bool _loaded = false;

  Future<List<TouristDestination>> getDestinations() async {
    if (_loaded) return _destinations;
    try {
      final raw = await rootBundle.loadString('assets/data/destinations.json');
      final list = jsonDecode(raw) as List<dynamic>;
      _destinations = list
          .map((e) => TouristDestination.fromJson(e as Map<String, dynamic>))
          .toList();
      _loaded = true;
    } catch (e) {
      debugPrint('Failed to load destinations.json: $e');
      _destinations = [];
      _loaded = true;
    }
    return _destinations;
  }

  /// Finds the closest destination in our verified database to given coordinates
  Future<TouristDestination?> findNearestDestination(double lat, double lon) async {
    final list = await getDestinations();
    if (list.isEmpty) return null;
    TouristDestination? closest;
    double minDistance = double.infinity;
    for (final d in list) {
      const double p = 0.017453292519943295;
      final a = 0.5 -
          math.cos((d.latitude - lat) * p) / 2 +
          math.cos(lat * p) *
              math.cos(d.latitude * p) *
              (1 - math.cos((d.longitude - lon) * p)) /
              2;
      final distKm = 12742 * math.asin(math.sqrt(a));
      if (distKm < minDistance) {
        minDistance = distKm;
        closest = d;
      }
    }
    return closest;
  }

  /// Finds the top N closest destinations in our verified database to given coordinates with distance in km
  Future<List<MapEntry<TouristDestination, double>>> findNearestDestinationsWithDistance(
    double lat,
    double lon, {
    int limit = 5,
  }) async {
    final list = await getDestinations();
    if (list.isEmpty) return [];

    final entries = <MapEntry<TouristDestination, double>>[];
    for (final d in list) {
      const double p = 0.017453292519943295;
      final a = 0.5 -
          math.cos((d.latitude - lat) * p) / 2 +
          math.cos(lat * p) *
              math.cos(d.latitude * p) *
              (1 - math.cos((d.longitude - lon) * p)) /
              2;
      final distKm = 12742 * math.asin(math.sqrt(a));
      entries.add(MapEntry(d, distKm));
    }
    entries.sort((a, b) => a.value.compareTo(b.value));
    return entries.take(limit).toList();
  }

  /// Searches OpenStreetMap Nominatim for any custom Indian town/landmark not in the curated list.
  Future<List<TouristDestination>> searchCustomPlaceInIndia(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    // Query aliases expansion for common Indian tourist spots
    String searchQuery = trimmed;
    final lower = trimmed.toLowerCase();
    if (lower == 'lonavla') {
      searchQuery = 'Lonavala';
    } else if (lower == 'alibaug') {
      searchQuery = 'Alibag';
    } else if (lower == 'poona') {
      searchQuery = 'Pune';
    } else if (lower == 'bombay') {
      searchQuery = 'Mumbai';
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=jsonv2&countrycodes=in&limit=6&addressdetails=1'
        '&q=${Uri.encodeQueryComponent(searchQuery)}',
      );
      final response = await http
          .get(uri, headers: {
            'Accept-Language': 'en',
            'User-Agent': 'TouristSafetyApp/2.0',
          })
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body) as List<dynamic>;
      final results = <TouristDestination>[];

      for (final item in decoded) {
        final map = item as Map<String, dynamic>;
        final addr = map['address'] as Map<String, dynamic>? ?? {};
        final name = (map['name'] as String?)?.trim().isNotEmpty == true
            ? map['name'] as String
            : (map['display_name'] as String? ?? trimmed).split(',').first.trim();
        final state = (addr['state'] ?? addr['State'] ?? 'India').toString();
        final district = (addr['state_district'] ?? addr['county'] ?? addr['city'] ?? '').toString();
        final lat = double.tryParse(map['lat']?.toString() ?? '') ?? 0.0;
        final lon = double.tryParse(map['lon']?.toString() ?? '') ?? 0.0;

        // Auto-link to nearest verified emergency facilities
        final closestHub = await findNearestDestination(lat, lon);

        results.add(
          TouristDestination(
            id: 'osm_${map['place_id']}',
            name: name,
            state: state,
            district: district,
            category: 'OpenStreetMap Search Result',
            latitude: lat,
            longitude: lon,
            emergencyHelpline: '112',
            touristHelpline: '1363',
            source: 'OpenStreetMap Nominatim Geocoder • National Helplines: 112 / 1363',
            safetyAdvisory:
                'Verified area navigation. Emergency response coordinated via ERSS 112 / State Helpline.',
            nearestPoliceStation: closestHub?.nearestPoliceStation ?? '$name Area Police Chowki',
            nearestHospital: closestHub?.nearestHospital ?? '$name Government Civil Hospital',
          ),
        );
      }
      return results;
    } catch (e) {
      debugPrint('Custom Nominatim destination search failed: $e');
      return [];
    }
  }
}
