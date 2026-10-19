import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';

class StateCrimeRecord {
  final String stateUt;
  final String category;
  final String capital;
  final double latitude;
  final double longitude;
  final double projectedPopulationLakhs2016;
  final int ipcCrimes2014;
  final int ipcCrimes2015;
  final int ipcCrimes2016;
  final double crimeRate2016;
  final double percentageShare2016;
  final int violentCrimes2016;
  final int murder2016;
  final int assaultOnWomen2016;
  final int kidnappingAndAbduction2016;
  final int robbery2016;
  final int burglary2016;
  final int theft2016;

  StateCrimeRecord({
    required this.stateUt,
    required this.category,
    required this.capital,
    required this.latitude,
    required this.longitude,
    required this.projectedPopulationLakhs2016,
    required this.ipcCrimes2014,
    required this.ipcCrimes2015,
    required this.ipcCrimes2016,
    required this.crimeRate2016,
    required this.percentageShare2016,
    required this.violentCrimes2016,
    required this.murder2016,
    required this.assaultOnWomen2016,
    required this.kidnappingAndAbduction2016,
    required this.robbery2016,
    required this.burglary2016,
    required this.theft2016,
  });

  factory StateCrimeRecord.fromJson(Map<String, dynamic> json) {
    return StateCrimeRecord(
      stateUt: json['state_ut']?.toString() ?? '',
      category: json['category']?.toString() ?? 'State',
      capital: json['capital']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 20.5937,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 78.9629,
      projectedPopulationLakhs2016: (json['projected_population_lakhs_2016'] as num?)?.toDouble() ?? 0.0,
      ipcCrimes2014: (json['ipc_crimes_2014'] as num?)?.toInt() ?? 0,
      ipcCrimes2015: (json['ipc_crimes_2015'] as num?)?.toInt() ?? 0,
      ipcCrimes2016: (json['ipc_crimes_2016'] as num?)?.toInt() ?? 0,
      crimeRate2016: (json['crime_rate_2016'] as num?)?.toDouble() ?? 0.0,
      percentageShare2016: (json['percentage_share_2016'] as num?)?.toDouble() ?? 0.0,
      violentCrimes2016: (json['violent_crimes_2016'] as num?)?.toInt() ?? 0,
      murder2016: (json['murder_2016'] as num?)?.toInt() ?? 0,
      assaultOnWomen2016: (json['assault_on_women_2016'] as num?)?.toInt() ?? 0,
      kidnappingAndAbduction2016: (json['kidnapping_and_abduction_2016'] as num?)?.toInt() ?? 0,
      robbery2016: (json['robbery_2016'] as num?)?.toInt() ?? 0,
      burglary2016: (json['burglary_2016'] as num?)?.toInt() ?? 0,
      theft2016: (json['theft_2016'] as num?)?.toInt() ?? 0,
    );
  }
}

class DistrictCrimeRecord {
  final String district;
  final String unitType;
  final String region;
  final String headquarters;
  final double latitude;
  final double longitude;
  final int reportingYear;
  final int totalIpcCrimes;
  final double? ipcCrimeRate;
  final int totalCognizableCrimes;
  final double? totalCrimeRate;
  final int crimesAgainstWomen;
  final double? crimesAgainstWomenRate;
  final double? populationLakhs;
  final int murder;
  final int attemptToMurder;
  final int rapeAndAssaultOnWomen;
  final int kidnappingAndAbduction;
  final int dacoityAndRobbery;
  final int burglary;
  final int theft;
  final int cheatingAndFraud;
  final double? crimeRate;
  final bool populationDenominatorAvailable;
  final String policeUnitsIncluded;
  final String note;

  DistrictCrimeRecord({
    required this.district,
    required this.unitType,
    required this.region,
    required this.headquarters,
    required this.latitude,
    required this.longitude,
    this.reportingYear = 2023,
    required this.totalIpcCrimes,
    this.ipcCrimeRate,
    this.totalCognizableCrimes = 0,
    this.totalCrimeRate,
    this.crimesAgainstWomen = 0,
    this.crimesAgainstWomenRate,
    this.populationLakhs,
    required this.murder,
    required this.attemptToMurder,
    required this.rapeAndAssaultOnWomen,
    required this.kidnappingAndAbduction,
    required this.dacoityAndRobbery,
    required this.burglary,
    required this.theft,
    required this.cheatingAndFraud,
    this.crimeRate,
    this.populationDenominatorAvailable = false,
    this.policeUnitsIncluded = '',
    this.note = '',
  });

