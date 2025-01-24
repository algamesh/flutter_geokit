import 'dart:convert';
import 'dart:io';
import 'models/geo_feature.dart';

class GeoJSONHandler {
  List<GeoFeature> features = [];

  Future<void> parseGeoJSONFile(String filePath) async {
    final file = File(filePath);
    final contents = await file.readAsString();
    parseGeoJSONString(contents);
  }

  void parseGeoJSONString(String geoJsonString) {
    final decoded = json.decode(geoJsonString);
    if (decoded['type'] != 'FeatureCollection') {
      throw const FormatException('Invalid GeoJSON: must be a FeatureCollection');
    }

    features = (decoded['features'] as List)
        .map((feature) => GeoFeature.fromJson(feature))
        .toList();
  }

  void addFeature(GeoFeature feature) {
    features.add(feature);
  }

  void removeFeature(GeoFeature feature) {
    features.remove(feature);
  }

  String exportToGeoJSON() {
    final featureCollection = {
      'type': 'FeatureCollection',
      'features': features.map((f) => f.toJson()).toList(),
    };
    return json.encode(featureCollection);
  }

  Future<void> saveToGeoJSONFile(String filePath) async {
    final file = File(filePath);
    await file.writeAsString(exportToGeoJSON());
  }
}
