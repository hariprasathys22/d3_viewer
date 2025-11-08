// lib/readers/case_reader.dart

import 'dart:io';
import '../models/openfoam_case.dart';
import '../parsers/foam_file_parser.dart';
import '../utils/field_interpolation.dart';
import '../utils/file_utils.dart';
import 'mesh_reader.dart';

class CaseReader {
  // Helper method to read and check file format
  static Future<Map<String, String>> getFileFormats(String casePath) async {
    final formats = <String, String>{};

    // Check controlDict (supports .gz)
    try {
      final controlDictPath = '$casePath/system/controlDict';
      if (await FileUtils.fileExists(controlDictPath)) {
        final content = await FileUtils.readFileAsString(controlDictPath);
        final header = FoamFileParser.parseFoamFileHeader(content);
        formats['controlDict'] = header['format'] ?? 'unknown';
      }
    } catch (e) {
      formats['controlDict'] = 'error';
    }

    // Check mesh files format (supports .gz)
    try {
      final pointsPath = '$casePath/constant/polyMesh/points';
      if (await FileUtils.fileExists(pointsPath)) {
        final bytes = await FileUtils.readFileBytes(pointsPath);
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
    // Use FileUtils to get all files (handles .gz automatically)
    final fields = await FileUtils.listFiles('$casePath/$timeDir');
    final validFields = <String>[];

    for (final name in fields) {
      // Skip uniform directory and other non-field files
      if (name == 'uniform' || name.startsWith('.')) continue;

      // Check if it's a valid OpenFOAM field file
      try {
        final content = await FileUtils.readFileAsString('$casePath/$timeDir/$name');
        if (content.contains('FoamFile')) {
          validFields.add(name);
        }
      } catch (e) {
        // Skip files that can't be read
        print('Skipping $name: $e');
      }
    }

    validFields.sort();
    return validFields;
  }

  // Load scalar field data from a time directory
  static Future<FieldData?> loadFieldData(
    String casePath,
    String timeDir,
    String fieldName,
    PolyMesh mesh,
  ) async {
    final fieldPath = '$casePath/$timeDir/$fieldName';

    if (!await FileUtils.fileExists(fieldPath)) {
      print('Field file not found: $fieldPath (also tried .gz)');
      return null;
    }

    try {
      final content = await FileUtils.readFileAsString(fieldPath);

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