  factory DistrictCrimeRecord.fromJson(Map<String, dynamic> json) {
    final double? parsedCrimeRate = (json['crime_rate'] as num?)?.toDouble() ??
        (json['ipc_crime_rate'] as num?)?.toDouble();
    final int year = (json['reporting_year'] as num?)?.toInt() ?? 2023;

    return DistrictCrimeRecord(
      district: json['district']?.toString() ?? '',
      unitType: json['unit_type']?.toString() ?? 'District',
      region: json['region']?.toString() ?? 'Maharashtra',
      headquarters: json['headquarters']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 19.7515,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 75.7139,
      reportingYear: year,
      totalIpcCrimes: (json['total_ipc_crimes'] as num?)?.toInt() ?? 0,
      ipcCrimeRate: (json['ipc_crime_rate'] as num?)?.toDouble(),
      totalCognizableCrimes: (json['total_cognizable_crimes'] as num?)?.toInt() ?? 0,
      totalCrimeRate: (json['total_crime_rate'] as num?)?.toDouble(),
      crimesAgainstWomen: (json['crimes_against_women'] as num?)?.toInt() ?? 0,
      crimesAgainstWomenRate: (json['crimes_against_women_rate'] as num?)?.toDouble(),
      populationLakhs: (json['population_lakhs'] as num?)?.toDouble(),
      murder: (json['murder'] as num?)?.toInt() ?? 0,
      attemptToMurder: (json['attempt_to_murder'] as num?)?.toInt() ?? 0,
      rapeAndAssaultOnWomen: (json['rape_and_assault_on_women'] as num?)?.toInt() ?? 0,
      kidnappingAndAbduction: (json['kidnapping_and_abduction'] as num?)?.toInt() ?? 0,
      dacoityAndRobbery: (json['dacoity_and_robbery'] as num?)?.toInt() ?? 0,
      burglary: (json['burglary'] as num?)?.toInt() ?? 0,
      theft: (json['theft'] as num?)?.toInt() ?? 0,
      cheatingAndFraud: (json['cheating_and_fraud'] as num?)?.toInt() ?? 0,
      crimeRate: parsedCrimeRate,
      populationDenominatorAvailable: json['population_denominator_available'] == true,
      policeUnitsIncluded: json['police_units_included']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }
}

class DatasetValidationReport {
  final String fileName;
  final String format;
  final int recordCount;
  final List<String> columns;
  final int missingValuesCount;
  final String detectedLevel;
  final String detectedPeriod;
  final bool hasPopulationDenominator;
  final bool isValid;
  final String? errorMessage;
  final List<Map<String, dynamic>> parsedRows;

  DatasetValidationReport({
    required this.fileName,
    required this.format,
    required this.recordCount,
    required this.columns,
    required this.missingValuesCount,
    required this.detectedLevel,
    required this.detectedPeriod,
    required this.hasPopulationDenominator,
    required this.isValid,
    this.errorMessage,
    required this.parsedRows,
  });
}

class CrimeDataService {
  static final CrimeDataService _instance = CrimeDataService._internal();
  factory CrimeDataService() => _instance;
  CrimeDataService._internal();

  List<StateCrimeRecord> _states = [];
  List<DistrictCrimeRecord> _districts = [];
  Map<String, dynamic>? _metadata;
  DatasetValidationReport? _activeCustomDataset;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  List<StateCrimeRecord> get states => List.unmodifiable(_states);
  List<DistrictCrimeRecord> get districts => List.unmodifiable(_districts);
  Map<String, dynamic>? get metadata => _metadata;
  DatasetValidationReport? get activeCustomDataset => _activeCustomDataset;

