import 'geo_geometry.dart';
import 'package:latlong2/latlong.dart';

class WKTHandler {
  GeoGeometry parseWKT(String wkt) {
    wkt = wkt.trim();
    if (wkt.startsWith('POINT')) {
      final coords = _extractCoords(wkt);
      final values = coords.split(' ');
      final x = double.parse(values[0]);
      final y = double.parse(values[1]);
      return GeoPoint(LatLng(y, x));
    } else if (wkt.startsWith('LINESTRING')) {
      final coords = _extractCoords(wkt);
      final points = coords.split(',').map((pair) {
        final values = pair.trim().split(' ');
        final x = double.parse(values[0]);
        final y = double.parse(values[1]);
        return LatLng(y, x);
      }).toList();
      return GeoLineString(points);
    } else if (wkt.startsWith('POLYGON')) {
      final coords = _extractCoords(wkt);
      final points = coords.split(',').map((pair) {
        final values = pair.trim().split(' ');
        final x = double.parse(values[0]);
        final y = double.parse(values[1]);
        return LatLng(y, x);
      }).toList();
      return GeoPolygon(points);
    } else {
      throw UnimplementedError('WKT parsing not fully implemented');
    }
  }

  String _extractCoords(String wkt) {
    final start = wkt.indexOf('(');
    final end = wkt.lastIndexOf(')');
    return wkt.substring(start + 1, end).replaceAll('(', '').replaceAll(')', '');
  }
}
