import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class GeoShapeOverlayMap extends StatefulWidget {
  const GeoShapeOverlayMap({
    super.key,
    required this.overlayConfigurations,
  });

  final Map<String, Map<String, dynamic>> overlayConfigurations;

  @override
  State<GeoShapeOverlayMap> createState() => _GeoShapeOverlayMapState();
}

class _GeoShapeOverlayMapState extends State<GeoShapeOverlayMap> {
  late MapLibreMapController _ctl;

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(42.3601, -71.0589),
        zoom: 10,
      ),
      onMapCreated: (c) => _ctl = c,
      onStyleLoadedCallback: _addLayers,
    );
  }

  Future<void> _addLayers() async {
    final padding = 50.0;
    List<LatLng> extent = [];

    for (final entry in widget.overlayConfigurations.entries) {
      final overlayId = entry.key;
      final cfg = entry.value;
      final geojson = cfg['geojsonData'] as Map<String, dynamic>;
      final props = cfg['layerProperties'] as Map<String, dynamic>? ?? {};

      final String color = props['fillColor'] ?? '#ff0000';
      final double opacity = (props['fillOpacity'] ?? 0.5).toDouble();
      final bool hitTest = props['interactive'] ?? false;

      // ➊ add source
      await _ctl.addGeoJsonSource(overlayId, geojson);

      // ➋ add layer
      await _ctl.addFillLayer(
        overlayId, // sourceId
        '${overlayId}_layer', // layerId
        FillLayerProperties(
          fillColor: color,
          fillOpacity: opacity,
        ),
        enableInteraction: hitTest, // activates onFeatureTapped callback
      );

      // ➌ collect coords for camera‑fit
      if (geojson['type'] == 'FeatureCollection') {
        for (final f in geojson['features']) {
          final geom = f['geometry'];
          _extractCoords(geom, extent);
        }
      }
    }

    if (extent.isNotEmpty) {
      _ctl.moveCamera(
        CameraUpdate.newLatLngBounds(
          _bounds(extent),
          left: padding,
          top: padding,
          right: padding,
          bottom: padding,
        ),
      );
    }
  }

  /* helpers */

  void _extractCoords(dynamic geom, List<LatLng> out) {
    switch (geom?['type']) {
      case 'Polygon':
        for (final c in geom['coordinates'][0]) {
          out.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
        }
        break;
      case 'MultiPolygon':
        for (final poly in geom['coordinates']) {
          for (final c in poly[0]) {
            out.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
          }
        }
    }
  }

  LatLngBounds _bounds(List<LatLng> pts) {
    double minLa = pts.first.latitude,
        maxLa = pts.first.latitude,
        minLo = pts.first.longitude,
        maxLo = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLa) minLa = p.latitude;
      if (p.latitude > maxLa) maxLa = p.latitude;
      if (p.longitude < minLo) minLo = p.longitude;
      if (p.longitude > maxLo) maxLo = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLa, minLo),
      northeast: LatLng(maxLa, maxLo),
    );
  }
}
