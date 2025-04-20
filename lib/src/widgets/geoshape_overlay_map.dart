// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre/maplibre.dart';

/// Describe a GeoJSON file to load and its base fill paint.
@immutable
class ShapeLayerConfig {
  final String geoJsonAsset;
  final String layerPrefix; // stem used for generated IDs
  final Map<String, Object> basePaint;
  const ShapeLayerConfig({
    required this.geoJsonAsset,
    required this.layerPrefix,
    this.basePaint = const <String, Object>{'fill-color': '#429ef5'},
  });
}

/// Map widget that draws all polygons (via a single *base* layer) **and** lets
/// users toggle a yellow highlight on individual features. Works even when the
/// GeoJSON lacks numeric IDs by assigning synthetic ones.
class StyleLayersFillPage extends StatefulWidget {
  const StyleLayersFillPage({
    super.key,
    required this.layers,
    this.initCenter,
    this.initZoom = 7,
    this.zoomOnLoad = 11,
  });

  final List<ShapeLayerConfig> layers;
  final Position? initCenter;
  final double initZoom;
  final double zoomOnLoad;

  @override
  State<StyleLayersFillPage> createState() => _StyleLayersFillPageState();
}

class _StyleLayersFillPageState extends State<StyleLayersFillPage> {
  late MapController _ctrl;
  StyleController? _style;
  bool _cameraDone = false;

  /// overlay layers currently visible
  final Set<String> _activeHighlights = {};

  /// map layerId → sourceId (for quick overlay creation)
  final Map<String, String> _layerToSource = {};

  Position get _center => widget.initCenter ?? Position(9.17, 47.68);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Per‑Feature Highlight Map')),
        body: MapLibreMap(
          options: MapOptions(initCenter: _center, initZoom: widget.initZoom),
          onMapCreated: (c) => _ctrl = c,
          onStyleLoaded: _onStyleLoaded,
          onEvent: _onEvent,
        ),
      );

  /* ---------------- style load ---------------- */
  Future<void> _onStyleLoaded(StyleController style) async {
    _style = style;

    for (final cfg in widget.layers) {
      // Load the entire file once.
      final geoStr = await rootBundle.loadString(cfg.geoJsonAsset);
      final fc = jsonDecode(geoStr) as Map<String, dynamic>;

      // 1️⃣  Add a *base* source/layer so all polygons are visible regardless of IDs.
      await style.addSource(GeoJsonSource(id: cfg.layerPrefix, data: geoStr));
      await style.addLayer(FillStyleLayer(
        id: '${cfg.layerPrefix}_base',
        sourceId: cfg.layerPrefix,
        paint: cfg.basePaint,
      ));

      // 2️⃣  Split into per‑feature layers for interactivity.
      if (fc['type'] == 'FeatureCollection') {
        int synthetic = 0;
        for (final f in (fc['features'] as List)) {
          int id;
          if (f['id'] is num) {
            id = (f['id'] as num).toInt();
          } else {
            id = synthetic++; // assign synthetic id if missing
            f['id'] = id;
          }

          final srcId = '${cfg.layerPrefix}_src_$id';
          final lyrId = '${cfg.layerPrefix}_ly_$id';
          _layerToSource[lyrId] = srcId;

          final singleFc = jsonEncode({
            'type': 'FeatureCollection',
            'features': [f]
          });
          await style.addSource(GeoJsonSource(id: srcId, data: singleFc));
          await style.addLayer(FillStyleLayer(
            id: lyrId,
            sourceId: srcId,
            paint: cfg.basePaint,
          ));
        }
      }

      // Center camera once on first coordinate.
      if (!_cameraDone) {
        final firstPosition = _extractFirstPosition(fc);
        if (firstPosition != null) {
          await _ctrl.moveCamera(
              center: firstPosition, zoom: widget.zoomOnLoad);
          _cameraDone = true;
        }
      }
    }
  }

  /* ---------------- click handler ---------------- */
  Future<void> _onEvent(MapEvent e) async {
    if (e is! MapEventClick || _style == null) return;

    final screenPt = await _ctrl.toScreenLocation(e.point);
    final hits = await _ctrl.queryLayers(screenPt);
    if (hits.isEmpty) return;

    final layerId = hits.first.layerId;
    // Skip overlay and base layers.
    if (layerId.endsWith('_hl') || layerId.endsWith('_base')) return;

    final overlayId = '${layerId}_hl';
    final srcId = _layerToSource[layerId]!;

    if (_activeHighlights.remove(overlayId)) {
      await _style!.removeLayer(overlayId);
    } else {
      await _style!.addLayer(FillStyleLayer(
        id: overlayId,
        sourceId: srcId,
        paint: const <String, Object>{
          'fill-color': '#FFFF00',
          'fill-opacity': 0.5,
        },
      ));
      _activeHighlights.add(overlayId);
    }
  }

  /* ---------------- helpers ---------------- */
  Position? _extractFirstPosition(Map<String, dynamic> geo) {
    dynamic coords;
    switch (geo['type']) {
      case 'FeatureCollection':
        coords = (geo['features'] as List).first['geometry']['coordinates'];
        break;
      case 'Feature':
        coords = geo['geometry']['coordinates'];
        break;
      default:
        coords = geo['coordinates'];
    }
    while (coords is List && coords.isNotEmpty && coords.first is List) {
      coords = coords.first;
    }
    if (coords is List && coords.length >= 2) {
      return Position(
          (coords[0] as num).toDouble(), (coords[1] as num).toDouble());
    }
    return null;
  }
}
