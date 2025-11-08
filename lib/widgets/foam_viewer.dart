// lib/widgets/foam_viewer.dart

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../models/openfoam_case.dart';
import '../utils/color_map.dart';

enum MeshRepresentation { wireframe, surface, surfaceWithEdges }

enum DataMode { cellData, pointData }

class FoamViewer extends StatefulWidget {
  final OpenFOAMCase foamCase;
  final FieldData? fieldData;
  final bool showInternalMesh;
  final Map<String, bool> boundaryVisibility;

  const FoamViewer({
    super.key,
    required this.foamCase,
    this.fieldData,
    this.showInternalMesh = true,
    this.boundaryVisibility = const {},
  });

  @override
  State<FoamViewer> createState() => _FoamViewerState();
}

class _FoamViewerState extends State<FoamViewer> {
  double _rotationX = 0.3;
  double _rotationY = 0.3;
  double _zoom = 500.0; // Increased default zoom
  Offset? _lastPanPosition;
  MeshRepresentation _representation = MeshRepresentation.surfaceWithEdges;
  DataMode _dataMode = DataMode.pointData;

  @override
  void initState() {
    super.initState();
    // Auto-calculate zoom based on mesh size
    _calculateAutoZoom();
  }

  void _calculateAutoZoom() {
    if (widget.foamCase.mesh.points.isEmpty) return;

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    double minZ = double.infinity;
    double maxZ = double.negativeInfinity;

    for (final point in widget.foamCase.mesh.points) {
      minX = math.min(minX, point.x);
      maxX = math.max(maxX, point.x);
      minY = math.min(minY, point.y);
      maxY = math.max(maxY, point.y);
      minZ = math.min(minZ, point.z);
      maxZ = math.max(maxZ, point.z);
    }

    final sizeX = maxX - minX;
    final sizeY = maxY - minY;
    final sizeZ = maxZ - minZ;
    final maxSize = math.max(sizeX, math.max(sizeY, sizeZ));

    if (maxSize > 0) {
      // Calculate zoom to fit mesh in viewport (assuming ~800px viewport)
      _zoom = 200.0 / maxSize;
    }
  }

