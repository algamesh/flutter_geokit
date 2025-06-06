import 'package:flutter/material.dart';
import 'package:flutter_geokit/flutter_geokit.dart';
import 'package:maplibre/maplibre.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoJSON Fill Demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: StyleLayersFillPage(
        initCenter: Position(-158.8000, -20.3000), // Cook Islands
        initZoom: 6.7,
        layers: [
          const ShapeLayerConfig(
            geoJsonAsset: 'assets/sample.geojson',
            layerPrefix: 'sample',
            basePaint: <String, Object>{
              'fill-color': '#ff5722',
              'fill-opacity': 0.6,
            },
          ),
        ],
      ),
    );
  }
}
