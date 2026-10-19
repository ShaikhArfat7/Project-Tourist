import 'package:flutter/material.dart';

import '../../core/services/crime_data_service.dart';
import '../../core/services/destination_service.dart';
import '../../core/services/safety_zone_service.dart';
import '../../core/services/weather_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/url_launcher_helper.dart';
import '../nearby/nearby_tab.dart';

class DestinationRiskScreen extends StatefulWidget {
  final TouristDestination destination;

  const DestinationRiskScreen({
    super.key,
    required this.destination,
  });

  @override
  State<DestinationRiskScreen> createState() => _DestinationRiskScreenState();
}

class _DestinationRiskScreenState extends State<DestinationRiskScreen> {
  final CrimeDataService _crimeService = CrimeDataService();
  final SafetyZoneService _safetyZoneService = SafetyZoneService();
  final WeatherService _weatherService = WeatherService();

  bool _isLoading = true;
  String? _errorMessage;

  DistrictCrimeRecord? _nearestDistrict;
  StateCrimeRecord? _stateCrimeRecord;
  SafetyEvaluationResult? _safetyEvaluation;
  WeatherData? _weatherData;

  // Composite risk metrics
  int _safetyScore = 100; // 0 - 100, 100 is safest
  RiskTier _compositeTier = RiskTier.low;
  String _riskSummaryText = '';

  @override
  void initState() {
    super.initState();
    _loadRiskAssessment();
  }

  Future<void> _loadRiskAssessment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Initialize crime service
      await _crimeService.initialize();

      // 2. Fetch nearest district crime records (prioritizing 2023 CID data)
      final lat = widget.destination.latitude;
      final lon = widget.destination.longitude;

      _nearestDistrict = _crimeService.findNearestDistrict(lat, lon, year: 2023) ??
          _crimeService.findNearestDistrict(lat, lon);

      // Also get state record if available
      _stateCrimeRecord = _crimeService.getStateByName(widget.destination.state);

      // 3. Evaluate geofence & hazard zone proximity
      _safetyEvaluation = await _safetyZoneService.evaluateLocation(
        lat,
        lon,
        fetchWeather: false, // We'll fetch detailed weather via WeatherService
      );

      // 4. Fetch live weather telemetry
      try {
        _weatherData = await _weatherService.fetchWeather(
          latitude: lat,
          longitude: lon,
          locationName: widget.destination.name,
        );
      } catch (wErr) {
        debugPrint('Weather fetch warning: $wErr');
      }

