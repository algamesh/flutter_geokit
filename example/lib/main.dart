import 'package:flutter/material.dart';
import 'package:flutter_geokit/flutter_geokit.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const GeoDataApp());
}

class GeoDataApp extends StatelessWidget {
  const GeoDataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoData Handler Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: false,
      ),
      home: const GeoDataHomePage(),
    );
  }
}

class GeoDataHomePage extends StatefulWidget {
  const GeoDataHomePage({super.key});

  @override
  _GeoDataHomePageState createState() => _GeoDataHomePageState();
}

class _GeoDataHomePageState extends State<GeoDataHomePage> {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  List<Polygon> _polygons = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoData Handler Example'),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(0, 0),
                initialZoom: 2.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: _markers,
                ),
                PolylineLayer(
                  polylines: _polylines,
                ),
                PolygonLayer(
                  polygons: _polygons,
                ),
              ],
            ),
          ),
          OverflowBar(
            alignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _loadGeoJSON,
                child: const Text('Load GeoJSON'),
              ),
              ElevatedButton(
                onPressed: _loadShapefile,
                child: const Text('Load Shapefile'),
              ),
              ElevatedButton(
                onPressed: _loadGeoPackage,
                child: const Text('Load GeoPackage'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadGeoJSON() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['geojson'],
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      final geoJsonHandler = GeoJSONHandler();
      await geoJsonHandler.parseGeoJSONFile(filePath);

      _updateMapWithFeatures(geoJsonHandler.features);
    }
  }

  Future<void> _loadShapefile() async {
    // Select .zip or .shp file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'shp'],
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;

      final shapefileHandler = ShapefileHandler();
      try {
        await shapefileHandler.readShapefile(filePath);

        _updateMapWithFeatures(shapefileHandler.features);
      } catch (e) {
        // Handle exceptions, e.g., show an error message
        print('Error loading shapefile: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load shapefile: $e')),
        );
      }
    }
  }

  Future<void> _loadGeoPackage() async {
    if (kIsWeb) {
      // GeoPackage (sqlite3 + dart:ffi) is not supported on web.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GeoPackage is not supported on Web')),
      );
      return;
    }

    // Select .gpkg file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpkg'],
    );

    if (result != null && result.files.single.path != null) {
      final gpkgPath = result.files.single.path!;
      final geoPackageHandler = GeoPackageHandler();
      try {
        geoPackageHandler.openGeoPackage(gpkgPath);
        geoPackageHandler.readFeatures();
        geoPackageHandler.closeGeoPackage();

        _updateMapWithFeatures(geoPackageHandler.features);
      } catch (e) {
        print('Error loading GeoPackage: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load GeoPackage: $e')),
        );
      }
    }
  }

  void _updateMapWithFeatures(List<GeoFeature> features) {
    List<Marker> markers = [];
    List<Polyline> polylines = [];
    List<Polygon> polygons = [];

    for (var feature in features) {
      if (feature.geometry is GeoPoint) {
        final point = (feature.geometry as GeoPoint).point;
        markers.add(
          Marker(
            point: point,
            width: 80.0,
            height: 80.0,
            child: const Icon(Icons.location_on, color: Colors.red),
          ),
        );
      } else if (feature.geometry is GeoLineString) {
        final points = (feature.geometry as GeoLineString).points;
        polylines.add(
          Polyline(
            points: points,
            strokeWidth: 4.0,
            color: Colors.blue,
          ),
        );
      } else if (feature.geometry is GeoPolygon) {
        final points = (feature.geometry as GeoPolygon).points;
        polygons.add(
          Polygon(
            points: points,
            borderStrokeWidth: 2.0,
            borderColor: Colors.green,
            color: Colors.green.withOpacity(0.2),
          ),
        );
      } else if (feature.geometry is GeoMultiPoint) {
        final multiPoint = feature.geometry as GeoMultiPoint;
        for (var point in multiPoint.points) {
          markers.add(
            Marker(
              point: point,
              width: 80.0,
              height: 80.0,
              child: const Icon(Icons.location_on, color: Colors.red),
            ),
          );
        }
      } else if (feature.geometry is GeoMultiLineString) {
        final multiLineString = feature.geometry as GeoMultiLineString;
        for (var lineString in multiLineString.lineStrings) {
          polylines.add(
            Polyline(
              points: lineString,
              strokeWidth: 4.0,
              color: Colors.blue,
            ),
          );
        }
      } else if (feature.geometry is GeoMultiPolygon) {
        final multiPolygon = feature.geometry as GeoMultiPolygon;
        for (var polygonPoints in multiPolygon.polygons) {
          polygons.add(
            Polygon(
              points: polygonPoints,
              borderStrokeWidth: 2.0,
              borderColor: Colors.green,
              color: Colors.green.withOpacity(0.2),
            ),
          );
        }
      }
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
      _polygons = polygons;

      // Adjust the map view to the first feature
      if (_markers.isNotEmpty) {
        _mapController.move(_markers.first.point, 10.0);
      } else if (_polylines.isNotEmpty) {
        _mapController.move(_polylines.first.points.first, 10.0);
      } else if (_polygons.isNotEmpty) {
        _mapController.move(_polygons.first.points.first, 10.0);
      }
    });
  }
}
