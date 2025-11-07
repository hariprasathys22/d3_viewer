// lib/parsers/foam_file_parser.dart

import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import '../models/openfoam_case.dart';

class FoamFileParser {
  // Find where header ends and data begins
  static int _findDataStart(List<int> bytes) {
    final content = utf8.decode(
      bytes.sublist(0, bytes.length < 3000 ? bytes.length : 3000),
      allowMalformed: true,
    );

    // Find the end of header (after the closing brace and newline)
    int braceCount = 0;
    bool inHeader = false;

    for (int i = 0; i < content.length; i++) {
      if (content[i] == '{') {
        if (!inHeader &&
            i > 0 &&
            content.substring(0, i).contains('FoamFile')) {
          inHeader = true;
        }
        braceCount++;
      } else if (content[i] == '}') {
        braceCount--;
        if (inHeader && braceCount == 0) {
          // Found end of FoamFile header, skip to next non-whitespace
          for (int j = i + 1; j < content.length; j++) {
            if (content[j] == '\n' || content[j] == '\r') continue;
            if (content[j] != ' ' && content[j] != '\t') {
              return j;
            }
          }
        }
      }
    }
    return 1000; // Default fallback
  }

  // Parse binary vector list (points)
  static List<Vector3> parseBinaryVectorList(List<int> bytes) {
    final dataStart = _findDataStart(bytes);
    final data = bytes.sublist(dataStart);

    // Try to read count - it should be ASCII before the opening parenthesis
    String textPart = '';
    int textEnd = 0;

    // Read up to 100 bytes as text to find the count
    for (int i = 0; i < 100 && i < data.length; i++) {
      if (data[i] == 0x28) {
        // '(' marks start of binary data
        textEnd = i;
        break;
      }
    }

    if (textEnd > 0) {
      textPart = utf8
          .decode(data.sublist(0, textEnd), allowMalformed: true)
          .trim();
    }

    // Extract the number from the text
    final numberMatch = RegExp(r'(\d+)').firstMatch(textPart);
    if (numberMatch == null) {
      throw Exception('Could not find count in binary file header');
    }

    final count = int.parse(numberMatch.group(1)!);
    print('Reading $count binary vectors...');

    // Binary data starts right after the '('
    int binaryStart = textEnd + 1;

    // Skip any whitespace/newlines after '('
    while (binaryStart < data.length &&
        (data[binaryStart] == 0x0A ||
            data[binaryStart] == 0x0D ||
            data[binaryStart] == 0x20 ||
            data[binaryStart] == 0x09)) {
      binaryStart++;
    }

    final vectors = <Vector3>[];
    final byteData = ByteData.sublistView(
      Uint8List.fromList(data.sublist(binaryStart)),
    );

    // Each vector is 3 doubles (24 bytes)
    for (int i = 0; i < count && (i * 24 + 24) <= byteData.lengthInBytes; i++) {
      final x = byteData.getFloat64(i * 24, Endian.little);
      final y = byteData.getFloat64(i * 24 + 8, Endian.little);
      final z = byteData.getFloat64(i * 24 + 16, Endian.little);
      vectors.add(Vector3(x, y, z));
    }

    print('Parsed ${vectors.length} binary vectors');
    return vectors;
  }

  // Parse binary integer list (owner, neighbour)
  static List<int> parseBinaryIntList(List<int> bytes) {
    final dataStart = _findDataStart(bytes);
    final data = bytes.sublist(dataStart);

    // Try to read count
    String textPart = '';
    int textEnd = 0;

    for (int i = 0; i < 100 && i < data.length; i++) {
      if (data[i] == 0x28) {
        textEnd = i;
        break;
      }
    }

    if (textEnd > 0) {
      textPart = utf8
          .decode(data.sublist(0, textEnd), allowMalformed: true)
          .trim();
    }

    final numberMatch = RegExp(r'(\d+)').firstMatch(textPart);
    if (numberMatch == null) {
      throw Exception('Could not find count in binary file header');
    }

    final count = int.parse(numberMatch.group(1)!);
    print('Reading $count binary integers...');

    // Binary data starts right after the '('
    int binaryStart = textEnd + 1;

    while (binaryStart < data.length &&
        (data[binaryStart] == 0x0A ||
            data[binaryStart] == 0x0D ||
            data[binaryStart] == 0x20 ||
            data[binaryStart] == 0x09)) {
      binaryStart++;
    }

    final ints = <int>[];
    final byteData = ByteData.sublistView(
      Uint8List.fromList(data.sublist(binaryStart)),
    );

    // Each int is 4 bytes
    for (int i = 0; i < count && (i * 4 + 4) <= byteData.lengthInBytes; i++) {
      final value = byteData.getInt32(i * 4, Endian.little);
      ints.add(value);
    }

    print('Parsed ${ints.length} binary integers');
    return ints;
  }

