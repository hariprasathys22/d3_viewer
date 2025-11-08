// lib/readers/mesh_reader.dart

import '../models/openfoam_case.dart';
import '../parsers/foam_file_parser.dart';
import '../utils/file_utils.dart';

class MeshReader {
  static Future<PolyMesh> readMesh(String casePath) async {
    final meshPath = '$casePath/constant/polyMesh';

    // Read points (supports both normal and .gz files)
    print('Reading points...');
    final pointsBytes = await FileUtils.readFileBytes('$meshPath/points');
    final List<Vector3> points;

    if (FoamFileParser.isBinaryFormat(pointsBytes)) {
      print('✓ Binary format detected for points, parsing...');
      points = FoamFileParser.parseBinaryVectorList(pointsBytes);
    } else {
      final pointsContent = String.fromCharCodes(pointsBytes);
      points = FoamFileParser.parseListData(pointsContent).cast<Vector3>();
    }
    print('Points loaded: ${points.length}');

    // Read faces (supports both normal and .gz files)
    print('Reading faces...');
    final facesBytes = await FileUtils.readFileBytes('$meshPath/faces');
    final List<Face> faces;

    if (FoamFileParser.isBinaryFormat(facesBytes)) {
      print('✓ Binary format detected for faces, parsing...');
      faces = FoamFileParser.parseBinaryFaces(facesBytes);
    } else {
      final facesContent = String.fromCharCodes(facesBytes);
      faces = FoamFileParser.parseFaces(facesContent);
    }
    print('Faces loaded: ${faces.length}');

    // Read owner (supports both normal and .gz files)
    print('Reading owner...');
    final ownerBytes = await FileUtils.readFileBytes('$meshPath/owner');
    final List<int> owner;

    if (FoamFileParser.isBinaryFormat(ownerBytes)) {
      print('✓ Binary format detected for owner, parsing...');
      owner = FoamFileParser.parseBinaryIntList(ownerBytes);
    } else {
      final ownerContent = String.fromCharCodes(ownerBytes);
      owner = FoamFileParser.parseListData(ownerContent).cast<int>();
    }
    print('Owner loaded: ${owner.length}');

    // Read neighbour (supports both normal and .gz files)
    print('Reading neighbour...');
    final neighbourBytes = await FileUtils.readFileBytes('$meshPath/neighbour');
    final List<int> neighbour;

    if (FoamFileParser.isBinaryFormat(neighbourBytes)) {
      print('✓ Binary format detected for neighbour, parsing...');
      neighbour = FoamFileParser.parseBinaryIntList(neighbourBytes);
    } else {
      final neighbourContent = String.fromCharCodes(neighbourBytes);
      neighbour = FoamFileParser.parseListData(neighbourContent).cast<int>();
    }
    print('Neighbour loaded: ${neighbour.length}');

    // Read boundary (usually ASCII even in binary cases, supports .gz)
    print('Reading boundary...');
    final boundaryContent = await FileUtils.readFileAsString('$meshPath/boundary');
    final boundaries = FoamFileParser.parseBoundary(boundaryContent);
    print('Boundaries loaded: ${boundaries.length}');

    return PolyMesh(
      points: points,
      faces: faces,
      owner: owner,
      neighbour: neighbour,
      boundaries: boundaries,
    );
  }
}
