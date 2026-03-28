import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/nearby_place.dart';
import '../services/openstreet_service.dart';
import '../widgets/custom_bottom_nav_bar.dart';

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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: place == null
          ? Row(
              children: [
                Icon(icon, size: 28, color: const Color(0xFF4F8CFF)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$title not found nearby',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 28, color: const Color(0xFF4F8CFF)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
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
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  place.address,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${place.distanceKm.toStringAsFixed(2)} km away',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openDirections(place),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F8CFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Emergency Services',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadNearbyServices,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            if (_isLoading) ...[
              const SizedBox(height: 80),
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4F8CFF),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Finding nearby services...',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
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
      bottomNavigationBar: const CustomBottomNavBar(
        currentTab: AppTab.services,
      ),
    );
  }
}