  // Parse binary faces
  static List<Face> parseBinaryFaces(List<int> bytes) {
    final dataStart = _findDataStart(bytes);
    final data = bytes.sublist(dataStart);

    // Try to read count
    String textPart = '';
    int textEnd = 0;

    for (int i = 0; i < 100 && i < data.length; i++) {
      if (data[i] == 0x28) {
        textEnd = i;
        break;
      }
    }

    if (textEnd > 0) {
      textPart = utf8
          .decode(data.sublist(0, textEnd), allowMalformed: true)
          .trim();
    }

    final numberMatch = RegExp(r'(\d+)').firstMatch(textPart);
    if (numberMatch == null) {
      throw Exception('Could not find count in binary file header');
    }

    final count = int.parse(numberMatch.group(1)!);
    print('Reading $count binary faces...');

    // Binary data starts right after the '('
    int binaryStart = textEnd + 1;

    while (binaryStart < data.length &&
        (data[binaryStart] == 0x0A ||
            data[binaryStart] == 0x0D ||
            data[binaryStart] == 0x20 ||
            data[binaryStart] == 0x09)) {
      binaryStart++;
    }

    final faces = <Face>[];
    final byteData = ByteData.sublistView(
      Uint8List.fromList(data.sublist(binaryStart)),
    );

    int offset = 0;
    // Binary face format: [nPoints, point1, point2, ..., pointN]
    for (int i = 0; i < count && offset < byteData.lengthInBytes; i++) {
      final nPoints = byteData.getInt32(offset, Endian.little);
      offset += 4;

      final pointIndices = <int>[];
      for (int j = 0; j < nPoints && offset < byteData.lengthInBytes; j++) {
        pointIndices.add(byteData.getInt32(offset, Endian.little));
        offset += 4;
      }

      faces.add(Face(pointIndices));
    }

    print('Parsed ${faces.length} binary faces');
    return faces;
  }

  // Check if file is binary format by reading header
  static bool isBinaryFormat(List<int> bytes) {
    try {
      // Read first part as ASCII to check header
      String headerSection = '';

      for (int i = 500; i < 2000 && i < bytes.length; i++) {
        headerSection = utf8.decode(bytes.sublist(0, i), allowMalformed: true);
        if (headerSection.contains('format') && headerSection.contains('}')) {
          break;
        }
      }

      final formatMatch = RegExp(r'format\s+(\w+);').firstMatch(headerSection);
      if (formatMatch != null) {
        return formatMatch.group(1)!.trim() == 'binary';
      }
    } catch (e) {
      print('Error checking binary format: $e');
    }
    return false;
  }

  // Parse FoamFile header from bytes
  static Map<String, dynamic> parseFoamFileHeaderFromBytes(List<int> bytes) {
    // Read first 2000 bytes as header
    final headerBytes = bytes.sublist(
      0,
      bytes.length < 2000 ? bytes.length : 2000,
    );
    final content = utf8.decode(headerBytes, allowMalformed: true);
    return parseFoamFileHeader(content);
  }

  // Parse FoamFile header
  static Map<String, dynamic> parseFoamFileHeader(String content) {
    final headerRegex = RegExp(
      r'FoamFile\s*\{([^}]+)\}',
      multiLine: true,
      dotAll: true,
    );

    final match = headerRegex.firstMatch(content);
    if (match == null) {
      throw Exception('No FoamFile header found');
    }

    final headerContent = match.group(1)!;
    final header = <String, dynamic>{};

    // Parse key-value pairs
    final kvRegex = RegExp(r'(\w+)\s+([^;]+);');
    for (final kvMatch in kvRegex.allMatches(headerContent)) {
      final key = kvMatch.group(1)!.trim();
      final value = kvMatch.group(2)!.trim().replaceAll('"', '');
      header[key] = value;
    }

    return header;
  }

  // Remove comments and header
  static String stripCommentsAndHeader(String content) {
    // Remove C++ style comments
    content = content.replaceAll(RegExp(r'//.*$', multiLine: true), '');
    content = content.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

    // Remove FoamFile header
    content = content.replaceAll(
      RegExp(r'FoamFile\s*\{[^}]+\}', multiLine: true, dotAll: true),
      '',
    );

    return content.trim();
  }

