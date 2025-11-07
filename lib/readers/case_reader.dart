// lib/readers/case_reader.dart

import 'dart:io';
import 'dart:convert';
import '../models/openfoam_case.dart';
import '../parsers/foam_file_parser.dart';
import '../utils/field_interpolation.dart';
import 'mesh_reader.dart';

class CaseReader {
  // Helper method to read and check file format
  static Future<Map<String, String>> getFileFormats(String casePath) async {
    final formats = <String, String>{};

    // Check controlDict
    try {
      final controlDictFile = File('$casePath/system/controlDict');
      if (await controlDictFile.exists()) {
        final content = await controlDictFile.readAsString();
        final header = FoamFileParser.parseFoamFileHeader(content);
        formats['controlDict'] = header['format'] ?? 'unknown';
      }
    } catch (e) {
      formats['controlDict'] = 'error';
    }

    // Check mesh files format
    try {
      final pointsFile = File('$casePath/constant/polyMesh/points');
      if (await pointsFile.exists()) {
        final bytes = await pointsFile.readAsBytes();
        final header = FoamFileParser.parseFoamFileHeaderFromBytes(bytes);
        formats['mesh'] = header['format'] ?? 'unknown';
      }
    } catch (e) {
      formats['mesh'] = 'error';
    }

    return formats;
  }

  static Future<OpenFOAMCase> readCase(String foamFilePath) async {
    // Get case directory (parent of .foam file)
    final casePath = File(foamFilePath).parent.path;

    print('Reading OpenFOAM case from: $casePath');

    // Check file formats
    final formats = await getFileFormats(casePath);
    print('File formats detected:');
    formats.forEach((key, value) {
      print('  $key: $value');
    });

    // Read mesh
    final mesh = await MeshReader.readMesh(casePath);

    // Find time directories
    final timeDirectories = await _findTimeDirectories(casePath);

    print('Time directories found: $timeDirectories');

    // Read fields (you can extend this)
    final fields = <String, FieldData>{};

    return OpenFOAMCase(
      casePath: casePath,
      mesh: mesh,
      fields: fields,
      timeDirectories: timeDirectories,
    );
  }

  static Future<List<String>> _findTimeDirectories(String casePath) async {
    final dir = Directory(casePath);
    final timeDirectories = <String>[];

    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        // Check if directory name is a number (time step)
        if (double.tryParse(name) != null) {
          timeDirectories.add(name);
        }
      }
    }

    // Sort numerically
    timeDirectories.sort((a, b) => double.parse(a).compareTo(double.parse(b)));

    return timeDirectories;
  }

  // Find available scalar fields in a time directory
  static Future<List<String>> getAvailableFields(
    String casePath,
    String timeDir,
  ) async {
    final fields = <String>[];
    final timeDirectory = Directory('$casePath/$timeDir');

    if (!await timeDirectory.exists()) {
      return fields;
    }

    await for (final entity in timeDirectory.list()) {
      if (entity is File) {
        final name = entity.path.split(Platform.pathSeparator).last;
        // Skip uniform directory and other non-field files
        if (name != 'uniform' && !name.startsWith('.')) {
          // Check if it's a valid OpenFOAM field file
          try {
            final content = await entity.readAsString(encoding: utf8);
            if (content.contains('FoamFile')) {
              fields.add(name);
            }
          } catch (e) {
            // Skip files that can't be read
          }
        }
      }
    }

    fields.sort();
    return fields;
  }

  // Load scalar field data from a time directory
  static Future<FieldData?> loadFieldData(
    String casePath,
    String timeDir,
    String fieldName,
    PolyMesh mesh,
  ) async {
    final fieldFile = File('$casePath/$timeDir/$fieldName');

    if (!await fieldFile.exists()) {
      print('Field file not found: ${fieldFile.path}');
      return null;
    }

    try {
      final content = await fieldFile.readAsString();

      // Parse the field header to check field type
      final header = FoamFileParser.parseFoamFileHeader(content);
      final fieldClass = header['class'] ?? '';

      if (!fieldClass.contains('ScalarField') &&
          !fieldClass.contains('VectorField')) {
        print(
          'Field $fieldName is not a scalar or vector field (class: $fieldClass)',
        );
        return null;
      }

      // Parse the field values (handles both scalar and vector fields)
      final values = FoamFileParser.parseScalarField(content);

      if (values.isEmpty) {
        print('No values found in field $fieldName');
        return null;
      }

      print('Loaded $fieldName: ${values.length} cell values');

      // Convert cell data to point data for smooth gradients
      final pointValues = FieldInterpolation.cellToPoint(values, mesh);
      print('Interpolated to ${pointValues.length} point values');

      return FieldData(
        name: fieldName,
        fieldClass: fieldClass,
        internalField: values,
        boundaryField: {},
        pointValues: pointValues,
      );
    } catch (e) {
      print('Error loading field $fieldName: $e');
      return null;
    }
  }
}
