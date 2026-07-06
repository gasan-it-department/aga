import '../models/navigation_coordinate.dart';

/// Decodes Google/OSRM encoded polylines without using Google services.
class PolylineDecoder {
  static List<NavigationCoordinate> decode(
    String encoded, {
    int precision = 6,
  }) {
    if (encoded.isEmpty) return const [];
    final coordinates = <NavigationCoordinate>[];
    var index = 0;
    var lat = 0;
    var lng = 0;
    final factor = _pow10(precision);

    while (index < encoded.length) {
      final latResult = _decodeValue(encoded, index);
      index = latResult.nextIndex;
      lat += latResult.value;

      final lonResult = _decodeValue(encoded, index);
      index = lonResult.nextIndex;
      lng += lonResult.value;

      coordinates.add(
        NavigationCoordinate(
          latitude: lat / factor,
          longitude: lng / factor,
          accuracyMeters: 0,
          timestamp: DateTime.now(),
        ),
      );
    }
    return coordinates;
  }

  static _DecodeResult _decodeValue(String encoded, int startIndex) {
    var result = 0;
    var shift = 0;
    var index = startIndex;
    int byte;
    do {
      if (index >= encoded.length) throw FormatException('Invalid polyline.');
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    final value = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    return _DecodeResult(value, index);
  }

  static double _pow10(int precision) {
    var value = 1.0;
    for (var i = 0; i < precision; i++) {
      value *= 10;
    }
    return value;
  }
}

class _DecodeResult {
  final int value;
  final int nextIndex;
  const _DecodeResult(this.value, this.nextIndex);
}
