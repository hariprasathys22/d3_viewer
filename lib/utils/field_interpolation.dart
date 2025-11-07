// lib/utils/field_interpolation.dart

import '../models/openfoam_case.dart';

class FieldInterpolation {
  /// Convert cell-centered data to point data by averaging values from all cells sharing each point
  static List<double> cellToPoint(List<double> cellData, PolyMesh mesh) {
    final nPoints = mesh.points.length;
    final nCells = cellData.length;

    // Initialize point values and count how many cells contribute to each point
    final pointValues = List<double>.filled(nPoints, 0.0);
    final pointCounts = List<int>.filled(nPoints, 0);

    // For each face, add the owner cell value to all points of that face
    for (int faceIdx = 0; faceIdx < mesh.faces.length; faceIdx++) {
      final face = mesh.faces[faceIdx];

      // Get owner cell index
      if (faceIdx >= mesh.owner.length) continue;
      final ownerCell = mesh.owner[faceIdx];

      // Skip if owner cell index is out of bounds
      if (ownerCell < 0 || ownerCell >= nCells) continue;

      final cellValue = cellData[ownerCell];

      // Add this cell's value to all points of the face
      for (final pointIdx in face.pointIndices) {
        if (pointIdx >= 0 && pointIdx < nPoints) {
          pointValues[pointIdx] += cellValue;
          pointCounts[pointIdx]++;
        }
      }

      // If this is an internal face, also add the neighbour cell contribution
      if (faceIdx < mesh.neighbour.length) {
        final neighbourCell = mesh.neighbour[faceIdx];
        if (neighbourCell >= 0 && neighbourCell < nCells) {
          final neighbourValue = cellData[neighbourCell];

          for (final pointIdx in face.pointIndices) {
            if (pointIdx >= 0 && pointIdx < nPoints) {
              pointValues[pointIdx] += neighbourValue;
              pointCounts[pointIdx]++;
            }
          }
        }
      }
    }

    // Average the values
    for (int i = 0; i < nPoints; i++) {
      if (pointCounts[i] > 0) {
        pointValues[i] /= pointCounts[i];
      }
    }

    return pointValues;
  }

  /// Get min and max values from a list
  static (double, double) getMinMax(List<double> values) {
    if (values.isEmpty) return (0.0, 1.0);

    double minVal = values[0];
    double maxVal = values[0];

    for (final value in values) {
      if (value < minVal) minVal = value;
      if (value > maxVal) maxVal = value;
    }

    return (minVal, maxVal);
  }
}
