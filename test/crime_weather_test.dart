import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tourist_safety_app/core/services/crime_data_service.dart';
import 'package:tourist_safety_app/core/services/destination_service.dart';
import 'package:tourist_safety_app/core/services/firebase_user_service.dart';
import 'package:tourist_safety_app/core/services/notification_service.dart';
import 'package:tourist_safety_app/core/services/safety_zone_service.dart';
import 'package:tourist_safety_app/core/services/weather_service.dart';
import 'package:tourist_safety_app/screens/crime_analysis/crime_analysis_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CrimeDataService Unit Tests', () {
    final service = CrimeDataService();

    test('Initializes and loads 36 Indian States/UTs from NCRB data', () async {
      await service.initialize();

      expect(service.isLoaded, isTrue);
      expect(service.states.length, equals(36));

      final mh = service.getStateByName('Maharashtra');
      expect(mh, isNotNull);
      expect(mh!.capital, equals('Mumbai'));
      expect(mh.projectedPopulationLakhs2016, equals(1208.4));
      expect(mh.ipcCrimes2016, equals(261714));
      expect(mh.crimeRate2016, equals(216.6));
      expect(mh.theft2016, equals(64289));
      expect(mh.burglary2016, equals(16812));
    });

    test('Loads official Maharashtra CID 2022-2023 dataset with 76 district records and verified rates', () async {
      await service.initialize();

      expect(service.districts.length, equals(76));

      final raigad = service.getDistrictByName('Raigad', year: 2023);
      expect(raigad, isNotNull);
      expect(raigad!.headquarters, contains('Panvel Jurisdiction'));
      expect(raigad.totalIpcCrimes, equals(4526));
      expect(raigad.reportingYear, equals(2023));
      // Scientific integrity check: Official population and crime rate from CID compendium
      expect(raigad.populationDenominatorAvailable, isTrue);
      expect(raigad.crimeRate, isNotNull);
      expect(raigad.crimeRate, closeTo(226.5, 0.5));

      final nearest = service.findNearestDistrict(18.9894, 73.1175, year: 2023);
      expect(nearest, isNotNull);
      expect(nearest!.district, anyOf(equals('Raigad'), equals('Navi Mumbai')));

      final mumbai = service.getDistrictByName('Mumbai (C.)', year: 2023);
      expect(mumbai, isNotNull);
      expect(mumbai!.unitType, equals('Commissionerate'));
      expect(mumbai.totalIpcCrimes, equals(44873));
      expect(mumbai.populationDenominatorAvailable, isTrue);
      expect(mumbai.crimeRate, isNotNull);
    });

    test('Loads official metadata documenting GODL license and official sources', () async {
      await service.initialize();

      final meta = service.metadata;
      expect(meta, isNotNull);
      expect(meta!['license_information']['license'], contains('Government Open Data License'));
      expect(meta['datasets'], isA<List>());
      expect((meta['datasets'] as List).length, equals(3));
    });

    test('Validates user-uploaded CSV dataset correctly', () {
      const sampleCsv = '''State,Reporting_Year,Total_IPC,Population_Lakhs
Maharashtra,2016,261714,1208.4
Uttar Pradesh,2016,282171,2191.1
Goa,2016,2900,15.0''';

      final report = service.validateAndParseUpload(
        fileName: 'custom_state_crime.csv',
        content: sampleCsv,
      );

      expect(report.isValid, isTrue);
      expect(report.format, equals('CSV'));
      expect(report.recordCount, equals(3));
      expect(report.columns, equals(['State', 'Reporting_Year', 'Total_IPC', 'Population_Lakhs']));
      expect(report.hasPopulationDenominator, isTrue);
      expect(report.detectedLevel, equals('State Level'));
      expect(report.missingValuesCount, equals(0));
    });

    test('Detects missing values and non-population CSV datasets gracefully', () {
      const sampleDistrictCsv = '''District,Unit_Type,Total_Crimes,Theft
Panvel Rural,Rural,1200,
Thane City,Commissionerate,4500,1800''';

      final report = service.validateAndParseUpload(
        fileName: 'custom_districts.csv',
        content: sampleDistrictCsv,
      );

      expect(report.isValid, isTrue);
      expect(report.recordCount, equals(2));
      expect(report.hasPopulationDenominator, isFalse);
      expect(report.detectedLevel, equals('District Level'));
      // 1 missing value in Panvel Rural Theft
      expect(report.missingValuesCount, equals(1));
    });

    test('Validates user-uploaded JSON dataset correctly', () {
      final sampleJson = jsonEncode([
        {'district': 'Raigad', 'crimes': 4500, 'theft': 1400},
        {'district': 'Pune Rural', 'crimes': 7800, 'theft': 2400},
      ]);

      final report = service.validateAndParseUpload(
        fileName: 'custom_districts.json',
        content: sampleJson,
      );

      expect(report.isValid, isTrue);
      expect(report.format, equals('JSON'));
      expect(report.recordCount, equals(2));
      expect(report.detectedLevel, equals('District Level'));
      expect(report.missingValuesCount, equals(0));
    });
  });

  group('WeatherService Unit Tests', () {
    test('Maps WMO weather codes to human-readable descriptions', () {
      expect(WeatherService.getWeatherDescription(0), equals('Clear Sky'));
      expect(WeatherService.getWeatherDescription(1), equals('Mainly Clear'));
      expect(WeatherService.getWeatherDescription(3), equals('Overcast'));
      expect(WeatherService.getWeatherDescription(45), contains('Fog'));
      expect(WeatherService.getWeatherDescription(63), contains('Rain'));
      expect(WeatherService.getWeatherDescription(95), equals('Thunderstorm'));
    });

    test('Mandatory scientific disclaimer is present and explicit', () {
      expect(WeatherData.disclaimer, contains('environmental awareness'));
      expect(WeatherData.disclaimer, contains('Weather does NOT predict, cause, or correlate with crime'));
    });
  });

  group('CrimeAnalysisScreen Widget Tests', () {
    testWidgets('Renders CrimeAnalysisScreen with tabs and selector', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CrimeAnalysisScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Public Safety & Crime Analytics'), findsOneWidget);
      expect(find.text('State Level'), findsOneWidget);
      expect(find.text('MH Districts'), findsOneWidget);
      expect(find.text('Custom Data'), findsOneWidget);
      expect(find.text('Select State / UT:'), findsOneWidget);
      expect(find.text('Live Weather Context'), findsOneWidget);
      expect(find.text('Total IPC Crimes'), findsOneWidget);
      expect(find.text('Official Crime Rate'), findsOneWidget);
    });
  });

  group('DestinationService & Emergency Locations Unit Tests', () {
    final destService = DestinationService();

    test('Loads 113+ total destinations with 103 in Maharashtra', () async {
      final dests = await destService.getDestinations();
      expect(dests.length, greaterThanOrEqualTo(113));

      final mhDests = dests.where((d) => d.state.toLowerCase() == 'maharashtra').toList();
      expect(mhDests.length, greaterThanOrEqualTo(103));
    });

    test('Every destination has valid coordinates, emergency helpline 112, and verified police/hospital', () async {
      final dests = await destService.getDestinations();
      for (final d in dests) {
        expect(d.name, isNotEmpty);
        expect(d.latitude, inInclusiveRange(8.0, 37.0));
        expect(d.longitude, inInclusiveRange(68.0, 97.0));
        expect(d.emergencyHelpline, equals('112'));
        expect(d.touristHelpline, equals('1363'));
        expect(d.nearestPoliceStation, isNotNull);
        expect(d.nearestPoliceStation, isNotEmpty);
        expect(d.nearestHospital, isNotNull);
        expect(d.nearestHospital, isNotEmpty);
      }
    });

    test('findNearestDestination returns closest location for remote coordinates', () async {
      // Shirdi coordinates approx 19.7645, 74.4762
      final nearest = await destService.findNearestDestination(19.765, 74.476);
      expect(nearest, isNotNull);
      expect(nearest!.name, contains('Shirdi'));
    });

    test('findNearestDestinationsWithDistance computes real distances correctly', () async {
      // Near Nerul coordinates (19.033, 73.019)
      final nearestList = await destService.findNearestDestinationsWithDistance(19.033, 73.019, limit: 3);
      expect(nearestList, isNotEmpty);
      expect(nearestList.first.key.name, contains('Nerul'));
      expect(nearestList.first.value, lessThan(2.0)); // Under 2 km
    });

    test('Panvel coordinates return Panvel as closest destination, not Nerul', () async {
      // Panvel coordinates (18.9894, 73.1175)
      final nearest = await destService.findNearestDestination(18.9894, 73.1175);
      expect(nearest, isNotNull);
      expect(nearest!.name.toLowerCase(), contains('panvel'));
      expect(nearest.name.toLowerCase(), isNot(contains('nerul')));
      expect(nearest.nearestPoliceStation, contains('Police Station'));
      expect(nearest.nearestHospital, isNotEmpty);
    });

    test('Kharghar coordinates return Kharghar as closest destination, not Nerul', () async {
      // Kharghar coordinates (19.0434, 73.0689)
      final nearest = await destService.findNearestDestination(19.0434, 73.0689);
      expect(nearest, isNotNull);
      expect(nearest!.name.toLowerCase(), contains('kharghar'));
      expect(nearest.nearestPoliceStation, contains('Kharghar'));
    });

    test('Lonavala coordinates return Lonavala as closest destination', () async {
      // Lonavala coordinates (18.7557, 73.4091)
      final nearest = await destService.findNearestDestination(18.7557, 73.4091);
      expect(nearest, isNotNull);
      expect(nearest!.name.toLowerCase(), contains('lonavala'));
      expect(nearest.nearestPoliceStation, contains('Lonavala'));
    });

    test('TouristDestination.matchesSearch matches aliases and spelling variations', () async {
      final dests = await destService.getDestinations();

      // Searching 'lonavla' should match 'Lonavala'
      final lonavlaMatches = dests.where((d) => d.matchesSearch('lonavla')).toList();
      expect(lonavlaMatches, isNotEmpty);
      expect(lonavlaMatches.any((d) => d.name.toLowerCase().contains('lonavala')), isTrue);

      // Searching 'alibaug' should match 'Alibag'
      final alibaugMatches = dests.where((d) => d.matchesSearch('alibaug')).toList();
      expect(alibaugMatches, isNotEmpty);

      // Searching 'panvel' should match Panvel
      final panvelMatches = dests.where((d) => d.matchesSearch('panvel')).toList();
      expect(panvelMatches, isNotEmpty);
      expect(panvelMatches.any((d) => d.name.toLowerCase().contains('panvel')), isTrue);

      // Searching by district 'raigad' should match Raigad destinations
      final raigadMatches = dests.where((d) => d.matchesSearch('raigad')).toList();
      expect(raigadMatches, isNotEmpty);
    });
  });

  group('SafetyZoneService Simulations Unit Tests', () {
    final safetyService = SafetyZoneService();

    test('Panvel simulation injects High Risk red geofence', () async {
      safetyService.setPanvelDemoEnabled(true);
      final zones = safetyService.allConfiguredZones;
      expect(zones.any((z) => z.id == 'dz_panvel_demo_simulation' && z.riskTier == RiskTier.highRisk), isTrue);
      safetyService.setPanvelDemoEnabled(false);
    });

    test('Panvel simulation triggers when coordinates are inside Panvel geofence', () async {
      safetyService.setPanvelDemoEnabled(true);
      // Panvel coordinates: 18.9894, 73.1175
      final eval = await safetyService.evaluateLocation(18.9894, 73.1175, fetchWeather: false);
      expect(eval.overallTier, equals(RiskTier.highRisk));
      expect(eval.activeZones.any((z) => z.id == 'dz_panvel_demo_simulation'), isTrue);
      safetyService.setPanvelDemoEnabled(false);
    });

    test('Nerul simulation is NOT active when coordinates are in Panvel', () async {
      safetyService.setNerulDemoEnabled(true);
      // Panvel coordinates: 18.9894, 73.1175 (~12km from Nerul)
      final eval = await safetyService.evaluateLocation(18.9894, 73.1175, fetchWeather: false);
      expect(eval.activeZones.any((z) => z.id == 'dz_nerul_demo_simulation'), isFalse);
      expect(eval.nearbyZones.any((z) => z.id == 'dz_nerul_demo_simulation'), isTrue);
      safetyService.setNerulDemoEnabled(false);
    });

    test('Nerul simulation triggers when coordinates are inside Nerul geofence', () async {
      safetyService.setNerulDemoEnabled(true);
      // Nerul coordinates: 19.0330, 73.0197
      final eval = await safetyService.evaluateLocation(19.0330, 73.0197, fetchWeather: false);
      expect(eval.activeZones.any((z) => z.id == 'dz_nerul_demo_simulation'), isTrue);
      safetyService.setNerulDemoEnabled(false);
    });

    test('evaluateCoordinatesForHazard correctly identifies Lonavala Lion Point as High Risk', () async {
      // Lion's Point Cliff coordinates: (18.6989, 73.3894)
      final hazard = await safetyService.evaluateCoordinatesForHazard(18.6989, 73.3894);
      expect(hazard, isNotNull);
      expect(hazard!.riskTier, equals(RiskTier.highRisk));
      expect(hazard.name, contains("Lion's Point"));
    });
  });

  group('NotificationService Unit Tests', () {
    test('Configures notification channel IDs correctly', () {
      expect(NotificationService.highRiskChannelId, equals('high_risk_channel'));
      expect(NotificationService.mediumRiskChannelId, equals('medium_risk_channel'));
      expect(NotificationService.onNotificationPayload, isNotNull);
    });
  });

  group('FirebaseUserService & Profile Resilience Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Guest sign-in initializes profile and saves to local persistence', () async {
      final userService = FirebaseUserService();
      await userService.signInAsGuest(
        name: 'Judge Test Tourist',
        email: 'judge@safety.edu',
      );

      expect(userService.isGuestSignedIn, isTrue);
      expect(userService.currentProfile, isNotNull);
      expect(userService.currentProfile!.fullName, equals('Judge Test Tourist'));
      expect(userService.currentProfile!.email, equals('judge@safety.edu'));
    });

    test('Update profile preserves data and updates local cache', () async {
      final userService = FirebaseUserService();
      await userService.signInAsGuest(name: 'Initial Name');

      final updated = TouristProfile(
        uid: userService.currentProfile!.uid,
        fullName: 'Updated Name',
        email: 'initial@email.com',
        phoneNumber: '+91 9988776655',
        emergencyContactName: 'Doctor Contact',
        emergencyContactPhone: '+91 9988770000',
        preferredLanguage: 'Marathi',
        bloodGroup: 'B+',
      );

      final error = await userService.updateProfile(updated);
      expect(error, isNull); // Local update succeeds immediately
      expect(userService.currentProfile!.fullName, equals('Updated Name'));
      expect(userService.currentProfile!.phoneNumber, equals('+91 9988776655'));
      expect(userService.currentProfile!.emergencyContactName, equals('Doctor Contact'));
      expect(userService.currentProfile!.bloodGroup, equals('B+'));
    });
  });
}
