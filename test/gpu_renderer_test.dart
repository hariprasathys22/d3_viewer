// test/gpu_renderer_test.dart
// Test to verify GPU renderer functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:d3_viewer/models/openfoam_case.dart';
import 'package:d3_viewer/renderers/mesh_converter.dart';

void main() {
  group('MeshConverter Tests', () {
    test('Convert simple mesh to GPU format', () {
      // Create a simple test mesh (cube)
      final mesh = PolyMesh(
        points: [
          Point3D(0, 0, 0),
          Point3D(1, 0, 0),
          Point3D(1, 1, 0),
          Point3D(0, 1, 0),
          Point3D(0, 0, 1),
          Point3D(1, 0, 1),
          Point3D(1, 1, 1),
          Point3D(0, 1, 1),
        ],
        faces: [
          // Bottom face
          Face(pointIndices: [0, 1, 2, 3]),
          // Top face
          Face(pointIndices: [4, 5, 6, 7]),
          // Front face
          Face(pointIndices: [0, 1, 5, 4]),
          // Back face
          Face(pointIndices: [3, 2, 6, 7]),
          // Left face
          Face(pointIndices: [0, 3, 7, 4]),
          // Right face
          Face(pointIndices: [1, 2, 6, 5]),
        ],
        owner: [0, 0, 0, 0, 0, 0],
        neighbour: [],
        boundaries: {},
      );

      final gpuData = MeshConverter.convertToGPU(
        mesh: mesh,
        showInternalMesh: true,
      );

      // Verify vertex data
      expect(gpuData.vertices.length, equals(8 * 3)); // 8 points × 3 coords
      expect(gpuData.vertices[0], equals(0.0)); // First point X
      expect(gpuData.vertices[1], equals(0.0)); // First point Y
      expect(gpuData.vertices[2], equals(0.0)); // First point Z

      // Verify indices (6 faces × 2 triangles × 3 vertices)
      expect(gpuData.indices.length, equals(6 * 2 * 3));

      // Verify colors (8 points × 4 channels RGBA)
      expect(gpuData.colors.length, equals(8 * 4));

      // Verify mesh center calculation
      expect(gpuData.centerX, equals(0.5));
      expect(gpuData.centerY, equals(0.5));
      expect(gpuData.centerZ, equals(0.5));

      // Verify auto zoom is calculated
      expect(gpuData.autoZoom, greaterThan(0));
    });

    test('Convert mesh with field data', () {
      final mesh = PolyMesh(
        points: [
          Point3D(0, 0, 0),
          Point3D(1, 0, 0),
          Point3D(1, 1, 0),
        ],
        faces: [
          Face(pointIndices: [0, 1, 2]),
        ],
        owner: [0],
        neighbour: [],
        boundaries: {},
      );

      final fieldData = FieldData(
        name: 'temperature',
        fieldClass: 'volScalarField',
        internalField: [300.0],
      );

      final gpuData = MeshConverter.convertToGPU(
        mesh: mesh,
        fieldData: fieldData,
        usePointData: false,
        showInternalMesh: true,
      );

      // Should have vertex and color data
      expect(gpuData.vertices.length, equals(3 * 3)); // 3 points × 3 coords
      expect(gpuData.colors.length, equals(3 * 4)); // 3 points × 4 channels
      expect(gpuData.indices.length, equals(3)); // 1 triangle × 3 vertices
    });

    test('Triangulation of quad face', () {
      final mesh = PolyMesh(
        points: [
          Point3D(0, 0, 0),
          Point3D(1, 0, 0),
          Point3D(1, 1, 0),
          Point3D(0, 1, 0),
        ],
        faces: [
          Face(pointIndices: [0, 1, 2, 3]), // Quad
        ],
        owner: [0],
        neighbour: [],
        boundaries: {},
      );

      final gpuData = MeshConverter.convertToGPU(
        mesh: mesh,
        showInternalMesh: true,
      );

      // Quad should be split into 2 triangles = 6 indices
      expect(gpuData.indices.length, equals(6));
    });

    test('Triangulation of polygon face', () {
      final mesh = PolyMesh(
        points: [
          Point3D(0, 0, 0),
          Point3D(1, 0, 0),
          Point3D(1, 1, 0),
          Point3D(0.5, 1.5, 0),
          Point3D(0, 1, 0),
        ],
        faces: [
          Face(pointIndices: [0, 1, 2, 3, 4]), // Pentagon
        ],
        owner: [0],
        neighbour: [],
        boundaries: {},
      );

      final gpuData = MeshConverter.convertToGPU(
        mesh: mesh,
        showInternalMesh: true,
      );

      // Pentagon (5 vertices) -> 3 triangles = 9 indices
      expect(gpuData.indices.length, equals(9));
    });

    test('Empty mesh handling', () {
      final mesh = PolyMesh(
        points: [],
        faces: [],
        owner: [],
        neighbour: [],
        boundaries: {},
      );

      final gpuData = MeshConverter.convertToGPU(
        mesh: mesh,
        showInternalMesh: true,
      );

      expect(gpuData.vertices.length, equals(0));
      expect(gpuData.indices.length, equals(0));
      expect(gpuData.colors.length, equals(0));
    });
  });

  group('GPU Data Format Tests', () {
    test('Vertex data is in XYZ format', () {
      final mesh = PolyMesh(
        points: [
          Point3D(1.5, 2.5, 3.5),
        ],
        faces: [],
        owner: [],
        neighbour: [],
        boundaries: {},
      );

      final gpuData = MeshConverter.convertToGPU(
        mesh: mesh,
        showInternalMesh: true,
      );

      expect(gpuData.vertices[0], equals(1.5)); // X
      expect(gpuData.vertices[1], equals(2.5)); // Y
      expect(gpuData.vertices[2], equals(3.5)); // Z
    });

    test('Color data is in RGBA format', () {
      final mesh = PolyMesh(
        points: [Point3D(0, 0, 0)],
        faces: [],
        owner: [],
        neighbour: [],
        boundaries: {},
      );

      final gpuData = MeshConverter.convertToGPU(
        mesh: mesh,
        showInternalMesh: true,
      );

      // Default color should have 4 components (RGBA)
      expect(gpuData.colors.length, equals(4));
      expect(gpuData.colors[0], greaterThanOrEqualTo(0.0)); // R
      expect(gpuData.colors[1], greaterThanOrEqualTo(0.0)); // G
      expect(gpuData.colors[2], greaterThanOrEqualTo(0.0)); // B
      expect(gpuData.colors[3], greaterThanOrEqualTo(0.0)); // A
      
      expect(gpuData.colors[0], lessThanOrEqualTo(1.0));
      expect(gpuData.colors[1], lessThanOrEqualTo(1.0));
      expect(gpuData.colors[2], lessThanOrEqualTo(1.0));
      expect(gpuData.colors[3], lessThanOrEqualTo(1.0));
    });
  });
}
