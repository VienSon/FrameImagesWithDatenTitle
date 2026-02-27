import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  const LocationResult({required this.label, required this.isFallback});

  final String label;
  final bool isFallback;
}

class LocationService {
  Future<LocationResult> getLocationLabel() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult(label: 'Location unavailable', isFallback: true);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const LocationResult(label: 'Location unavailable', isFallback: true);
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final fallback =
        '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) {
        return LocationResult(label: fallback, isFallback: true);
      }

      final place = placemarks.first;
      final parts = <String>[
        if ((place.name ?? '').trim().isNotEmpty) place.name!.trim(),
        if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
        if ((place.administrativeArea ?? '').trim().isNotEmpty)
          place.administrativeArea!.trim(),
        if ((place.country ?? '').trim().isNotEmpty) place.country!.trim(),
      ].toSet().toList();

      if (parts.isEmpty) {
        return LocationResult(label: fallback, isFallback: true);
      }

      return LocationResult(label: parts.join(', '), isFallback: false);
    } catch (_) {
      return LocationResult(label: fallback, isFallback: true);
    }
  }
}
