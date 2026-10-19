import 'package:flutter/material.dart';

enum EmergencyCategory {
  all,
  police,
  hospital,
  clinic,
  pharmacy,
  fireStation,
  ambulance,
  touristInfo,
}

extension EmergencyCategoryExtension on EmergencyCategory {
  String get label {
    switch (this) {
      case EmergencyCategory.all:
        return 'All Services';
      case EmergencyCategory.police:
        return 'Police';
      case EmergencyCategory.hospital:
        return 'Hospitals';
      case EmergencyCategory.clinic:
        return 'Clinics';
      case EmergencyCategory.pharmacy:
        return 'Pharmacies';
      case EmergencyCategory.fireStation:
        return 'Fire Stations';
      case EmergencyCategory.ambulance:
        return 'Ambulance';
      case EmergencyCategory.touristInfo:
        return 'Tourist Info';
    }
  }

  String get singularType {
    switch (this) {
      case EmergencyCategory.all:
        return 'Emergency Service';
      case EmergencyCategory.police:
        return 'Police Station';
      case EmergencyCategory.hospital:
        return 'Hospital';
      case EmergencyCategory.clinic:
        return 'Clinic / Medical Centre';
      case EmergencyCategory.pharmacy:
        return 'Pharmacy';
      case EmergencyCategory.fireStation:
        return 'Fire Station';
      case EmergencyCategory.ambulance:
        return 'Ambulance Station';
      case EmergencyCategory.touristInfo:
        return 'Tourist Assistance';
    }
  }

  IconData get icon {
    switch (this) {
      case EmergencyCategory.all:
        return Icons.emergency_outlined;
      case EmergencyCategory.police:
        return Icons.local_police_outlined;
      case EmergencyCategory.hospital:
        return Icons.local_hospital_outlined;
      case EmergencyCategory.clinic:
        return Icons.medical_services_outlined;
      case EmergencyCategory.pharmacy:
        return Icons.local_pharmacy_outlined;
      case EmergencyCategory.fireStation:
        return Icons.local_fire_department_outlined;
      case EmergencyCategory.ambulance:
        return Icons.airport_shuttle_outlined;
      case EmergencyCategory.touristInfo:
        return Icons.assistant_direction_outlined;
    }
  }

  Color get color {
    switch (this) {
      case EmergencyCategory.all:
        return const Color(0xFF0F766E);
      case EmergencyCategory.police:
        return const Color(0xFF1D4ED8);
      case EmergencyCategory.hospital:
        return const Color(0xFFDC2626);
      case EmergencyCategory.clinic:
        return const Color(0xFF059669);
      case EmergencyCategory.pharmacy:
        return const Color(0xFF0891B2);
      case EmergencyCategory.fireStation:
        return const Color(0xFFEA580C);
      case EmergencyCategory.ambulance:
        return const Color(0xFFB91C1C);
      case EmergencyCategory.touristInfo:
        return const Color(0xFF7C3AED);
    }
  }
}

class EmergencyServicePlace {
  final String id;
  final String name;
  final bool hasVerifiedName;
  final EmergencyCategory category;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String? address;
  final String? phone;
  final String? openingHours;

  const EmergencyServicePlace({
    required this.id,
    required this.name,
    required this.hasVerifiedName,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.address,
    this.phone,
    this.openingHours,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'hasVerifiedName': hasVerifiedName,
        'category': category.name,
        'latitude': latitude,
        'longitude': longitude,
        'distanceKm': distanceKm,
        'address': address,
        'phone': phone,
        'openingHours': openingHours,
      };

  factory EmergencyServicePlace.fromJson(Map<String, dynamic> json) {
    final catName = json['category'] as String? ?? 'hospital';
    final category = EmergencyCategory.values.firstWhere(
      (e) => e.name == catName,
      orElse: () => EmergencyCategory.hospital,
    );
    return EmergencyServicePlace(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? category.singularType,
      hasVerifiedName: json['hasVerifiedName'] as bool? ?? true,
      category: category,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      openingHours: json['openingHours'] as String?,
    );
  }
}
