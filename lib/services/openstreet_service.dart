import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/nearby_place.dart';

class OpenStreetService {
  static const String _baseUrl =
      'https://lz4.overpass-api.de/api/interpreter';

  /// Returns nearest-one-per-category when [nearestOnly] is true,
  /// otherwise returns all places within [maxDistanceKm].
  Future<NearbyPlaceResult> getAllNearbyPlaces(
    double lat,
    double lng, {
    int radiusMeters = 20000,
    double? maxDistanceKm,
    bool nearestOnly = false,
  }) async {
    final r = radiusMeters;
    final query = '''
[out:json][timeout:15];
(
  node["amenity"="hospital"](around:$r,$lat,$lng);
  way["amenity"="hospital"](around:$r,$lat,$lng);
  relation["amenity"="hospital"](around:$r,$lat,$lng);

  node["amenity"="pharmacy"](around:$r,$lat,$lng);
  way["amenity"="pharmacy"](around:$r,$lat,$lng);
  relation["amenity"="pharmacy"](around:$r,$lat,$lng);

  node["healthcare"="clinic"](around:$r,$lat,$lng);
  way["healthcare"="clinic"](around:$r,$lat,$lng);
  relation["healthcare"="clinic"](around:$r,$lat,$lng);
  node["amenity"="clinic"](around:$r,$lat,$lng);
  way["amenity"="clinic"](around:$r,$lat,$lng);
  relation["amenity"="clinic"](around:$r,$lat,$lng);

  node["emergency"="yes"](around:$r,$lat,$lng);
  way["emergency"="yes"](around:$r,$lat,$lng);
  relation["emergency"="yes"](around:$r,$lat,$lng);

  node["emergency"="department"](around:$r,$lat,$lng);
  way["emergency"="department"](around:$r,$lat,$lng);
  relation["emergency"="department"](around:$r,$lat,$lng);

  node["amenity"="hospital"]["emergency"="yes"](around:$r,$lat,$lng);
  way["amenity"="hospital"]["emergency"="yes"](around:$r,$lat,$lng);
  relation["amenity"="hospital"]["emergency"="yes"](around:$r,$lat,$lng);

  node["amenity"="hospital"]["emergency"="department"](around:$r,$lat,$lng);
  way["amenity"="hospital"]["emergency"="department"](around:$r,$lat,$lng);
  relation["amenity"="hospital"]["emergency"="department"](around:$r,$lat,$lng);
);
out center;
''';

    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          },
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception(_friendlyErrorMessage(response.statusCode));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = (data['elements'] as List<dynamic>? ?? []);

    NearbyPlace? nearestHospital;
    NearbyPlace? nearestPharmacy;
    NearbyPlace? nearestClinic;
    NearbyPlace? nearestEr;

    final allPlaces = <NearbyPlace>[];

    for (final element in elements) {
      if (element is! Map<String, dynamic>) continue;

      final tags =
          (element['tags'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};

      double? placeLat;
      double? placeLng;

      if (element['lat'] != null && element['lon'] != null) {
        placeLat = (element['lat'] as num).toDouble();
        placeLng = (element['lon'] as num).toDouble();
      } else if (element['center'] != null) {
        placeLat = (element['center']['lat'] as num).toDouble();
        placeLng = (element['center']['lon'] as num).toDouble();
      }

      if (placeLat == null || placeLng == null) continue;

      final distance = _calculateDistanceKm(lat, lng, placeLat, placeLng);

      if (maxDistanceKm != null && distance > maxDistanceKm) continue;

      final isHospital = tags['amenity'] == 'hospital';
      final isPharmacy = tags['amenity'] == 'pharmacy';
      final isClinic =
          tags['healthcare'] == 'clinic' || tags['amenity'] == 'clinic';
      final isER =
          tags['emergency'] == 'yes' ||
          tags['emergency'] == 'department' ||
          (tags['amenity'] == 'hospital' &&
              (tags['emergency'] == 'yes' ||
                  tags['emergency'] == 'department'));

      String? category;
      String fallbackName;

      if (isER) {
        category = 'Emergency Room';
        fallbackName = 'Nearby Emergency Room';
      } else if (isHospital) {
        category = 'Hospital';
        fallbackName = 'Nearby Hospital';
      } else if (isClinic) {
        category = 'Walk-in Clinic';
        fallbackName = 'Nearby Walk-in Clinic';
      } else if (isPharmacy) {
        category = 'Pharmacy';
        fallbackName = 'Nearby Pharmacy';
      } else {
        continue;
      }

      final place = NearbyPlace(
        name: _fallbackName(tags, fallbackName),
        address: _buildAddress(tags),
        lat: placeLat,
        lng: placeLng,
        distanceKm: distance,
        category: category,
      );

      if (isHospital && (nearestHospital == null || distance < nearestHospital.distanceKm)) {
        nearestHospital = place;
      }
      if (isPharmacy && (nearestPharmacy == null || distance < nearestPharmacy.distanceKm)) {
        nearestPharmacy = place;
      }
      if (isClinic && (nearestClinic == null || distance < nearestClinic.distanceKm)) {
        nearestClinic = place;
      }
      if (isER && (nearestEr == null || distance < nearestEr.distanceKm)) {
        nearestEr = place;
      }

      allPlaces.add(place);
    }

    if (nearestOnly) {
      return NearbyPlaceResult.nearest(
        hospital: nearestHospital,
        pharmacy: nearestPharmacy,
        clinic: nearestClinic,
        er: nearestEr,
      );
    }

    allPlaces.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return NearbyPlaceResult.all(allPlaces);
  }

  String _fallbackName(Map<String, dynamic> tags, String fallback) {
    final name = tags['name']?.toString().trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return fallback;
  }

  String _friendlyErrorMessage(int statusCode) {
    switch (statusCode) {
      case 429:
        return 'Too many requests right now. Please try again in a moment.';
      case 504:
        return 'Nearby service lookup timed out. Please try again.';
      default:
        return 'Could not load nearby services right now.';
    }
  }

  String _buildAddress(Map<String, dynamic> tags) {
    final parts = [
      tags['addr:housenumber'],
      tags['addr:street'],
      tags['addr:city'],
      tags['addr:province'],
    ]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .map((e) => e.toString())
        .toList();

    if (parts.isEmpty) {
      return 'Address not available';
    }

    return parts.join(', ');
  }

  double _calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0;

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _toRadians(double degree) => degree * pi / 180.0;
}