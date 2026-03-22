import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/nearby_place.dart';
import '../services/openstreet_service.dart';

class EmergencyServicesScreen extends StatefulWidget {
  const EmergencyServicesScreen({super.key});

  @override
  State<EmergencyServicesScreen> createState() =>
      _EmergencyServicesScreenState();
}

class _EmergencyServicesScreenState extends State<EmergencyServicesScreen> {
  final OpenStreetService _service = OpenStreetService();

  bool _isLoading = true;
  String? _error;

  NearbyPlace? _hospital;
  NearbyPlace? _pharmacy;
  NearbyPlace? _clinic;
  NearbyPlace? _er;

  @override
  void initState() {
    super.initState();
    _loadNearbyServices();
  }

  Future<void> _loadNearbyServices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are turned off.');
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission permanently denied. Please enable it in Settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final results = await _service.getAllNearbyPlaces(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _hospital = results['hospital'];
        _pharmacy = results['pharmacy'];
        _clinic = results['clinic'];
        _er = results['er'];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _openDirections(NearbyPlace place) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${place.lat},${place.lng}',
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open directions')),
      );
    }
  }

  Widget _buildPlaceCard(String title, IconData icon, NearbyPlace? place) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: place == null
            ? Row(
                children: [
                  Icon(icon, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$title not found nearby',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(place.address),
                  const SizedBox(height: 6),
                  Text('${place.distanceKm.toStringAsFixed(2)} km away'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _openDirections(place),
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Services'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNearbyServices,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoading) ...[
              const SizedBox(height: 80),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              const Center(child: Text('Finding nearby services...')),
            ] else if (_error != null) ...[
              const SizedBox(height: 40),
              Center(
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadNearbyServices,
                child: const Text('Try Again'),
              ),
            ] else ...[
              _buildPlaceCard(
                'Nearest Hospital',
                Icons.local_hospital,
                _hospital,
              ),
              _buildPlaceCard(
                'Nearest ER',
                Icons.emergency,
                _er,
              ),
              _buildPlaceCard(
                'Nearest Walk-in Clinic',
                Icons.medical_services,
                _clinic,
              ),
              _buildPlaceCard(
                'Nearest Pharmacy',
                Icons.local_pharmacy,
                _pharmacy,
              ),
            ],
          ],
        ),
      ),
    );
  }
}