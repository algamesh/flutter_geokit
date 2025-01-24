import 'package:latlong2/latlong.dart';

import 'geo_geometry.dart';

class GeoFeature {
  GeoGeometry geometry;
  Map<String, dynamic> properties;

  GeoFeature({required this.geometry, required this.properties});

  Map<String, dynamic> toJson() {
    return {
      'type': 'Feature',
      'geometry': geometry.toJson(),
      'properties': properties,
    };
  }

  factory GeoFeature.fromJson(Map<String, dynamic> json) {
    return GeoFeature(
      geometry: parseGeometry(json['geometry']),
      properties: Map<String, dynamic>.from(json['properties'] ?? {}),
    );
  }

  static GeoGeometry parseGeometry(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'Point':
        return GeoPoint(LatLng(json['coordinates'][1], json['coordinates'][0]));
      case 'LineString':
        return GeoLineString(
          (json['coordinates'] as List)
              .map((c) => LatLng(c[1], c[0]))
              .toList(),
        );
      case 'Polygon':
        return GeoPolygon(
          ((json['coordinates'] as List).first as List)
              .map((c) => LatLng(c[1], c[0]))
              .toList(),
        );
      case 'MultiPoint':
        return GeoMultiPoint(
          (json['coordinates'] as List)
              .map((c) => LatLng(c[1], c[0]))
              .toList(),
        );
      case 'MultiLineString':
        return GeoMultiLineString(
          (json['coordinates'] as List)
              .map((line) => (line as List)
                  .map((c) => LatLng(c[1], c[0]))
                  .toList())
              .toList(),
        );
      case 'MultiPolygon':
        return GeoMultiPolygon(
          (json['coordinates'] as List)
              .map((polygon) => ((polygon as List).first as List)
                  .map((c) => LatLng(c[1], c[0]))
                  .toList())
              .toList(),
        );
      default:
        throw UnimplementedError(
            'Geometry type not supported: ${json['type']}');
    }
  }
}
