import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre/maplibre.dart';

/// Configuration object that describes a fill layer and its styling.
@immutable
class ShapeLayerConfig {
  final String geoJsonAsset;
  final String sourceId;
  final String layerId;
  final Map<String, Object> paint;

  const ShapeLayerConfig({
    required this.geoJsonAsset,
    required this.sourceId,
    required this.layerId,
    this.paint = const <String, Object>{'fill-color': '#429ef5'},
  });
}

/// Page that renders any number of fill‐style layers described by a list of
/// [ShapeLayerConfig] objects. If at least one GeoJSON is loaded, the camera
/// recenters on the *first coordinate* it encounters in the first layer and
/// applies a sensible zoom so the feature is clearly visible.
@immutable
class StyleLayersFillPage extends StatefulWidget {
  const StyleLayersFillPage({
    Key? key,
    required this.layers,
    this.initCenter,
    this.initZoom = 7,
    this.geoJsonZoom = 11,
  }) : super(key: key);

  static const location = '/style-layers/fill';

  final List<ShapeLayerConfig> layers;
  final Position? initCenter;
  final double initZoom;
  final double geoJsonZoom;

  @override
  State<StyleLayersFillPage> createState() => _StyleLayersFillPageState();
}

class _StyleLayersFillPageState extends State<StyleLayersFillPage> {
  late MapController _controller;
  bool _recentred = false;

  Position get _center => widget.initCenter ?? Position(9.17, 47.68);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fill Style Layer')),
      body: MapLibreMap(
        options: MapOptions(
          initZoom: widget.initZoom,
          initCenter: _center,
        ),
        onMapCreated: (c) => _controller = c,
        onStyleLoaded: _onStyleLoaded,
        onEvent: _handleClick,
      ),
    );
  }

  Future<void> _onStyleLoaded(StyleController style) async {
    for (final layer in widget.layers) {
      final geoStr = await rootBundle.loadString(layer.geoJsonAsset);
      await style.addSource(GeoJsonSource(id: layer.sourceId, data: geoStr));
      await style.addLayer(FillStyleLayer(
        id: layer.layerId,
        sourceId: layer.sourceId,
        paint: layer.paint,
      ));

      if (!_recentred) {
        final first = _firstCoord(geoStr);
        if (first != null) {
          await _controller.moveCamera(center: first, zoom: widget.geoJsonZoom);
          _recentred = true;
        }
      }
    }
  }

  /// Quickly extracts the first [lon, lat] pair from a GeoJSON string.
  Position? _firstCoord(String geo) {
    final obj = jsonDecode(geo) as Map<String, dynamic>;
    dynamic coords;
    if (obj['type'] == 'FeatureCollection') {
      coords = (obj['features'] as List).first['geometry']['coordinates'];
    } else if (obj['type'] == 'Feature') {
      coords = obj['geometry']['coordinates'];
    } else {
      coords = obj['coordinates'];
    }
    while (coords is List && coords.isNotEmpty && coords.first is List) {
      coords = coords.first;
    }
    if (coords is List && coords.length >= 2) {
      final lon = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      return Position(lon, lat);
    }
    return null;
  }

  Future<void> _handleClick(MapEvent event) async {
    if (event case MapEventClick()) {
      final pt = await _controller.toScreenLocation(event.point);
      final layers = await _controller.queryLayers(pt);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
              content: Text(
                  '${layers.length} layers: ${layers.map((e) => e.layerId).join(', ')}')),
        );
    }
  }
}