  // Preset view methods
  void _setTopView() => setState(() { _rotationX = 0.0; _rotationY = 0.0; });
  void _setBottomView() => setState(() { _rotationX = math.pi; _rotationY = 0.0; });
  void _setFrontView() => setState(() { _rotationX = math.pi / 2; _rotationY = 0.0; });
  void _setBackView() => setState(() { _rotationX = math.pi / 2; _rotationY = math.pi; });
  void _setRightView() => setState(() { _rotationX = math.pi / 2; _rotationY = math.pi / 2; });
  void _setLeftView() => setState(() { _rotationX = math.pi / 2; _rotationY = -math.pi / 2; });
  void _setIsometricView() => setState(() { _rotationX = math.pi / 4; _rotationY = math.pi / 4; });


  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                setState(() {
                  // Zoom with mouse wheel - proportional to current zoom level
                  // This makes zooming smooth at all zoom levels
                  final zoomFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
                  _zoom *= zoomFactor;
                  
                  // More generous clamping range
                  _zoom = _zoom.clamp(0.1, 10000.0);
                });
              }
            },
            child: GestureDetector(
              onPanStart: (details) {
                _lastPanPosition = details.localPosition;
              },
              onPanUpdate: (details) {
                setState(() {
                  final delta = details.localPosition - _lastPanPosition!;
                  _rotationY += delta.dx * 0.01;
                  _rotationX += delta.dy * 0.01;
                  _lastPanPosition = details.localPosition;
                });
              },
              onPanEnd: (details) {
                _lastPanPosition = null;
              },
              child: Container(
                color: Colors.white,
                child: CustomPaint(
                  painter: FoamMeshPainter(
                    widget.foamCase.mesh,
                    _rotationX,
                    _rotationY,
                    _zoom,
                    _representation,
                    widget.fieldData,
                    _dataMode,
                    widget.showInternalMesh,
                    widget.boundaryVisibility,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          // Representation dropdown
          Positioned(
            top: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Representation mode
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButton<MeshRepresentation>(
                    value: _representation,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: MeshRepresentation.wireframe,
                        child: Text('Wireframe'),
                      ),
                      DropdownMenuItem(
                        value: MeshRepresentation.surface,
                        child: Text('Surface'),
                      ),
                      DropdownMenuItem(
                        value: MeshRepresentation.surfaceWithEdges,
                        child: Text('Surface with Edges'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _representation = value;
                        });
                      }
                    },
                  ),
                ),
                // Data mode dropdown (only show when field data is loaded)
                if (widget.fieldData != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButton<DataMode>(
                      value: _dataMode,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: DataMode.cellData,
                          child: Text('Cell Data'),
                        ),
                        DropdownMenuItem(
                          value: DataMode.pointData,
                          child: Text('Point Data'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _dataMode = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Color legend (only show when field data is loaded)
          if (widget.fieldData != null)
            Positioned(
              bottom: 20,
              right: 20,
              child: _ColorLegend(fieldData: widget.fieldData!),
            ),
          // View preset buttons on the right side
          Positioned(
            right: 10,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ViewButton(
                      icon: Icons.arrow_upward,
                      tooltip: 'Top View',
                      onPressed: _setTopView,
                    ),
                    _ViewButton(
                      icon: Icons.arrow_downward,
                      tooltip: 'Bottom View',
                      onPressed: _setBottomView,
                    ),
                    const Divider(height: 8),
                    _ViewButton(
                      icon: Icons.arrow_forward,
                      tooltip: 'Front View',
                      onPressed: _setFrontView,
                    ),
                    _ViewButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Back View',
                      onPressed: _setBackView,
                    ),
                    const Divider(height: 8),
                    _ViewButton(
                      icon: Icons.arrow_right_alt,
                      tooltip: 'Right View',
                      onPressed: _setRightView,
                    ),
                    _ViewButton(
                      icon: Icons.arrow_left,
                      tooltip: 'Left View',
                      onPressed: _setLeftView,
                    ),
                    const Divider(height: 8),
                    _ViewButton(
                      icon: Icons.threed_rotation,
                      tooltip: 'Isometric View',
                      onPressed: _setIsometricView,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FoamMeshPainter extends CustomPainter {
  final PolyMesh mesh;
  final double rotationX;
  final double rotationY;
  final double zoom;
  final MeshRepresentation representation;
  final FieldData? fieldData;
  final DataMode dataMode;
  final bool showInternalMesh;
  final Map<String, bool> boundaryVisibility;

  // Cache for point data interpolation
  List<double>? _pointData;
  
  // GPU-friendly cached data structures
  static List<double>? _cachedPointData;
  static FieldData? _cachedFieldData;
  static DataMode? _cachedDataMode;
  static PolyMesh? _cachedMesh;

  FoamMeshPainter(
    this.mesh,
    this.rotationX,
    this.rotationY,
    this.zoom,
    this.representation,
    this.fieldData,
    this.dataMode,
    this.showInternalMesh,
    this.boundaryVisibility,
  ) {
    // Use cached point data if available and valid
    if (_cachedFieldData == fieldData && 
        _cachedDataMode == dataMode && 
        _cachedMesh == mesh &&
        _cachedPointData != null) {
      _pointData = _cachedPointData;
    } else if (fieldData != null &&
        fieldData!.internalField.isNotEmpty &&
        dataMode == DataMode.pointData) {
      // Convert cell data to point data if needed (cache it)
      _pointData = _interpolateCellToPoint();
      _cachedPointData = _pointData;
      _cachedFieldData = fieldData;
      _cachedDataMode = dataMode;
      _cachedMesh = mesh;
    }
  }

  // Interpolate cell-centered data to point data
  List<double> _interpolateCellToPoint() {
    final pointValues = List<double>.filled(mesh.points.length, 0.0);
    final pointCount = List<int>.filled(mesh.points.length, 0);

    // For each face, distribute the owner cell value to all face points
    for (int faceIdx = 0; faceIdx < mesh.faces.length; faceIdx++) {
      final face = mesh.faces[faceIdx];

      // Get the owner cell value
      int cellIdx = -1;
      if (faceIdx < mesh.owner.length) {
        cellIdx = mesh.owner[faceIdx];
      }

      if (cellIdx >= 0 && cellIdx < fieldData!.internalField.length) {
        final cellValue = fieldData!.internalField[cellIdx];

        // Add this value to all points of the face
        for (final pointIdx in face.pointIndices) {
          if (pointIdx < mesh.points.length) {
            pointValues[pointIdx] += cellValue;
            pointCount[pointIdx]++;
          }
        }
      }

      // Also consider neighbour cell if it exists
      if (faceIdx < mesh.neighbour.length) {
        final neighbourIdx = mesh.neighbour[faceIdx];
        if (neighbourIdx >= 0 &&
            neighbourIdx < fieldData!.internalField.length) {
          final neighbourValue = fieldData!.internalField[neighbourIdx];

          for (final pointIdx in face.pointIndices) {
            if (pointIdx < mesh.points.length) {
              pointValues[pointIdx] += neighbourValue;
              pointCount[pointIdx]++;
            }
          }
        }
      }
    }

    // Average the accumulated values
    for (int i = 0; i < pointValues.length; i++) {
      if (pointCount[i] > 0) {
        pointValues[i] /= pointCount[i];
      }
    }

    return pointValues;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Calculate mesh bounds
    if (mesh.points.isEmpty) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'No mesh data',
          style: TextStyle(color: Colors.red, fontSize: 24),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(centerX - 50, centerY - 12));
      return;
    }

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

    final centerMeshX = (minX + maxX) / 2;
    final centerMeshY = (minY + maxY) / 2;
    final centerMeshZ = (minZ + maxZ) / 2;

    // Get field data min/max for color mapping
    double? minFieldValue;
    double? maxFieldValue;
    if (fieldData != null) {
      if (dataMode == DataMode.pointData &&
          _pointData != null &&
          _pointData!.isNotEmpty) {
        // Use point data range
        minFieldValue = _pointData!.reduce(math.min);
        maxFieldValue = _pointData!.reduce(math.max);
      } else if (dataMode == DataMode.cellData &&
          fieldData!.internalField.isNotEmpty) {
        // Use cell data range
        minFieldValue = fieldData!.internalField.reduce(math.min);
        maxFieldValue = fieldData!.internalField.reduce(math.max);
      }
    }

    // ============================================
    // GPU-OPTIMIZED: Pre-transform all points once
    // ============================================
    final transformedPoints = List<Offset>.filled(mesh.points.length, Offset.zero);
    final transformedDepths = List<double>.filled(mesh.points.length, 0.0);
    
    for (int i = 0; i < mesh.points.length; i++) {
      final point = mesh.points[i];
      
      // Center the mesh
      final x = point.x - centerMeshX;
      final y = point.y - centerMeshY;
      final z = point.z - centerMeshZ;

      // Apply 3D rotation
      final rotated = _rotate3D(x, y, z, rotationX, rotationY);

      // Project to 2D
      transformedPoints[i] = Offset(
        centerX + rotated[0] * zoom,
        centerY - rotated[1] * zoom,
      );
      transformedDepths[i] = rotated[2];
    }

    // ============================================
    // GPU-OPTIMIZED: Build face list with pre-transformed vertices
    // ============================================
    final List<_TransformedFace> transformedFaces = [];
    final numInternalFaces = mesh.neighbour.length;

    for (int faceIdx = 0; faceIdx < mesh.faces.length; faceIdx++) {
      final face = mesh.faces[faceIdx];
      if (face.pointIndices.isEmpty) continue;

      // Determine if this face belongs to a boundary or is internal
      bool isInternal = faceIdx < numInternalFaces;
      String? boundaryName;

      if (!isInternal) {
        // Find which boundary this face belongs to
        for (final boundary in mesh.boundaries.values) {
          if (faceIdx >= boundary.startFace &&
              faceIdx < boundary.startFace + boundary.nFaces) {
            boundaryName = boundary.name;
            break;
          }
        }
      }

      // Skip face if it should be hidden based on visibility settings
      if (isInternal && !showInternalMesh) continue;
      if (!isInternal &&
          boundaryName != null &&
          !(boundaryVisibility[boundaryName] ?? true))
        continue;

      // Use pre-transformed points (zero cost!)
      final List<Offset> screenPoints = [];
      final List<int> pointIndices = [];
      double totalZ = 0.0;

      // Get cell index (owner) for this face for cell data mode
      int cellIdx = -1;
      if (faceIdx < mesh.owner.length) {
        cellIdx = mesh.owner[faceIdx];
      }

      for (final pointIdx in face.pointIndices) {
        if (pointIdx >= mesh.points.length) continue;
        
        screenPoints.add(transformedPoints[pointIdx]);
        pointIndices.add(pointIdx);
        totalZ += transformedDepths[pointIdx];
      }

      if (screenPoints.isNotEmpty) {
        final avgZ = totalZ / screenPoints.length;
        transformedFaces.add(
          _TransformedFace(screenPoints, avgZ, cellIdx, pointIndices),
        );
      }
    }

    // Sort faces by depth (painter's algorithm - back to front)
    transformedFaces.sort((a, b) => a.depth.compareTo(b.depth));

    // ============================================
    // GPU-OPTIMIZED: Batch render faces
    // ============================================
    _batchRenderFaces(
      canvas, 
      transformedFaces, 
      minFieldValue, 
      maxFieldValue,
    );

    // Draw info text
    final textPainter = TextPainter(
      text: TextSpan(
        text:
            'Points: ${mesh.points.length}, Faces: ${mesh.faces.length}\n'
            'Drag to rotate | Scroll to zoom\n'
            'Zoom: ${zoom.toStringAsFixed(1)} | GPU: ON',
        style: const TextStyle(color: Colors.black, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(10, 10));
  }

  // ============================================
  // GPU-OPTIMIZED: Batch rendering with Vertices API
  // ============================================
  void _batchRenderFaces(
    Canvas canvas,
    List<_TransformedFace> faces,
    double? minFieldValue,
    double? maxFieldValue,
  ) {
    // For GPU acceleration, we'll batch triangles using Vertices API
    final List<Offset> allTriangleVertices = [];
    final List<Color> allTriangleColors = [];
    final List<Path> edgePaths = []; // For wireframe/edges
    
    for (final transformedFace in faces) {
      if (transformedFace.points.isEmpty) continue;

      // For wireframe mode
      if (representation == MeshRepresentation.wireframe) {
        final path = Path();
        path.moveTo(transformedFace.points[0].dx, transformedFace.points[0].dy);
        for (int i = 1; i < transformedFace.points.length; i++) {
          path.lineTo(transformedFace.points[i].dx, transformedFace.points[i].dy);
        }
        path.close();
        edgePaths.add(path);
        continue;
      }

      // For surface modes - convert to triangles for GPU rendering
      if (representation == MeshRepresentation.surface ||
          representation == MeshRepresentation.surfaceWithEdges) {
        
        if (dataMode == DataMode.pointData &&
            _pointData != null &&
            minFieldValue != null &&
            maxFieldValue != null &&
            transformedFace.pointIndices.isNotEmpty &&
            transformedFace.points.length >= 3) {
          
          // POINT DATA MODE: Batch triangles with vertex colors
          _batchTrianglesFromFace(
            transformedFace.points,
            transformedFace.pointIndices,
            minFieldValue,
            maxFieldValue,
            allTriangleVertices,
            allTriangleColors,
          );
          
        } else if (dataMode == DataMode.cellData &&
            fieldData != null &&
            minFieldValue != null &&
            maxFieldValue != null &&
            transformedFace.cellIdx >= 0 &&
            transformedFace.cellIdx < fieldData!.internalField.length) {
          
          // CELL DATA MODE: Batch with uniform color
          final cellValue = fieldData!.internalField[transformedFace.cellIdx];
          final cellColor = ColorMap.getFastColor(
            cellValue,
            minFieldValue,
            maxFieldValue,
          );
          
          _batchTrianglesFromFace(
            transformedFace.points,
            transformedFace.pointIndices,
            minFieldValue,
            maxFieldValue,
            allTriangleVertices,
            allTriangleColors,
            uniformColor: cellColor,
          );
          
        } else {
          // No field data - use default color
          _batchTrianglesFromFace(
            transformedFace.points,
            transformedFace.pointIndices,
            0.0,
            1.0,
            allTriangleVertices,
            allTriangleColors,
            uniformColor: Colors.lightBlue.shade200,
          );
        }

        // Add edges if requested
        if (representation == MeshRepresentation.surfaceWithEdges) {
          final path = Path();
          path.moveTo(transformedFace.points[0].dx, transformedFace.points[0].dy);
          for (int i = 1; i < transformedFace.points.length; i++) {
            path.lineTo(transformedFace.points[i].dx, transformedFace.points[i].dy);
          }
          path.close();
          edgePaths.add(path);
        }
      }
    }

    // ============================================
    // GPU DRAW CALL: Single batch render for all triangles
    // ============================================
    if (allTriangleVertices.isNotEmpty) {
      final vertices = ui.Vertices(
        ui.VertexMode.triangles,
        allTriangleVertices,
        colors: allTriangleColors,
      );
      
      final paint = Paint()..style = PaintingStyle.fill;
      canvas.drawVertices(vertices, BlendMode.srcOver, paint);
    }

    // Draw edges/wireframe (can't batch these easily, but they're lightweight)
    if (edgePaths.isNotEmpty) {
      final edgePaint = Paint()
        ..color = representation == MeshRepresentation.wireframe 
            ? Colors.blue 
            : Colors.black.withOpacity(0.3)
        ..strokeWidth = representation == MeshRepresentation.wireframe ? 1.0 : 0.5
        ..style = PaintingStyle.stroke;
      
      for (final path in edgePaths) {
        canvas.drawPath(path, edgePaint);
      }
    }
  }

  // ============================================
  // GPU-OPTIMIZED: Batch triangulate face
  // ============================================
  void _batchTrianglesFromFace(
    List<Offset> points,
    List<int> pointIndices,
    double minValue,
    double maxValue,
    List<Offset> outVertices,
    List<Color> outColors, {
    Color? uniformColor,
  }) {
    if (points.length < 3) return;

    // Get colors for each vertex
    final colors = <Color>[];
    if (uniformColor != null) {
      // Use uniform color for all vertices
      for (int i = 0; i < pointIndices.length; i++) {
        colors.add(uniformColor);
      }
    } else if (_pointData != null) {
      // Use per-vertex colors
      for (final pointIdx in pointIndices) {
        if (pointIdx >= 0 && pointIdx < _pointData!.length) {
          final value = _pointData![pointIdx];
          colors.add(ColorMap.getFastColor(value, minValue, maxValue));
        } else {
          colors.add(Colors.grey);
        }
      }
    }

    // Triangulate and add to batch
    if (points.length == 3) {
      // Triangle - add directly
      outVertices.addAll(points);
      outColors.addAll(colors);
    } else if (points.length == 4) {
      // Quad - split into 2 triangles
      outVertices.addAll([points[0], points[1], points[2]]);
      outColors.addAll([colors[0], colors[1], colors[2]]);
      outVertices.addAll([points[0], points[2], points[3]]);
      outColors.addAll([colors[0], colors[2], colors[3]]);
    } else {
      // Polygon - fan triangulation
      for (int i = 1; i < points.length - 1; i++) {
        outVertices.addAll([points[0], points[i], points[i + 1]]);
        outColors.addAll([colors[0], colors[i], colors[i + 1]]);
      }
    }
  }

  List<double> _rotate3D(
    double x,
    double y,
    double z,
    double angleX,
    double angleY,
  ) {
    // Rotate around X axis
    final cosX = math.cos(angleX);
    final sinX = math.sin(angleX);
    final y1 = y * cosX - z * sinX;
    final z1 = y * sinX + z * cosX;

    // Rotate around Y axis
    final cosY = math.cos(angleY);
    final sinY = math.sin(angleY);
    final x2 = x * cosY + z1 * sinY;
    final z2 = -x * sinY + z1 * cosY;

    return [x2, y1, z2];
  }

  @override
  bool shouldRepaint(covariant FoamMeshPainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.zoom != zoom ||
        oldDelegate.representation != representation ||
        oldDelegate.fieldData != fieldData ||
        oldDelegate.dataMode != dataMode ||
        oldDelegate.showInternalMesh != showInternalMesh ||
        oldDelegate.boundaryVisibility != boundaryVisibility;
  }
}

// Helper class for depth sorting
class _TransformedFace {
  final List<Offset> points;
  final double depth;
  final int cellIdx;
  final List<int> pointIndices;

  _TransformedFace(
    this.points,
    this.depth,
    this.cellIdx, [
    this.pointIndices = const [],
  ]);
}

// Color legend widget
class _ColorLegend extends StatelessWidget {
  final FieldData fieldData;

  const _ColorLegend({required this.fieldData});

  @override
  Widget build(BuildContext context) {
    // Use point values if available for better range, otherwise use internal field
    final values = fieldData.pointValues ?? fieldData.internalField;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);

    // Extract field type from class name
    String fieldType = 'Field';
    if (fieldData.fieldClass.contains('Vector')) {
      fieldType = 'Velocity Magnitude';
    } else if (fieldData.fieldClass.contains('Scalar')) {
      fieldType = fieldData.name;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fieldType,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          // Color bar
          Container(
            width: 200,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: CustomPaint(painter: _ColorBarPainter()),
            ),
          ),
          const SizedBox(height: 4),
          // Min/Max labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ColorMap.formatValue(minValue),
                style: const TextStyle(fontSize: 10),
              ),
              Text(
                ColorMap.formatValue(maxValue),
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Custom painter for the color bar gradient
class _ColorBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const steps = 100;
    final barWidth = size.width / steps;

    for (int i = 0; i < steps; i++) {
      final value = i / (steps - 1);
      final color = ColorMap.getFastColor(value, 0.0, 1.0);
      final paint = Paint()..color = color;

      canvas.drawRect(
        Rect.fromLTWH(i * barWidth, 0, barWidth + 1, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// View preset button widget
class _ViewButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ViewButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
