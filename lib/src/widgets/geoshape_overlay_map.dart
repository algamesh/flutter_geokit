import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'dart:math' show Point;

class GeoShapeOverlayMap extends StatefulWidget {
  final Map<String, dynamic> overlayConfigurations;
  final Function(String overlayId, dynamic featureId)? onFeatureSelect;

  const GeoShapeOverlayMap({
    Key? key,
    required this.overlayConfigurations,
    this.onFeatureSelect,
  }) : super(key: key);

  @override
  _GeoShapeOverlayMapState createState() => _GeoShapeOverlayMapState();
}

class _GeoShapeOverlayMapState extends State<GeoShapeOverlayMap> {
  late MapLibreMapController controller;

  @override
  Widget build(BuildContext context) {
    return MaplibreMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(42.3601, -71.0589),
        zoom: 10,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _setupOverlays,
      onMapClick: _onMapClick,
    );
  }

  void _onMapCreated(MapLibreMapController ctrl) {
    setState(() => controller = ctrl);
  }

  /// After the style loads, set up overlays and adjust the camera
  void _setupOverlays() async {
    final overlays = widget.overlayConfigurations;
    // A list to accumulate all coordinates from all overlays
    final List<LatLng> allCoordinates = [];

    for (var overlayId in overlays.keys) {
      final overlay = overlays[overlayId];
      final sourceId = overlay['sourceId'];
      final data = overlay['geojsonData'];
      final properties = overlay['layerProperties'];

      // Add the GeoJSON source and layer
      await controller.addGeoJsonSource(sourceId, data);
      await controller.addFillLayer(
        sourceId,
        overlayId,
        FillLayerProperties(
          fillColor: properties['fillColor'] ?? '#FF0000',
          fillOpacity: properties['fillOpacity'] ?? 0.5,
        ),
        enableInteraction: properties['interactive'] ?? false,
      );

      // Extract coordinates from the GeoJSON
      // This simple example assumes that the data is a FeatureCollection
      // with features that have geometries of type Polygon or MultiPolygon.
      if (data['type'] == 'FeatureCollection') {
        for (var feature in data['features']) {
          final geometry = feature['geometry'];
          if (geometry != null) {
            final type = geometry['type'];
            final coords = geometry['coordinates'];
            if (type == 'Polygon') {
              // coords is a list of rings; use the first ring
              for (var coord in coords[0]) {
                allCoordinates.add(LatLng(coord[1], coord[0]));
              }
            } else if (type == 'MultiPolygon') {
              // coords is a list of polygons; iterate over each
              for (var polygon in coords) {
                for (var coord in polygon[0]) {
                  allCoordinates.add(LatLng(coord[1], coord[0]));
                }
              }
            }
            // You can add additional cases (e.g., Point, LineString) as needed.
          }
        }
      }
    }

    // If coordinates were found, compute the bounds and update the camera.
    if (allCoordinates.isNotEmpty) {
      final bounds = _computeBounds(allCoordinates);
      // Optionally, set some padding (in pixels) to ensure the shapes are not too close to the edge.
      final double padding = 50;
      controller.moveCamera(CameraUpdate.newLatLngBounds(bounds,
          left: padding, top: padding, right: padding, bottom: padding));
    }
  }

  /// Compute the bounding box from a list of LatLng coordinates.
  LatLngBounds _computeBounds(List<LatLng> coordinates) {
    double? minLat, minLng, maxLat, maxLng;
    for (var coord in coordinates) {
      if (minLat == null || coord.latitude < minLat) minLat = coord.latitude;
      if (minLng == null || coord.longitude < minLng) minLng = coord.longitude;
      if (maxLat == null || coord.latitude > maxLat) maxLat = coord.latitude;
      if (maxLng == null || coord.longitude > maxLng) maxLng = coord.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  void _onMapClick(Point<double> point, LatLng coordinates) async {
    final overlays = widget.overlayConfigurations;
    for (var overlayId in overlays.keys) {
      final properties = overlays[overlayId]['layerProperties'];
      if (!(properties['interactive'] ?? false)) continue;

      final features = await controller.queryRenderedFeatures(
          point,
          [
            overlayId,
          ],
          null);

      if (features.isNotEmpty) {
        final feature = features.first;
        final featureId = feature['id'] ?? feature['properties']['id'];

        if (widget.onFeatureSelect != null && featureId != null) {
          widget.onFeatureSelect!(overlayId, featureId);
        }

        _highlightFeature(overlayId, feature);
        break;
      }
    }
  }

  void _highlightFeature(String overlayId, dynamic feature) async {
    final highlightSourceId = 'highlight_$overlayId';

    final highlightGeoJson = {
      'type': 'FeatureCollection',
      'features': [feature],
    };

    final existingSources = await controller.getSourceIds();
    if (!existingSources.contains(highlightSourceId)) {
      await controller.addGeoJsonSource(highlightSourceId, highlightGeoJson);
      await controller.addFillLayer(
        highlightSourceId,
        'highlight_layer_$overlayId',
        FillLayerProperties(fillColor: '#FFFF00', fillOpacity: 0.8),
        belowLayerId: overlayId,
      );
    } else {
      await controller.setGeoJsonSource(highlightSourceId, highlightGeoJson);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
