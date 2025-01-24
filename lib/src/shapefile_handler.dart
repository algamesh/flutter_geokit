import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'models/geo_feature.dart';
import 'models/geo_geometry.dart';

class ShapefileHandler {
  List<GeoFeature> features = [];

  Future<void> readShapefile(String path) async {
    String shpPath;
    String dbfPath;

    // Check if the path is a ZIP file
    if (p.extension(path).toLowerCase() == '.zip') {
      // Extract the ZIP file
      final tempDir = await _extractZipFile(path);
      // Find the .shp and .dbf files in the extracted directory
      shpPath = _findFileInDirectory(tempDir.path, '.shp')!;
      dbfPath = _findFileInDirectory(tempDir.path, '.dbf')!;
    } else {
      // Assume the path is a directory containing .shp and .dbf files
      shpPath = _findFileInDirectory(path, '.shp')!;
      dbfPath = _findFileInDirectory(path, '.dbf')!;
    }

    // Read the files
    final shpFile = File(shpPath);
    final dbfFile = File(dbfPath);

    final shpBytes = await shpFile.readAsBytes();
    final dbfBytes = await dbfFile.readAsBytes();

    final shpGeometries = _parseShpFile(shpBytes);
    final dbfAttributes = _parseDbfFile(dbfBytes);

    for (int i = 0; i < shpGeometries.length; i++) {
      features.add(GeoFeature(
        geometry: shpGeometries[i],
        properties: dbfAttributes[i],
      ));
    }
  }