  Future<void> initialize() async {
    if (_isLoaded) return;

    try {
      // 1. Load Metadata
      final metaStr = await rootBundle.loadString('assets/data/crime_metadata.json');
      _metadata = jsonDecode(metaStr) as Map<String, dynamic>;

      // 2. Load State NCRB Data
      final stateStr = await rootBundle.loadString('assets/data/crime_state_ncrb.json');
      final stateList = jsonDecode(stateStr) as List;
      _states = stateList.map((e) => StateCrimeRecord.fromJson(e as Map<String, dynamic>)).toList();

      // 3. Load Maharashtra District Data
      final distStr = await rootBundle.loadString('assets/data/crime_maharashtra_districts.json');
      final distList = jsonDecode(distStr) as List;
      _districts = distList.map((e) => DistrictCrimeRecord.fromJson(e as Map<String, dynamic>)).toList();

      _isLoaded = true;
    } catch (e) {
      // ignore: avoid_print
      print('Error initializing CrimeDataService: $e');
    }
  }

  StateCrimeRecord? getStateByName(String name) {
    try {
      return _states.firstWhere(
        (s) => s.stateUt.toLowerCase() == name.trim().toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  List<int> get availableDistrictYears {
    final years = _districts.map((d) => d.reportingYear).toSet().toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  List<DistrictCrimeRecord> getDistricts({int? year}) {
    if (year == null) return List.unmodifiable(_districts);
    return List.unmodifiable(_districts.where((d) => d.reportingYear == year));
  }

  DistrictCrimeRecord? getDistrictByName(String name, {int? year}) {
    final query = name.trim().toLowerCase();
    try {
      final matches = _districts.where(
        (d) => d.district.toLowerCase() == query ||
               d.district.toLowerCase().contains(query) ||
               d.policeUnitsIncluded.toLowerCase().contains(query),
      );
      if (year != null) {
        return matches.firstWhere((d) => d.reportingYear == year);
      }
      return matches.firstOrNull;
    } catch (_) {
      return null;
    }
  }

  /// Calculates Haversine distance in km between two geographic coordinates
  double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Finds the geographically nearest police unit/district record
  DistrictCrimeRecord? findNearestDistrict(
    double latitude,
    double longitude, {
    int? year,
  }) {
    final candidates = year != null ? getDistricts(year: year) : _districts;
    if (candidates.isEmpty) return null;

    DistrictCrimeRecord? closest;
    double minDistance = double.infinity;

    for (final record in candidates) {
      final dist = calculateDistanceKm(
        latitude,
        longitude,
        record.latitude,
        record.longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closest = record;
      }
    }
    return closest;
  }

  /// Validates and parses uploaded CSV or JSON file contents
  DatasetValidationReport validateAndParseUpload({
    required String fileName,
    required String content,
  }) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.json')) {
      return _parseJsonUpload(fileName, content);
    } else {
      return _parseCsvUpload(fileName, content);
    }
  }

  DatasetValidationReport _parseJsonUpload(String fileName, String content) {
    try {
      final dynamic decoded = jsonDecode(content);
      if (decoded is! List) {
        return DatasetValidationReport(
          fileName: fileName,
          format: 'JSON',
          recordCount: 0,
          columns: [],
          missingValuesCount: 0,
          detectedLevel: 'Invalid Structure',
          detectedPeriod: 'Unknown',
          hasPopulationDenominator: false,
          isValid: false,
          errorMessage: 'JSON dataset must contain an array of objects.',
          parsedRows: [],
        );
      }

      final list = decoded.cast<Map<String, dynamic>>();
      if (list.isEmpty) {
        return DatasetValidationReport(
          fileName: fileName,
          format: 'JSON',
          recordCount: 0,
          columns: [],
          missingValuesCount: 0,
          detectedLevel: 'Empty Dataset',
          detectedPeriod: 'Unknown',
          hasPopulationDenominator: false,
          isValid: false,
          errorMessage: 'Dataset contains zero records.',
          parsedRows: [],
        );
      }

      final columns = list.first.keys.toList();
      int missing = 0;
      for (final row in list) {
        for (final k in columns) {
          final v = row[k];
          if (v == null || v.toString().trim().isEmpty) {
            missing++;
          }
        }
      }

      final hasPop = columns.any((c) => c.toLowerCase().contains('pop'));
      final isDistrict = columns.any((c) => c.toLowerCase().contains('district'));
      final isState = columns.any((c) => c.toLowerCase().contains('state'));

      String level = 'Custom Generic';
      if (isDistrict) {
        level = 'District Level';
      } else if (isState) {
        level = 'State Level';
      }

      return DatasetValidationReport(
        fileName: fileName,
        format: 'JSON',
        recordCount: list.length,
        columns: columns,
        missingValuesCount: missing,
        detectedLevel: level,
        detectedPeriod: _detectPeriod(columns, list),
        hasPopulationDenominator: hasPop,
        isValid: true,
        parsedRows: list,
      );
    } catch (e) {
      return DatasetValidationReport(
        fileName: fileName,
        format: 'JSON',
        recordCount: 0,
        columns: [],
        missingValuesCount: 0,
        detectedLevel: 'Malformed JSON',
        detectedPeriod: 'Unknown',
        hasPopulationDenominator: false,
        isValid: false,
        errorMessage: 'JSON Parsing Error: $e',
        parsedRows: [],
      );
    }
  }

  DatasetValidationReport _parseCsvUpload(String fileName, String content) {
    try {
      final rows = const CsvDecoder(dynamicTyping: true).convert(content);

      if (rows.isEmpty || rows.length < 2) {
        return DatasetValidationReport(
          fileName: fileName,
          format: 'CSV',
          recordCount: 0,
          columns: [],
          missingValuesCount: 0,
          detectedLevel: 'Invalid CSV',
          detectedPeriod: 'Unknown',
          hasPopulationDenominator: false,
          isValid: false,
          errorMessage: 'CSV must contain at least a header row and one data record.',
          parsedRows: [],
        );
      }

      final header = rows.first.map((e) => e.toString().trim()).toList();
      final dataRows = rows.sublist(1);
      int missing = 0;
      final parsedList = <Map<String, dynamic>>[];

      for (final row in dataRows) {
        if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) {
          continue;
        }
        final map = <String, dynamic>{};
        for (int i = 0; i < header.length; i++) {
          final val = (i < row.length) ? row[i] : null;
          if (val == null || val.toString().trim().isEmpty) {
            missing++;
          }
          map[header[i]] = val;
        }
        parsedList.add(map);
      }

      final hasPop = header.any((c) => c.toLowerCase().contains('pop'));
      final isDistrict = header.any((c) => c.toLowerCase().contains('district'));
      final isState = header.any((c) => c.toLowerCase().contains('state'));

      String level = 'Custom Generic';
      if (isDistrict) {
        level = 'District Level';
      } else if (isState) {
        level = 'State Level';
      }

      return DatasetValidationReport(
        fileName: fileName,
        format: 'CSV',
        recordCount: parsedList.length,
        columns: header,
        missingValuesCount: missing,
        detectedLevel: level,
        detectedPeriod: _detectPeriod(header, parsedList),
        hasPopulationDenominator: hasPop,
        isValid: true,
        parsedRows: parsedList,
      );
    } catch (e) {
      return DatasetValidationReport(
        fileName: fileName,
        format: 'CSV',
        recordCount: 0,
        columns: [],
        missingValuesCount: 0,
        detectedLevel: 'Malformed CSV',
        detectedPeriod: 'Unknown',
        hasPopulationDenominator: false,
        isValid: false,
        errorMessage: 'CSV Parsing Error: $e',
        parsedRows: [],
      );
    }
  }

  void setActiveCustomDataset(DatasetValidationReport? report) {
    _activeCustomDataset = report;
  }

  String _detectPeriod(List<String> columns, List<Map<String, dynamic>> rows) {
    final yearRegex = RegExp(r'\b(19\d\d|20\d\d)\b');
    final years = <String>{};

    for (final col in columns) {
      for (final match in yearRegex.allMatches(col)) {
        years.add(match.group(0)!);
      }
    }

    if (years.isNotEmpty) {
      final sorted = years.toList()..sort();
      return sorted.join(' - ');
    }
    return '2014-2016 (Estimated)';
  }
}
