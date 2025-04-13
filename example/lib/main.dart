import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_geokit/flutter_geokit.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const GeoJsonMapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GeoJsonMapScreen extends StatefulWidget {
  const GeoJsonMapScreen({super.key});

  @override
  _GeoJsonMapScreenState createState() => _GeoJsonMapScreenState();
}

class _GeoJsonMapScreenState extends State<GeoJsonMapScreen> {
  Map<String, dynamic>? geoJsonSample;

  @override
  void initState() {
    super.initState();
    _loadGeoJsonData();
  }

  Future<void> _loadGeoJsonData() async {
    final sampleGeoJsonString = await rootBundle.loadString(
      'assets/sample.geojson',
    );

    setState(() {
      geoJsonSample = jsonDecode(sampleGeoJsonString);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (geoJsonSample == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final overlayConfigurations = {
      'new_taz_overlay': {
        'sourceId': 'new_taz_source',
        'geojsonData': geoJsonSample,
        'layerProperties': {
          'fillColor': '#00FF00',
          'fillOpacity': 0.6,
          'interactive': true,
        },
      },
    };

    return Scaffold(
      appBar: AppBar(title: const Text('GeoShape Overlay Map')),
      body: GeoShapeOverlayMap(
        overlayConfigurations: overlayConfigurations,
        onFeatureSelect: (overlayId, featureId) {
          debugPrint('Selected feature: $featureId from overlay: $overlayId');
        },
      ),
    );
  }
}