  // Parse list data (vectors, scalars, etc.)
  static List<dynamic> parseListData(String content) {
    content = stripCommentsAndHeader(content);

    // Find the number and list - use a more flexible regex
    // Format: number ( data )
    final listRegex = RegExp(r'(\d+)\s*\((.*)\)', dotAll: true);
    final match = listRegex.firstMatch(content);

    if (match == null) {
      throw Exception(
        'Invalid list format - could not find pattern "N ( data )"',
      );
    }

    final count = int.parse(match.group(1)!);
    final listContent = match.group(2)!.trim();

    print('Parsing list: $count items');

    // Check if it's a list of vectors or scalars
    if (listContent.contains('(')) {
      // Parse vectors
      final vectors = _parseVectorList(listContent);
      print('Parsed ${vectors.length} vectors');
      return vectors;
    } else {
      // Parse scalars (integers or floats)
      final scalars = _parseScalarList(listContent);
      print('Parsed ${scalars.length} scalars');
      // Convert to ints if they're whole numbers
      if (scalars.every((s) => s == s.toInt())) {
        return scalars.map((s) => s.toInt()).toList();
      }
      return scalars;
    }
  }

  static List<Vector3> _parseVectorList(String content) {
    final vectorRegex = RegExp(
      r'\(\s*([-\d.eE+]+)\s+([-\d.eE+]+)\s+([-\d.eE+]+)\s*\)',
    );
    final vectors = <Vector3>[];

    for (final match in vectorRegex.allMatches(content)) {
      vectors.add(
        Vector3(
          double.parse(match.group(1)!),
          double.parse(match.group(2)!),
          double.parse(match.group(3)!),
        ),
      );
    }

    return vectors;
  }