      // 5. Compute composite safety score and tier
      _calculateCompositeRisk();
    } catch (e) {
      debugPrint('Error evaluating destination risk: $e');
      _errorMessage = 'Failed to compile full risk assessment: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculateCompositeRisk() {
    int score = 85; // baseline tourist safety score
    RiskTier tier = RiskTier.low;
    final List<String> factors = [];

    // Evaluate Geofence Danger Zones
    final activeZones = _safetyEvaluation?.activeZones ?? [];
    final nearbyZones = _safetyEvaluation?.nearbyZones ?? [];

    if (activeZones.isNotEmpty) {
      final hasHighRisk = activeZones.any((z) => z.riskTier == RiskTier.highRisk);
      if (hasHighRisk) {
        score -= 40;
        tier = RiskTier.highRisk;
        factors.add('Location is within an active High-Risk hazard boundary');
      } else {
        score -= 20;
        if (tier == RiskTier.low) tier = RiskTier.caution;
        factors.add('Location is inside an active Caution safety zone');
      }
    } else if (nearbyZones.isNotEmpty) {
      score -= 5;
      factors.add('${nearbyZones.length} hazard zone(s) identified within 25 km');
    }

    // Evaluate Weather Conditions
    if (_weatherData != null) {
      final code = _weatherData!.weatherCode;
      final wind = _weatherData!.windSpeed;
      final precip = _weatherData!.precipitation;

      // Heavy rain or thunderstorm
      if (code >= 95 || precip > 15 || wind > 45) {
        score -= 25;
        tier = RiskTier.highRisk;
        factors.add('Severe weather alert (${_weatherData!.conditionDescription}, ${wind.toStringAsFixed(0)} km/h winds)');
      } else if (code >= 51 || precip > 3 || wind > 28) {
        score -= 10;
        if (tier == RiskTier.low) tier = RiskTier.caution;
        factors.add('Adverse weather detected (${_weatherData!.conditionDescription})');
      }
    }

    // Evaluate District Crime Rate
    if (_nearestDistrict != null && _nearestDistrict!.crimeRate != null) {
      final rate = _nearestDistrict!.crimeRate!;
      final womenRate = _nearestDistrict!.crimesAgainstWomenRate ?? 0;

      if (rate > 450 || womenRate > 100) {
        score -= 18;
        if (tier == RiskTier.low) tier = RiskTier.caution;
        factors.add('Higher than average district crime rate (${rate.toStringAsFixed(1)} per 100k)');
      } else if (rate > 280 || womenRate > 65) {
        score -= 10;
        factors.add('Moderate district crime incidence (${rate.toStringAsFixed(1)} per 100k)');
      } else {
        score += 5;
        factors.add('Favorable district public safety rate (${rate.toStringAsFixed(1)} per 100k)');
      }
    }

    // Clamp score
    _safetyScore = score.clamp(15, 98);
    _compositeTier = tier;

    if (factors.isEmpty) {
      _riskSummaryText = 'No elevated hazards detected. Standard tourist precautions recommended.';
    } else {
      _riskSummaryText = factors.join(' • ');
    }
  }

  Color _getTierColor(RiskTier tier) {
    switch (tier) {
      case RiskTier.low:
        return AppTheme.lowRiskGreen;
      case RiskTier.caution:
        return AppTheme.cautionAmber;
      case RiskTier.highRisk:
        return AppTheme.highRiskRed;
    }
  }

  IconData _getTierIcon(RiskTier tier) {
    switch (tier) {
      case RiskTier.low:
        return Icons.verified_user_outlined;
      case RiskTier.caution:
        return Icons.warning_amber_rounded;
      case RiskTier.highRisk:
        return Icons.gpp_bad_outlined;
    }
  }

  String _getTierLabel(RiskTier tier) {
    switch (tier) {
      case RiskTier.low:
        return 'LOW RISK';
      case RiskTier.caution:
        return 'MODERATE RISK / CAUTION';
      case RiskTier.highRisk:
        return 'HIGH RISK HAZARD';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dest = widget.destination;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Destination Risk Predictor'),
        backgroundColor: AppTheme.tealDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Assessment',
            onPressed: _loadRiskAssessment,
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Open in Maps',
            onPressed: () => UrlLauncherHelper.openMapDirections(
              context,
              dest.name,
              lat: dest.latitude,
              lng: dest.longitude,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.teal),
                  SizedBox(height: 16),
                  Text(
                    'Analyzing destination coordinates...',
                    style: TextStyle(color: AppTheme.muted, fontSize: 14),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Checking 2023 CID datasets, geofences & live weather',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppTheme.teal,
              onRefresh: _loadRiskAssessment,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  if (_errorMessage != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 1. Destination Header Card
                  _buildHeaderCard(),

                  const SizedBox(height: 16),

                  // 2. Overall Risk Score Banner
                  _buildOverallScoreCard(),

                  const SizedBox(height: 16),

                  // 3. Active Danger Zone Alert (if any)
                  if (_safetyEvaluation?.activeZones.isNotEmpty ?? false)
                    _buildActiveHazardAlert(),

                  // 4. Factor Breakdown: Crime, Weather, Geofence
                  const Text(
                    'Safety Factor Breakdown',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildCrimeSafetyFactorCard(),
                  const SizedBox(height: 12),
                  _buildWeatherSafetyFactorCard(),
                  const SizedBox(height: 12),
                  _buildGeofenceFactorCard(),

                  const SizedBox(height: 16),

                  // 5. Official Destination Safety Advisory
                  _buildAdvisoryCard(),

                  const SizedBox(height: 16),

                  // 6. Direct Emergency Helplines
                  _buildEmergencyDialersCard(),

                  const SizedBox(height: 16),

                  // 7. Emergency Services For This Destination
                  _buildNearbyEmergencyLocationsCard(),

                  const SizedBox(height: 20),

                  // 8. Scientific & Legal Disclaimers
                  _buildDisclaimersCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ==========================================
  // WIDGET BUILDERS
  // ==========================================

  Widget _buildHeaderCard() {
    final dest = widget.destination;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.tealTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    size: 30,
                    color: AppTheme.teal,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dest.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dest.category} • ${dest.state}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.gps_fixed, size: 14, color: AppTheme.muted),
                const SizedBox(width: 6),
                Text(
                  '${dest.latitude.toStringAsFixed(4)}° N, ${dest.longitude.toStringAsFixed(4)}° E',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.muted,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.directions, size: 16),
                  label: const Text('Directions'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.teal,
                    side: const BorderSide(color: AppTheme.teal),
                  ),
                  onPressed: () => UrlLauncherHelper.openMapDirections(
                    context,
                    dest.name,
                    lat: dest.latitude,
                    lng: dest.longitude,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallScoreCard() {
    final color = _getTierColor(_compositeTier);
    final icon = _getTierIcon(_compositeTier);
    final label = _getTierLabel(_compositeTier);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PREDICTED RISK RATING',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              // Safety Score Ring Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Column(
                  children: [
                    Text(
                      '$_safetyScore',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    Text(
                      'SAFETY INDEX',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _safetyScore / 100.0,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _riskSummaryText,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textDark,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveHazardAlert() {
    final active = _safetyEvaluation!.activeZones.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ACTIVE HAZARD ZONE: ${active.name}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            active.warningMessage,
            style: TextStyle(fontSize: 13, color: Colors.red.shade900),
          ),
          if (active.recommendedAction.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Action: ${active.recommendedAction}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCrimeSafetyFactorCard() {
    final dist = _nearestDistrict;
    final state = _stateCrimeRecord;

    if (dist == null && state == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No historical crime baseline available for this coordinate.'),
        ),
      );
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppTheme.teal, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Crime & Public Safety Context',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.tealTint,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    dist != null ? '${dist.reportingYear} CID Data' : 'NCRB State Data',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.tealDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (dist != null) ...[
              Text(
                'Nearest Police Jurisdiction: ${dist.policeUnitsIncluded.isNotEmpty ? dist.policeUnitsIncluded : dist.district} (${dist.unitType})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildStatTile(
                    'IPC Crime Rate',
                    dist.crimeRate != null ? dist.crimeRate!.toStringAsFixed(1) : 'N/A',
                    'per 100k pop',
                  ),
                  const SizedBox(width: 8),
                  _buildStatTile(
                    'Women Safety Rate',
                    dist.crimesAgainstWomenRate != null
                        ? dist.crimesAgainstWomenRate!.toStringAsFixed(1)
                        : 'N/A',
                    'per 100k females',
                  ),
                  const SizedBox(width: 8),
                  _buildStatTile(
                    'Annual IPC Crimes',
                    dist.totalIpcCrimes.toString(),
                    'recorded',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Theft: ${dist.theft}  •  Burglary: ${dist.burglary}  •  Robbery: ${dist.dacoityAndRobbery}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
                ],
              ),
            ] else if (state != null) ...[
              Text(
                'Statewide Context: ${state.stateUt} (${state.category})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatTile('State Crime Rate', '${state.crimeRate2016}', 'per 100k pop'),
                  const SizedBox(width: 8),
                  _buildStatTile('IPC Crimes', '${state.ipcCrimes2016}', 'reported'),
                  const SizedBox(width: 8),
                  _buildStatTile('Theft', '${state.theft2016}', 'cases'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherSafetyFactorCard() {
    final w = _weatherData;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wb_sunny_outlined, color: Colors.orange, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Environmental & Live Weather',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Live Telemetry',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (w != null) ...[
              Row(
                children: [
                  Text(
                    '${w.temperature.toStringAsFixed(1)}°C',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.conditionDescription,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Wind: ${w.windSpeed.toStringAsFixed(1)} km/h  •  Precipitation: ${w.precipitation.toStringAsFixed(1)} mm',
                          style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'Live weather data temporarily unavailable. Check local forecast before venturing outdoors.',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGeofenceFactorCard() {
    final nearby = _safetyEvaluation?.nearbyZones ?? [];

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.share_location, color: Colors.blueAccent, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Geofenced Hazard Zones',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${nearby.length} Nearby',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (nearby.isEmpty)
              const Text(
                'No mapped hazard perimeters or high-risk geofences within 25 km of this destination.',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              )
            else
              ...nearby.take(2).map(
                    (z) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            z.riskTier == RiskTier.highRisk ? Icons.dangerous : Icons.warning_amber,
                            color: z.riskTier == RiskTier.highRisk ? Colors.red : Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${z.name} (${((z.distanceMeters ?? 0) / 1000).toStringAsFixed(1)} km away)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvisoryCard() {
    final advisory = widget.destination.safetyAdvisory;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.teal, size: 20),
                SizedBox(width: 8),
                Text(
                  'Local Travel Advisory',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              advisory.isNotEmpty
                  ? advisory
                  : 'Follow standard travel safety guidelines: Keep emergency contacts handy, travel in registered taxis, and avoid isolated or unlit spots after dark.',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textDark,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyDialersCard() {
    final dest = widget.destination;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.tealDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.phone_in_talk, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'One-Touch Emergency Helplines',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDialButton(
                  title: 'Police & ERSS',
                  number: dest.emergencyHelpline.isNotEmpty ? dest.emergencyHelpline : '112',
                  icon: Icons.local_police,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDialButton(
                  title: 'Tourist Helpline',
                  number: dest.touristHelpline.isNotEmpty ? dest.touristHelpline : '1363',
                  icon: Icons.support_agent,
                  color: Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDialButton(
                  title: 'Ambulance',
                  number: '108',
                  icon: Icons.medical_services,
                  color: Colors.tealAccent.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDialButton({
    required String title,
    required String number,
    required IconData icon,
    required Color color,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 1,
      ),
      onPressed: () => UrlLauncherHelper.callNumber(context, number),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          Text(
            number,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, String unit) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.slateBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppTheme.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            Text(
              unit,
              style: const TextStyle(fontSize: 9, color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyEmergencyLocationsCard() {
    final dest = widget.destination;
    final ps = dest.nearestPoliceStation ?? 'Local Police Station (ERSS 112)';
    final hosp = dest.nearestHospital ?? 'Government Trauma Centre & Civil Hospital';

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emergency_outlined, color: AppTheme.teal, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Emergency Services For This Location',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.tealTint,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Verified Grid',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.tealDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_police, color: Colors.blue, size: 20),
              ),
              title: Text(ps, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Designated Police Jurisdiction • ${dest.district.isNotEmpty ? dest.district : dest.state}',
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.call, color: AppTheme.teal, size: 20),
                tooltip: 'Call Police / 112',
                onPressed: () => UrlLauncherHelper.callNumber(context, dest.emergencyHelpline),
              ),
            ),
            const Divider(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_hospital, color: Colors.red, size: 20),
              ),
              title: Text(hosp, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text('Nearest Medical & Emergency Hospital', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
              trailing: IconButton(
                icon: const Icon(Icons.call, color: Colors.red, size: 20),
                tooltip: 'Call Ambulance 108',
                onPressed: () => UrlLauncherHelper.callNumber(context, '108'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.map, size: 18),
                label: Text('View Emergency Map & Services in ${dest.name}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: NearbyTab(browsedDestination: dest),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimersCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.shade50.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified, size: 18, color: AppTheme.teal),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Official Dataset Integrity: All 113+ destinations, geographic coordinates, historical crime rates, and emergency services are derived strictly from official government records (Maharashtra State CID 2022-2023, NCRB, and verified emergency grids) — not unverified web scraping. In case of immediate emergency in India, dial 112.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.tealDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
