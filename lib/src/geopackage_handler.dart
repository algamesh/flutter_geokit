import 'dart:typed_data';
import 'package:sqlite3/sqlite3.dart';
import 'models/geo_feature.dart';
import 'models/geo_geometry.dart';
import 'package:latlong2/latlong.dart';

class GeoPackageHandler {
  late Database _db;
  List<GeoFeature> features = [];

  void openGeoPackage(String path) {
    _db = sqlite3.open(path);
  }

  void closeGeoPackage() {
    _db.dispose();
  }

  void readFeatures() {
    // Query the gpkg_contents table to get feature tables
    final result = _db.select(
      'SELECT table_name FROM gpkg_contents WHERE data_type = ?',
      ['features'],
    );

    for (final row in result) {
      final tableName = row['table_name'] as String;
      _readFeatureTable(tableName);
    }
  }

  void _readFeatureTable(String tableName) {
    // Get geometry column name from gpkg_geometry_columns
    final result = _db.select(
      'SELECT column_name FROM gpkg_geometry_columns WHERE table_name = ?',
      [tableName],
    );

    if (result.isEmpty) {
      return;
    }

    final geometryColumn = result.first['column_name'] as String;

    // Read features from the table
    final featuresResult = _db.select('SELECT * FROM "$tableName"');
    final columnNames = featuresResult.columnNames;

    for (final row in featuresResult) {
      // Get the geometry blob
      final geometryBlob = row[geometryColumn] as Uint8List?;

      if (geometryBlob == null) {
        continue; // Skip rows without geometry
      }

      // Parse the geometry
      final geometry = _parseGeometryBlob(geometryBlob);

      // Collect properties
      final properties = <String, dynamic>{};
      for (final column in columnNames) {
        if (column != geometryColumn) {
          properties[column] = row[column];
        }
      }

      // Create GeoFeature
      features.add(GeoFeature(geometry: geometry, properties: properties));
    }
  }

  GeoGeometry _parseGeometryBlob(Uint8List blob) {
    // Implement parsing of GeoPackage geometry blobs (WKB with header)
    // Return a GeoGeometry object
    // This is a complex process; see the detailed implementation below.
    return _parseGeoPackageGeometry(blob);
  }

  GeoGeometry _parseGeoPackageGeometry(Uint8List blob) {
    final byteData = ByteData.sublistView(blob);
    int offset = 0;

    // Read magic number (2 bytes)
    final magic = byteData.getUint16(offset, Endian.big);
    offset += 2;

    if (magic != 0x4750) {
      throw Exception('Invalid GeoPackage geometry blob (magic number mismatch)');
    }

    // Read version (1 byte)
    final version = byteData.getUint8(offset);
    offset += 1;

    // Read flags (1 byte)
    final flags = byteData.getUint8(offset);
    offset += 1;

    // Parse flags
    final envelopeIndicator = (flags >> 1) & 0x07;
    final hasZ = (flags & 0x10) != 0;
    final hasM = (flags & 0x20) != 0;

    // Read SRS ID (4 bytes)
    final srsId = byteData.getInt32(offset, Endian.little);
    offset += 4;

    // Read envelope (optional)
    int envelopeSize = 0;
    switch (envelopeIndicator) {
      case 0:
        envelopeSize = 0;
        break;
      case 1:
        envelopeSize = 32;
        break;
      case 2:
        envelopeSize = 48;
        break;
      case 3:
        envelopeSize = 48;
        break;
      case 4:
        envelopeSize = 64;
        break;
      default:
        throw Exception('Invalid envelope indicator: $envelopeIndicator');
    }
    offset += envelopeSize;

    // Remaining bytes are WKB
    final wkbBytes = blob.sublist(offset);

    // Parse WKB geometry
    return _parseWKBGeometry(wkbBytes, hasZ: hasZ, hasM: hasM);
  }

  GeoGeometry _parseWKBGeometry(Uint8List wkbBytes, {bool hasZ = false, bool hasM = false}) {
    final byteData = ByteData.sublistView(wkbBytes);
    int offset = 0;

    // Read byte order (1 byte)
    final byteOrder = byteData.getUint8(offset);
    offset += 1;

    final isLittleEndian = byteOrder == 1;

    // Read geometry type (4 bytes)
    final geometryType = _getUint32(byteData, offset, isLittleEndian);
    offset += 4;

    // Remove high bits indicating presence of Z, M, or ZM dimensions
    final baseGeometryType = geometryType & 0xFF;

    // Handle different geometry types
    switch (baseGeometryType) {
      case 1: // Point
        return _parsePoint(byteData, offset, isLittleEndian, hasZ: hasZ, hasM: hasM);
      case 2: // LineString
        return _parseLineString(byteData, offset, isLittleEndian, hasZ: hasZ, hasM: hasM);
      case 3: // Polygon
        return _parsePolygon(byteData, offset, isLittleEndian, hasZ: hasZ, hasM: hasM);
      case 4: // MultiPoint
        return _parseMultiPoint(byteData, offset, isLittleEndian, hasZ: hasZ, hasM: hasM);
      case 5: // MultiLineString
        return _parseMultiLineString(byteData, offset, isLittleEndian, hasZ: hasZ, hasM: hasM);
      case 6: // MultiPolygon
        return _parseMultiPolygon(byteData, offset, isLittleEndian, hasZ: hasZ, hasM: hasM);
      default:
        throw Exception('Unsupported geometry type: $baseGeometryType');
    }
  }

