// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('assets/data/crime_maharashtra_districts.json');
  final data = jsonDecode(file.readAsStringSync()) as List;
  final recs = data.where((r) => r['reporting_year'] == 2023 && r['crime_rate'] != null).toList();
  recs.sort((a,b) => (b['crime_rate'] as num).compareTo(a['crime_rate'] as num));

  print('=== HIGH CRIME INCIDENCE (Rate >= 350 per 100k or Women Rate >= 100) ===');
  for (final r in recs) {
    final rate = r['crime_rate'] as num;
    final wRate = (r['crimes_against_women_rate'] as num?) ?? 0;
    if (rate >= 350 || wRate >= 100) {
      print('${r['district']} [${r['unit_type']}] - Rate: $rate, IPC: ${r['total_ipc_crimes']}, Women Rate: $wRate, Region: ${r['region']}');
    }
  }

  print('\n=== MODERATE CRIME INCIDENCE (Rate 250 - 349 per 100k) ===');
  for (final r in recs) {
    final rate = r['crime_rate'] as num;
    final wRate = (r['crimes_against_women_rate'] as num?) ?? 0;
    if (rate >= 250 && rate < 350 && wRate < 100) {
      print('${r['district']} [${r['unit_type']}] - Rate: $rate, IPC: ${r['total_ipc_crimes']}, Women Rate: $wRate, Region: ${r['region']}');
    }
  }

  print('\n=== LOWEST CRIME INCIDENCE (Rate < 250 per 100k) ===');
  for (final r in recs) {
    final rate = r['crime_rate'] as num;
    final wRate = (r['crimes_against_women_rate'] as num?) ?? 0;
    if (rate < 250 && wRate < 100) {
      print('${r['district']} [${r['unit_type']}] - Rate: $rate, IPC: ${r['total_ipc_crimes']}, Women Rate: $wRate, Region: ${r['region']}');
    }
  }
}
