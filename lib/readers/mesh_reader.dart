// lib/readers/mesh_reader.dart

import 'dart:io';
import '../models/openfoam_case.dart';
import '../parsers/foam_file_parser.dart';

class MeshReader {
  static Future<PolyMesh> readMesh(String casePath) async {
    final meshPath = '$casePath/constant/polyMesh';

    // Read points
    print('Reading points...');
    final pointsFile = File('$meshPath/points');
    final pointsBytes = await pointsFile.readAsBytes();
    final List<Vector3> points;

    if (FoamFileParser.isBinaryFormat(pointsBytes)) {
      print('✓ Binary format detected for points, parsing...');
      points = FoamFileParser.parseBinaryVectorList(pointsBytes);
    } else {
      final pointsContent = await pointsFile.readAsString();
      points = FoamFileParser.parseListData(pointsContent).cast<Vector3>();
    }
    print('Points loaded: ${points.length}');

    // Read faces
    print('Reading faces...');
    final facesFile = File('$meshPath/faces');
    final facesBytes = await facesFile.readAsBytes();
    final List<Face> faces;

    if (FoamFileParser.isBinaryFormat(facesBytes)) {
      print('✓ Binary format detected for faces, parsing...');
      faces = FoamFileParser.parseBinaryFaces(facesBytes);
    } else {
      final facesContent = await facesFile.readAsString();
      faces = FoamFileParser.parseFaces(facesContent);
    }
    print('Faces loaded: ${faces.length}');

    // Read owner
    print('Reading owner...');
    final ownerFile = File('$meshPath/owner');
    final ownerBytes = await ownerFile.readAsBytes();
    final List<int> owner;

    if (FoamFileParser.isBinaryFormat(ownerBytes)) {
      print('✓ Binary format detected for owner, parsing...');
      owner = FoamFileParser.parseBinaryIntList(ownerBytes);
    } else {
      final ownerContent = await ownerFile.readAsString();
      owner = FoamFileParser.parseListData(ownerContent).cast<int>();
    }
    print('Owner loaded: ${owner.length}');

    // Read neighbour
    print('Reading neighbour...');
    final neighbourFile = File('$meshPath/neighbour');
    final neighbourBytes = await neighbourFile.readAsBytes();
    final List<int> neighbour;

    if (FoamFileParser.isBinaryFormat(neighbourBytes)) {
      print('✓ Binary format detected for neighbour, parsing...');
      neighbour = FoamFileParser.parseBinaryIntList(neighbourBytes);
    } else {
      final neighbourContent = await neighbourFile.readAsString();
      neighbour = FoamFileParser.parseListData(neighbourContent).cast<int>();
    }
    print('Neighbour loaded: ${neighbour.length}');

    // Read boundary (usually ASCII even in binary cases)
    print('Reading boundary...');
    final boundaryFile = File('$meshPath/boundary');
    final boundaryContent = await boundaryFile.readAsString();
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
