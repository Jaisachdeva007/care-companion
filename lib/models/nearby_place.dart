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

class NearbyPlaceResult {
  final bool isNearest;
  // nearest mode
  final NearbyPlace? hospital;
  final NearbyPlace? pharmacy;
  final NearbyPlace? clinic;
  final NearbyPlace? er;
  // radius mode
  final List<NearbyPlace> allPlaces;

  NearbyPlaceResult.nearest({
    this.hospital,
    this.pharmacy,
    this.clinic,
    this.er,
  })  : isNearest = true,
        allPlaces = const [];

  NearbyPlaceResult.all(this.allPlaces)
      : isNearest = false,
        hospital = null,
        pharmacy = null,
        clinic = null,
        er = null;
}