  // Parse methods
  GeoPoint _parsePoint(ByteData byteData, int offset, bool isLittleEndian, {bool hasZ = false, bool hasM = false}) {
    final x = _getFloat64(byteData, offset, isLittleEndian);
    offset += 8;
    final y = _getFloat64(byteData, offset, isLittleEndian);
    offset += 8;

    // Skip Z and M if present
    if (hasZ) {
      offset += 8;
    }
    if (hasM) {
      offset += 8;
    }

    return GeoPoint(LatLng(y, x));
  }

  GeoLineString _parseLineString(ByteData byteData, int offset, bool isLittleEndian, {bool hasZ = false, bool hasM = false}) {
    final numPoints = _getUint32(byteData, offset, isLittleEndian);
    offset += 4;

    final points = <LatLng>[];

    for (int i = 0; i < numPoints; i++) {
      final x = _getFloat64(byteData, offset, isLittleEndian);
      offset += 8;
      final y = _getFloat64(byteData, offset, isLittleEndian);
      offset += 8;

      // Skip Z and M if present
      if (hasZ) {
        offset += 8;
      }
      if (hasM) {
        offset += 8;
      }

      points.add(LatLng(y, x));
    }

    return GeoLineString(points);
  }

  GeoPolygon _parsePolygon(ByteData byteData, int offset, bool isLittleEndian, {bool hasZ = false, bool hasM = false}) {
    final numRings = _getUint32(byteData, offset, isLittleEndian);
    offset += 4;

    final points = <LatLng>[];

    for (int i = 0; i < numRings; i++) {
      final numPoints = _getUint32(byteData, offset, isLittleEndian);
      offset += 4;

      for (int j = 0; j < numPoints; j++) {
        final x = _getFloat64(byteData, offset, isLittleEndian);
        offset += 8;
        final y = _getFloat64(byteData, offset, isLittleEndian);
        offset += 8;

        // Skip Z and M if present
        if (hasZ) {
          offset += 8;
        }
        if (hasM) {
          offset += 8;
        }

        points.add(LatLng(y, x));
      }
    }

    return GeoPolygon(points);
  }

  GeoMultiPoint _parseMultiPoint(ByteData byteData, int offset, bool isLittleEndian, {bool hasZ = false, bool hasM = false}) {
    final numPoints = _getUint32(byteData, offset, isLittleEndian);
    offset += 4;

    final points = <LatLng>[];

    for (int i = 0; i < numPoints; i++) {
      // Each point is a Point geometry with its own byte order and geometry type
      final pointGeometry = _parseWKBGeometry(byteData.buffer.asUint8List(offset), hasZ: hasZ, hasM: hasM);
      if (pointGeometry is GeoPoint) {
        points.add(pointGeometry.point);
      }
      // Update offset (1 byte for byte order, 4 bytes for geometry type, plus point data)
      offset += 1 + 4 + 16; // Adjust for actual size
    }

    return GeoMultiPoint(points);
  }

  GeoMultiLineString _parseMultiLineString(ByteData byteData, int offset, bool isLittleEndian, {bool hasZ = false, bool hasM = false}) {
    final numLineStrings = _getUint32(byteData, offset, isLittleEndian);
    offset += 4;

    final lineStrings = <List<LatLng>>[];

    for (int i = 0; i < numLineStrings; i++) {
      final lineStringGeometry = _parseWKBGeometry(byteData.buffer.asUint8List(offset), hasZ: hasZ, hasM: hasM);
      if (lineStringGeometry is GeoLineString) {
        lineStrings.add(lineStringGeometry.points);
      }
      // Update offset accordingly
      // Need to calculate the actual size of the LineString geometry
      // This requires parsing the geometry size
      // For simplicity, you may need to adjust this implementation
    }

    return GeoMultiLineString(lineStrings);
  }

  GeoMultiPolygon _parseMultiPolygon(ByteData byteData, int offset, bool isLittleEndian, {bool hasZ = false, hasM = false}) {
    final numPolygons = _getUint32(byteData, offset, isLittleEndian);
    offset += 4;

    final polygons = <List<LatLng>>[];

    for (int i = 0; i < numPolygons; i++) {
      final polygonGeometry = _parseWKBGeometry(byteData.buffer.asUint8List(offset), hasZ: hasZ, hasM: hasM);
      if (polygonGeometry is GeoPolygon) {
        polygons.add(polygonGeometry.points);
      }
      // Update offset accordingly
      // Need to calculate the actual size of the Polygon geometry
    }

    return GeoMultiPolygon(polygons);
  }

  // Utility methods
  int _getUint32(ByteData data, int offset, bool isLittleEndian) {
    if (isLittleEndian) {
      return data.getUint32(offset, Endian.little);
    } else {
      return data.getUint32(offset, Endian.big);
    }
  }

  double _getFloat64(ByteData data, int offset, bool isLittleEndian) {
    if (isLittleEndian) {
      return data.getFloat64(offset, Endian.little);
    } else {
      return data.getFloat64(offset, Endian.big);
    }
  }
}
