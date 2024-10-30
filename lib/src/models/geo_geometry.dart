import 'package:latlong2/latlong.dart';

abstract class GeoGeometry {
  GeoGeometry();

  Map<String, dynamic> toJson();
  String toWKT();
}

class GeoPoint extends GeoGeometry {
  final LatLng point;

  GeoPoint(this.point) : super();

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'Point',
      'coordinates': [point.longitude, point.latitude],
    };
  }

  @override
  String toWKT() {
    return 'POINT (${point.longitude} ${point.latitude})';
  }
}

class GeoLineString extends GeoGeometry {
  final List<LatLng> points;

  GeoLineString(this.points) : super();

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'LineString',
      'coordinates': points.map((p) => [p.longitude, p.latitude]).toList(),
    };
  }

  @override
  String toWKT() {
    final coords = points.map((p) => '${p.longitude} ${p.latitude}').join(', ');
    return 'LINESTRING ($coords)';
  }
}

class GeoPolygon extends GeoGeometry {
  final List<LatLng> points;

  GeoPolygon(this.points) : super();

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'Polygon',
      'coordinates': [
        points.map((p) => [p.longitude, p.latitude]).toList(),
      ],
    };
  }

  @override
  String toWKT() {
    final coords = points.map((p) => '${p.longitude} ${p.latitude}').join(', ');
    return 'POLYGON (($coords))';
  }
}

class GeoMultiPoint extends GeoGeometry {
  final List<LatLng> points;

  GeoMultiPoint(this.points);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'MultiPoint',
      'coordinates': points.map((p) => [p.longitude, p.latitude]).toList(),
    };
  }

  @override
  String toWKT() {
    final coords = points.map((p) => '(${p.longitude} ${p.latitude})').join(', ');
    return 'MULTIPOINT ($coords)';
  }
}

class GeoMultiLineString extends GeoGeometry {
  final List<List<LatLng>> lineStrings;

  GeoMultiLineString(this.lineStrings);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'MultiLineString',
      'coordinates': lineStrings
          .map((line) => line.map((p) => [p.longitude, p.latitude]).toList())
          .toList(),
    };
  }

  @override
  String toWKT() {
    final lines = lineStrings.map((line) {
      final coords = line.map((p) => '${p.longitude} ${p.latitude}').join(', ');
      return '($coords)';
    }).join(', ');
    return 'MULTILINESTRING ($lines)';
  }
}

class GeoMultiPolygon extends GeoGeometry {
  final List<List<LatLng>> polygons;

  GeoMultiPolygon(this.polygons);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'MultiPolygon',
      'coordinates': polygons
          .map((polygon) => [
                polygon.map((p) => [p.longitude, p.latitude]).toList(),
              ])
          .toList(),
    };
  }

  @override
  String toWKT() {
    final polys = polygons.map((polygon) {
      final coords = polygon.map((p) => '${p.longitude} ${p.latitude}').join(', ');
      return '(($coords))';
    }).join(', ');
    return 'MULTIPOLYGON ($polys)';
  }
}
