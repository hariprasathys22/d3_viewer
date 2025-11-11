// lib/renderers/mesh_converter.dart

import 'dart:math' as math;
import '../models/openfoam_case.dart';
import '../utils/color_map.dart';

class MeshConverter {
  /// Convert OpenFOAM mesh to GPU-ready format
  static MeshGPUData convertToGPU({
    required PolyMesh mesh,
    FieldData? fieldData,
    bool usePointData = true,
    bool showInternalMesh = true,
    Map<String, bool> boundaryVisibility = const {},
  }) {
    final vertices = <double>[];
    final indices = <int>[];
    final colors = <double>[];

    // Add all mesh points
    for (final point in mesh.points) {
      vertices.addAll([point.x, point.y, point.z]);
    }

    // Determine field value range for color mapping
    double? minValue;
    double? maxValue;
    List<double>? pointData;

    if (fieldData != null) {
      if (usePointData && fieldData.internalField.isNotEmpty) {
        // Interpolate cell data to points
        pointData = _interpolateCellToPoint(mesh, fieldData);
        minValue = pointData.reduce(math.min);
        maxValue = pointData.reduce(math.max);
      } else if (!usePointData && fieldData.internalField.isNotEmpty) {
        minValue = fieldData.internalField.reduce(math.min);
        maxValue = fieldData.internalField.reduce(math.max);
      }
    }

    // Generate colors per vertex
    if (pointData != null && minValue != null && maxValue != null) {
      for (int i = 0; i < pointData.length; i++) {
        final color = ColorMap.getFastColor(pointData[i], minValue, maxValue);
        colors.addAll([
          color.red / 255.0,
          color.green / 255.0,
          color.blue / 255.0,
          color.alpha / 255.0,
        ]);
      }
    } else {
      // Default color
      for (int i = 0; i < mesh.points.length; i++) {
        colors.addAll([0.5, 0.7, 1.0, 1.0]); // Light blue
      }
    }

    // Convert faces to triangles
    final numInternalFaces = mesh.neighbour.length;
    
    for (int faceIdx = 0; faceIdx < mesh.faces.length; faceIdx++) {
      final face = mesh.faces[faceIdx];
      if (face.pointIndices.isEmpty) continue;

      // Check visibility
      bool isInternal = faceIdx < numInternalFaces;
      if (isInternal && !showInternalMesh) continue;

      if (!isInternal) {
        String? boundaryName;
        for (final boundary in mesh.boundaries.values) {
          if (faceIdx >= boundary.startFace &&
              faceIdx < boundary.startFace + boundary.nFaces) {
            boundaryName = boundary.name;
            break;
          }
        }
        if (boundaryName != null && !(boundaryVisibility[boundaryName] ?? true)) {
          continue;
        }
      }

      // Triangulate face
      _triangulateFace(face.pointIndices, indices);
    }

    // Calculate mesh center
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    double minZ = double.infinity;
    double maxZ = double.negativeInfinity;

    for (final point in mesh.points) {
      minX = math.min(minX, point.x);
      maxX = math.max(maxX, point.x);
      minY = math.min(minY, point.y);
      maxY = math.max(maxY, point.y);
      minZ = math.min(minZ, point.z);
      maxZ = math.max(maxZ, point.z);
    }

    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    final centerZ = (minZ + maxZ) / 2;

    // Calculate auto-zoom
    final sizeX = maxX - minX;
    final sizeY = maxY - minY;
    final sizeZ = maxZ - minZ;
    final maxSize = math.max(sizeX, math.max(sizeY, sizeZ));
    final autoZoom = maxSize > 0 ? 200.0 / maxSize : 500.0;

    return MeshGPUData(
      vertices: vertices,
      indices: indices,
      colors: colors,
      centerX: centerX,
      centerY: centerY,
      centerZ: centerZ,
      autoZoom: autoZoom,
    );
  }

  /// Interpolate cell-centered data to point data
  static List<double> _interpolateCellToPoint(PolyMesh mesh, FieldData fieldData) {
    final pointValues = List<double>.filled(mesh.points.length, 0.0);
    final pointCount = List<int>.filled(mesh.points.length, 0);

    for (int faceIdx = 0; faceIdx < mesh.faces.length; faceIdx++) {
      final face = mesh.faces[faceIdx];

      // Owner cell
      if (faceIdx < mesh.owner.length) {
        final cellIdx = mesh.owner[faceIdx];
        if (cellIdx >= 0 && cellIdx < fieldData.internalField.length) {
          final cellValue = fieldData.internalField[cellIdx];
          for (final pointIdx in face.pointIndices) {
            if (pointIdx < mesh.points.length) {
              pointValues[pointIdx] += cellValue;
              pointCount[pointIdx]++;
            }
          }
        }
      }

      // Neighbour cell
      if (faceIdx < mesh.neighbour.length) {
        final neighbourIdx = mesh.neighbour[faceIdx];
        if (neighbourIdx >= 0 && neighbourIdx < fieldData.internalField.length) {
          final neighbourValue = fieldData.internalField[neighbourIdx];
          for (final pointIdx in face.pointIndices) {
            if (pointIdx < mesh.points.length) {
              pointValues[pointIdx] += neighbourValue;
              pointCount[pointIdx]++;
            }
          }
        }
      }
    }

    // Average
    for (int i = 0; i < pointValues.length; i++) {
      if (pointCount[i] > 0) {
        pointValues[i] /= pointCount[i];
      }
    }

    return pointValues;
  }

  /// Triangulate a face (fan triangulation)
  static void _triangulateFace(List<int> pointIndices, List<int> output) {
    if (pointIndices.length < 3) return;

    if (pointIndices.length == 3) {
      // Already a triangle
      output.addAll(pointIndices);
    } else if (pointIndices.length == 4) {
      // Quad -> 2 triangles
      output.addAll([pointIndices[0], pointIndices[1], pointIndices[2]]);
      output.addAll([pointIndices[0], pointIndices[2], pointIndices[3]]);
    } else {
      // Polygon -> fan triangulation
      for (int i = 1; i < pointIndices.length - 1; i++) {
        output.addAll([pointIndices[0], pointIndices[i], pointIndices[i + 1]]);
      }
    }
  }
}

class MeshGPUData {
  final List<double> vertices;
  final List<int> indices;
  final List<double> colors;
  final double centerX;
  final double centerY;
  final double centerZ;
  final double autoZoom;

  MeshGPUData({
    required this.vertices,
    required this.indices,
    required this.colors,
    required this.centerX,
    required this.centerY,
    required this.centerZ,
    required this.autoZoom,
  });
}