  static List<double> _parseScalarList(String content) {
    final numbers = content
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) {
          try {
            return double.parse(s);
          } catch (e) {
            print('Warning: Could not parse "$s" as number');
            return 0.0;
          }
        })
        .toList();
    return numbers;
  }

  // Parse scalar field (pressure, temperature, etc.)
  static List<double> parseScalarField(String content) {
    content = stripCommentsAndHeader(content);

    // Check if it's a vector field first
    if (content.contains('List<vector>')) {
      return parseVectorFieldMagnitude(content);
    }

    // Find internalField section
    final internalFieldRegex = RegExp(
      r'internalField\s+(?:nonuniform\s+)?List<scalar>\s*(\d+)\s*\((.*?)\)\s*;',
      dotAll: true,
      multiLine: true,
    );

    final match = internalFieldRegex.firstMatch(content);
    if (match == null) {
      // Try uniform field format: internalField uniform 0;
      final uniformRegex = RegExp(
        r'internalField\s+uniform\s+([-\d.eE+]+)\s*;',
      );
      final uniformMatch = uniformRegex.firstMatch(content);
      if (uniformMatch != null) {
        final value = double.parse(uniformMatch.group(1)!);
        print('Parsed uniform scalar field: $value');
        return [value]; // Return single value - caller needs to expand it
      }
      throw Exception('Could not find internalField in scalar field file');
    }

    final count = int.parse(match.group(1)!);
    final scalarContent = match.group(2)!.trim();

    print('Parsing scalar field: $count values');

    final values = scalarContent
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) {
          try {
            return double.parse(s);
          } catch (e) {
            print('Warning: Could not parse "$s" as scalar');
            return 0.0;
          }
        })
        .toList();

    print(
      'Parsed ${values.length} scalar values, min: ${values.reduce((a, b) => a < b ? a : b)}, max: ${values.reduce((a, b) => a > b ? a : b)}',
    );
    return values;
  }

  // Parse vector field and return magnitude
  static List<double> parseVectorFieldMagnitude(String content) {
    content = stripCommentsAndHeader(content);

    // Find internalField section with vectors
    final internalFieldRegex = RegExp(
      r'internalField\s+nonuniform\s+List<vector>\s*(\d+)\s*\((.*?)\)\s*;',
      dotAll: true,
      multiLine: true,
    );

    final match = internalFieldRegex.firstMatch(content);
    if (match == null) {
      throw Exception('Could not find vector internalField');
    }

    final count = int.parse(match.group(1)!);
    final vectorContent = match.group(2)!.trim();

    print('Parsing vector field: $count vectors');

    // Parse vectors in format (x y z)
    final vectorRegex = RegExp(
      r'\(\s*([-\d.eE+]+)\s+([-\d.eE+]+)\s+([-\d.eE+]+)\s*\)',
    );

    final magnitudes = <double>[];
    for (final vectorMatch in vectorRegex.allMatches(vectorContent)) {
      final x = double.parse(vectorMatch.group(1)!);
      final y = double.parse(vectorMatch.group(2)!);
      final z = double.parse(vectorMatch.group(3)!);

      // Calculate magnitude: sqrt(x^2 + y^2 + z^2)
      final magnitude = math.sqrt(x * x + y * y + z * z);
      magnitudes.add(magnitude);
    }

    print(
      'Parsed ${magnitudes.length} vector magnitudes, min: ${magnitudes.reduce((a, b) => a < b ? a : b)}, max: ${magnitudes.reduce((a, b) => a > b ? a : b)}',
    );
    return magnitudes;
  }

  // Parse faces (list of lists)
  static List<Face> parseFaces(String content) {
    content = stripCommentsAndHeader(content);

    final listRegex = RegExp(r'(\d+)\s*\((.*)\)', dotAll: true);
    final match = listRegex.firstMatch(content);

    if (match == null) {
      throw Exception('Invalid faces format');
    }

    final count = int.parse(match.group(1)!);
    final listContent = match.group(2)!.trim();

    print('Parsing $count faces...');

    // Parse face definitions: 4(0 1 2 3) or just numbers in list
    final faceRegex = RegExp(r'(\d+)\s*\(([^)]+)\)');
    final faces = <Face>[];

    for (final faceMatch in faceRegex.allMatches(listContent)) {
      final nPoints = int.parse(faceMatch.group(1)!);
      final pointIndices = faceMatch
          .group(2)!
          .trim()
          .split(RegExp(r'\s+'))
          .map((s) => int.parse(s))
          .toList();

      if (pointIndices.length != nPoints) {
        print(
          'Warning: Face declared $nPoints points but has ${pointIndices.length}',
        );
      }

      faces.add(Face(pointIndices));
    }

    print('Parsed ${faces.length} faces');
    return faces;
  }

  // Parse boundary file
  static Map<String, Boundary> parseBoundary(String content) {
    content = stripCommentsAndHeader(content);

    final boundaries = <String, Boundary>{};

    // Find the boundary count (first number after header)
    final countMatch = RegExp(
      r'^\s*(\d+)\s*$',
      multiLine: true,
    ).firstMatch(content);
    if (countMatch != null) {
      final boundaryCount = int.parse(countMatch.group(1)!);
      print('Parsing $boundaryCount boundaries...');
    }

    // Find the opening parenthesis after the count
    final startIdx = content.indexOf('(');
    if (startIdx == -1) {
      throw Exception('Invalid boundary format - no opening parenthesis');
    }

    // Extract content between outer parentheses
    int depth = 0;
    int endIdx = startIdx;
    for (int i = startIdx; i < content.length; i++) {
      if (content[i] == '(') depth++;
      if (content[i] == ')') {
        depth--;
        if (depth == 0) {
          endIdx = i;
          break;
        }
      }
    }

    final boundaryContent = content.substring(startIdx + 1, endIdx);

    // Parse each boundary definition
    // Match boundary name followed by its properties in braces
    final boundaryPattern = RegExp(
      r'(\w+)\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}',
      multiLine: true,
      dotAll: true,
    );

    for (final match in boundaryPattern.allMatches(boundaryContent)) {
      final name = match.group(1)!;
      final props = match.group(2)!;

      // Skip if this is just "inGroups" or other nested properties
      if (name == 'inGroups') continue;

      // Extract properties, ignoring inGroups lines
      String type = '';
      int nFaces = 0;
      int startFace = 0;

      final typeMatch = RegExp(r'type\s+(\w+);').firstMatch(props);
      if (typeMatch != null) type = typeMatch.group(1)!;

      final nFacesMatch = RegExp(r'nFaces\s+(\d+);').firstMatch(props);
      if (nFacesMatch != null) nFaces = int.parse(nFacesMatch.group(1)!);

      final startMatch = RegExp(r'startFace\s+(\d+);').firstMatch(props);
      if (startMatch != null) startFace = int.parse(startMatch.group(1)!);

      // Only add if we have valid data (skip inGroups and other metadata)
      if (type.isNotEmpty && nFaces > 0) {
        boundaries[name] = Boundary(
          name: name,
          type: type,
          nFaces: nFaces,
          startFace: startFace,
        );
        print(
          '  Parsed boundary: $name (type=$type, nFaces=$nFaces, start=$startFace)',
        );
      }
    }

    print('Total boundaries parsed: ${boundaries.length}');
    return boundaries;
  }
}
