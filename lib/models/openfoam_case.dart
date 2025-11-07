// lib/models/openfoam_case.dart

class OpenFOAMCase {
  final String casePath;
  final PolyMesh mesh;
  final Map<String, FieldData> fields;
  final List<String> timeDirectories;

  OpenFOAMCase({
    required this.casePath,
    required this.mesh,
    required this.fields,
    required this.timeDirectories,
  });
}

class PolyMesh {
  final List<Vector3> points; // Vertex coordinates
  final List<Face> faces; // Face definitions
  final List<int> owner; // Owner cell for each face
  final List<int> neighbour; // Neighbour cell for each face
  final Map<String, Boundary> boundaries;

  PolyMesh({
    required this.points,
    required this.faces,
    required this.owner,
    required this.neighbour,
    required this.boundaries,
  });
}

class Vector3 {
  final double x, y, z;
  Vector3(this.x, this.y, this.z);
}

class Face {
  final List<int> pointIndices;
  Face(this.pointIndices);
}

class Boundary {
  final String name;
  final String type;
  final int nFaces;
  final int startFace;

  Boundary({
    required this.name,
    required this.type,
    required this.nFaces,
    required this.startFace,
  });
}

class FieldData {
  final String name;
  final String fieldClass;
  final List<double> internalField; // Cell-centered values
  final Map<String, dynamic> boundaryField;
  final List<double>? pointValues; // Point-based values (interpolated)

  FieldData({
    required this.name,
    required this.fieldClass,
    required this.internalField,
    required this.boundaryField,
    this.pointValues,
  });

  // Create a copy with point values
  FieldData withPointValues(List<double> pointValues) {
    return FieldData(
      name: name,
      fieldClass: fieldClass,
      internalField: internalField,
      boundaryField: boundaryField,
      pointValues: pointValues,
    );
  }
}
