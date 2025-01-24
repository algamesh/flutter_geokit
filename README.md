# flutter_geokit

`flutter_geokit` is a Flutter package that provides tools to handle various geospatial data formats such as GeoJSON, Shapefiles, and GeoPackage. It also supports integration with Flutter's `flutter_map` for map visualization.

## Features

- **GeoJSON Support**: Read, parse, and convert GeoJSON data.
- **Shapefile Support**: Read, parse, and convert Shapefiles (.shp, .dbf).
- **GeoPackage Support**: Read, parse, and convert GeoPackage (.gpkg) files.
- **Data Conversion**: Convert between GeoJSON, Shapefile, and GeoPackage formats.
- **Map Visualization**: Integrate with `flutter_map` to visualize geospatial data.

## Getting Started

To use this package, add `flutter_geokit` as a dependency in your `pubspec.yaml`:

```yaml
dependencies:
  flutter_geokit:
    git:
      url: https://github.com/algamesh/flutter_geokit.git
      ref: main
```

### Example Usage

```dart
import 'package:flutter_geokit/flutter_geokit.dart';

void main() {
  final geoJsonHandler = GeoJSONHandler();
  geoJsonHandler.parseGeoJSONFile('path/to/geojson/file');
  
  // Visualize on flutter_map
}
```

## Installation

1. Add `flutter_geokit` to your `pubspec.yaml` dependencies.
2. Run `flutter pub get` to install the package.

## Documentation

For full documentation, please visit the [GitHub repository](https://github.com/algamesh/flutter_geokit).

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/algamesh/flutter_geokit/blob/main/LICENSE) file for details.
