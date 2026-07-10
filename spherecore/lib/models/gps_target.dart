class GpsTarget {
  final double lat;
  final double lon;

  GpsTarget({required this.lat, required this.lon});

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon};
}
