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
      initialCameraPosition: CameraPosition(
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

  void _setupOverlays() {
    final overlays = widget.overlayConfigurations;
    for (var overlayId in overlays.keys) {
      final overlay = overlays[overlayId];
      final sourceId = overlay['sourceId'];
      final data = overlay['geojsonData'];
      final properties = overlay['layerProperties'];

      controller.addGeoJsonSource(sourceId, data);
      controller.addFillLayer(
        sourceId,
        overlayId,
        FillLayerProperties(
          fillColor: properties['fillColor'] ?? '#FF0000',
          fillOpacity: properties['fillOpacity'] ?? 0.5,
        ),
        enableInteraction: properties['interactive'] ?? false,
      );
    }
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
    final selectedGeometry = feature['geometry'];
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