  Future<Directory> _extractZipFile(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final tempDir = await Directory.systemTemp.createTemp();

    for (final file in archive) {
      final filename = file.name;
      final filePath = p.join(tempDir.path, filename);

      if (file.isFile) {
        final data = file.content as List<int>;
        await File(filePath).writeAsBytes(data);
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }

    return tempDir;
  }

  String? _findFileInDirectory(String dirPath, String extension) {
    final dir = Directory(dirPath);
    final files = dir.listSync(recursive: true);

    for (final file in files) {
      if (file is File && p.extension(file.path).toLowerCase() == extension) {
        return file.path;
      }
    }
    return null;
  }

  List<GeoGeometry> _parseShpFile(Uint8List bytes) {
    final geometries = <GeoGeometry>[];
    final byteData = ByteData.view(bytes.buffer);

    // Skip the header (100 bytes)
    int offset = 100;

    while (offset < bytes.length) {
      // Read record header
      final recordNumber = byteData.getUint32(offset, Endian.big);
      final contentLength = byteData.getUint32(offset + 4, Endian.big);
      offset += 8;

      // Read shape type
      final shapeType = byteData.getUint32(offset, Endian.little);
      offset += 4;

      switch (shapeType) {
        case 1: // Point
          final x = byteData.getFloat64(offset, Endian.little);
          final y = byteData.getFloat64(offset + 8, Endian.little);
          geometries.add(GeoPoint(LatLng(y, x)));
          offset += 16;
          break;
        case 3: // PolyLine
        case 5: // Polygon
          // Read bounding box
          offset += 32;

          final numParts = byteData.getUint32(offset, Endian.little);
          final numPoints = byteData.getUint32(offset + 4, Endian.little);
          offset += 8;

          // Read parts
          final parts = List<int>.generate(numParts, (i) {
            return byteData.getUint32(offset + (i * 4), Endian.little);
          });
          offset += numParts * 4;

          // Read points
          final points = List<LatLng>.generate(numPoints, (i) {
            final x = byteData.getFloat64(offset + (i * 16), Endian.little);
            final y = byteData.getFloat64(offset + (i * 16) + 8, Endian.little);
            return LatLng(y, x);
          });
          offset += numPoints * 16;

          if (shapeType == 3) {
            geometries.add(GeoLineString(points));
          } else {
            geometries.add(GeoPolygon(points));
          }
          break;
        default:
          print('Unsupported shape type: $shapeType');
          offset += contentLength * 2 - 4;
      }
    }

    return geometries;
  }

  List<Map<String, dynamic>> _parseDbfFile(Uint8List bytes) {
    final attributes = <Map<String, dynamic>>[];
    final byteData = ByteData.view(bytes.buffer);

    // Parse DBF header
    final numRecords = byteData.getUint32(4, Endian.little);
    final headerLength = byteData.getUint16(8, Endian.little);
    final recordLength = byteData.getUint16(10, Endian.little);

    // Parse field descriptors
    final fields = <String>[];
    int fieldOffset = 32;
    while (bytes[fieldOffset] != 0x0D) {
      final fieldNameBytes = bytes.sublist(fieldOffset, fieldOffset + 11);
      final fieldName = String.fromCharCodes(fieldNameBytes).trim();
      fields.add(fieldName);
      fieldOffset += 32;
    }

    // Parse records
    int offset = headerLength;
    for (int i = 0; i < numRecords; i++) {
      final record = <String, dynamic>{};
      offset++; // Skip the deletion flag
      for (final field in fields) {
        final valueBytes = bytes.sublist(offset, offset + 10);
        final value = String.fromCharCodes(valueBytes).trim();
        record[field] = value;
        offset += 10; // Assuming field length of 10 bytes
      }
      attributes.add(record);
    }

    return attributes;
  }

  Future<void> writeShapefile(String shpPath, String dbfPath) async {
    // Implement shapefile writing logic
    // Writing shapefiles involves creating the .shp, .shx, and .dbf files
    // This implementation focuses on the .shp file
    final shpFile = File(shpPath);
    final shpBytes = _createShpFile();
    await shpFile.writeAsBytes(shpBytes);

    final dbfFile = File(dbfPath);
    final dbfBytes = _createDbfFile();
    await dbfFile.writeAsBytes(dbfBytes);
  }
  
  Uint8List _createShpFile() {
    final bytesBuilder = BytesBuilder();

    // Add file header (100 bytes)
    final header = ByteData(100);
    // Set file code
    header.setUint32(0, 9994, Endian.big);
    // Unused bytes
    for (int i = 4; i < 24; i += 4) {
      header.setUint32(i, 0, Endian.big);
    }
    // Set file length (to be updated later)
    header.setUint32(24, 0, Endian.big);
    // Set version
    header.setUint32(28, 1000, Endian.little);
    // Set shape type (assuming all features are of the same type)
    int shapeType = _getShapeType(features.first.geometry);
    header.setUint32(32, shapeType, Endian.little);
    // Set bounding box (xmin, ymin, xmax, ymax)
    // For simplicity, set all to zero
    for (int i = 36; i < 68; i += 8) {
      header.setFloat64(i, 0.0, Endian.little);
    }
    // Unused bytes for Z and M
    for (int i = 68; i < 100; i += 8) {
      header.setFloat64(i, 0.0, Endian.little);
    }

    bytesBuilder.add(header.buffer.asUint8List());

    // Add records
    int recordNumber = 1;
    for (final feature in features) {
      final record = _createShpRecord(recordNumber, feature.geometry);
      bytesBuilder.add(record);
      recordNumber++;
    }

    // Update file length in header
    final totalLength = bytesBuilder.length ~/ 2; // Corrected from lengthInBytes
    final allBytes = bytesBuilder.toBytes();
    final headerBytes = allBytes.sublist(0, 100);
    final headerData = ByteData.sublistView(headerBytes);

    headerData.setUint32(24, totalLength, Endian.big);

    // Replace the header in the byte array
    final updatedBytes = Uint8List.fromList(allBytes);
    updatedBytes.setRange(0, 100, headerData.buffer.asUint8List());

    return updatedBytes;
  }

  int _getShapeType(GeoGeometry geometry) {
    if (geometry is GeoPoint) {
      return 1;
    } else if (geometry is GeoLineString) {
      return 3;
    } else if (geometry is GeoPolygon) {
      return 5;
    } else {
      throw UnimplementedError('Unsupported geometry type');
    }
  }

  Uint8List _createShpRecord(int recordNumber, GeoGeometry geometry) {
    final bytesBuilder = BytesBuilder();

    final recordHeader = ByteData(8);
    recordHeader.setUint32(0, recordNumber, Endian.big);
    // Content length (to be updated later)
    recordHeader.setUint32(4, 0, Endian.big);
    bytesBuilder.add(recordHeader.buffer.asUint8List());

    final contentBytesBuilder = BytesBuilder();
    final contentData = ByteData(4);
    final shapeType = _getShapeType(geometry);
    contentData.setUint32(0, shapeType, Endian.little);
    contentBytesBuilder.add(contentData.buffer.asUint8List());

    // Add geometry data
    if (geometry is GeoPoint) {
      final pointData = ByteData(16);
      pointData.setFloat64(0, geometry.point.longitude, Endian.little);
      pointData.setFloat64(8, geometry.point.latitude, Endian.little);
      contentBytesBuilder.add(pointData.buffer.asUint8List());
    } else {
      // Implement handling for other geometry types
      throw UnimplementedError('Geometry writing not fully implemented');
    }

    // Update content length
    final contentLength = contentBytesBuilder.length ~/ 2;
    final recordHeaderData = ByteData.sublistView(bytesBuilder.toBytes());
    recordHeaderData.setUint32(4, contentLength, Endian.big);

    bytesBuilder.add(contentBytesBuilder.toBytes());

    return bytesBuilder.toBytes();
  }

  Uint8List _createDbfFile() {
    // Implement .dbf file creation logic
    // This is a simplified example and may need to be expanded
    final bytesBuilder = BytesBuilder();

    // Header
    final header = ByteData(32);
    header.setUint8(0, 0x03); // File type
    // Number of records
    header.setUint32(4, features.length, Endian.little);
    // Header length
    final headerLength = 32 + (features.first.properties.length * 32) + 1;
    header.setUint16(8, headerLength, Endian.little);
    // Record length
    final recordLength = features.first.properties.length * 10 + 1;
    header.setUint16(10, recordLength, Endian.little);

    bytesBuilder.add(header.buffer.asUint8List());

    // Field descriptors
    for (final field in features.first.properties.keys) {
      final fieldDesc = ByteData(32);
      final fieldNameBytes = field.padRight(11).codeUnits;
      fieldDesc.buffer.asUint8List().setRange(0, 11, fieldNameBytes);
      fieldDesc.setUint8(11, 0x43); // Field type 'C' for character
      fieldDesc.setUint8(16, 10); // Field length
      bytesBuilder.add(fieldDesc.buffer.asUint8List());
    }

    bytesBuilder.addByte(0x0D); // Header terminator

    // Records
    for (final feature in features) {
      bytesBuilder.addByte(0x20); // Deletion flag
      for (final value in feature.properties.values) {
        final valueStr = value.toString().padRight(10).substring(0, 10);
        bytesBuilder.add(valueStr.codeUnits);
      }
    }

    return bytesBuilder.toBytes();
  }

  void addFeature(GeoFeature feature) {
    features.add(feature);
  }

  void removeFeature(GeoFeature feature) {
    features.remove(feature);
  }
}
