class NearbyPlace {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final double distanceKm;
  final String category;

  NearbyPlace({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    required this.category,
  });
}