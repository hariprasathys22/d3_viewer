// lib/widgets/foam_viewer_gpu.dart

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import '../models/openfoam_case.dart';
import '../renderers/foam_gl_renderer_ffi.dart';
import '../renderers/mesh_converter.dart';
import '../utils/color_map.dart';

enum MeshRepresentationMode { wireframe, surface, surfaceWithEdges }

enum DataModeType { cellData, pointData }

class FoamViewerGPU extends StatefulWidget {
  final OpenFOAMCase foamCase;
  final FieldData? fieldData;
  final bool showInternalMesh;
  final Map<String, bool> boundaryVisibility;

  const FoamViewerGPU({
    super.key,
    required this.foamCase,
    this.fieldData,
    this.showInternalMesh = true,
    this.boundaryVisibility = const {},
  });

  @override
  State<FoamViewerGPU> createState() => _FoamViewerGPUState();
}

class _FoamViewerGPUState extends State<FoamViewerGPU> {
  FoamGLRenderer? _renderer;
  double _rotationX = 0.3;
  double _rotationY = 0.3;
  double _zoom = 500.0;
  Offset? _lastPanPosition;
  MeshRepresentationMode _representation = MeshRepresentationMode.surface;
  DataModeType _dataMode = DataModeType.pointData;
  
  MeshGPUData? _meshData;
  bool _meshUploaded = false;

  @override
  void initState() {
    super.initState();
    _initializeRenderer();
  }

  void _initializeRenderer() {
    // Convert mesh to GPU format
    _meshData = MeshConverter.convertToGPU(
      mesh: widget.foamCase.mesh,
      fieldData: widget.fieldData,
      usePointData: _dataMode == DataModeType.pointData,
      showInternalMesh: widget.showInternalMesh,
      boundaryVisibility: widget.boundaryVisibility,
    );

    if (_meshData != null) {
      _zoom = _meshData!.autoZoom;
    }
  }

  @override
  void didUpdateWidget(FoamViewerGPU oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Re-convert mesh if data changed
    if (oldWidget.fieldData != widget.fieldData ||
        oldWidget.showInternalMesh != widget.showInternalMesh ||
        oldWidget.boundaryVisibility != widget.boundaryVisibility) {
      _meshData = MeshConverter.convertToGPU(
        mesh: widget.foamCase.mesh,
        fieldData: widget.fieldData,
        usePointData: _dataMode == DataModeType.pointData,
        showInternalMesh: widget.showInternalMesh,
        boundaryVisibility: widget.boundaryVisibility,
      );
      _meshUploaded = false;
    }
  }

  @override
  void dispose() {
    _renderer?.dispose();
    super.dispose();
  }

  void _updateRenderer(Size size) {
    if (_meshData == null) return;

    final width = size.width.toInt();
    final height = size.height.toInt();

    // Create renderer if needed
    if (_renderer == null) {
      try {
        _renderer = FoamGLRenderer(width, height);
      } catch (e) {
        debugPrint('Failed to create OpenGL renderer: $e');
        return;
      }
    } else if (_renderer!.width != width || _renderer!.height != height) {
      _renderer!.resize(width, height);
    }

    // Upload mesh data once
    if (!_meshUploaded && _meshData != null) {
      _renderer!.updateMesh(
        vertices: _meshData!.vertices,
        indices: _meshData!.indices,
        colors: _meshData!.colors,
      );
      _meshUploaded = true;
    }

    // Update view parameters
    _renderer!.setView(
      rotationX: _rotationX,
      rotationY: _rotationY,
      zoom: _zoom,
      centerX: _meshData!.centerX,
      centerY: _meshData!.centerY,
      centerZ: _meshData!.centerZ,
    );

    // Update rendering mode
    _renderer!.setMode(
      representation: _getMeshRepresentation(),
      dataMode: _getDataMode(),
    );
  }

  MeshRepresentation _getMeshRepresentation() {
    switch (_representation) {
      case MeshRepresentationMode.wireframe:
        return MeshRepresentation.wireframe;
      case MeshRepresentationMode.surface:
        return MeshRepresentation.surface;
      case MeshRepresentationMode.surfaceWithEdges:
        return MeshRepresentation.surfaceWithEdges;
    }
  }

  DataMode _getDataMode() {
    switch (_dataMode) {
      case DataModeType.cellData:
        return DataMode.cellData;
      case DataModeType.pointData:
        return DataMode.pointData;
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
                  final zoomFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
                  _zoom *= zoomFactor;
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
                color: const Color(0xFF1E1E1E),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _updateRenderer(constraints.biggest);
                    
                    // Render frame
                    final textureId = _renderer?.render() ?? 0;
                    
                    if (textureId == 0 || _renderer == null) {
                      return const Center(
                        child: Text(
                          'GPU renderer not available or no mesh data',
                          style: TextStyle(color: Colors.red, fontSize: 18),
                        ),
                      );
                    }

                    // Display the rendered texture
                    return CustomPaint(
                      painter: _TextureDisplayPainter(textureId),
                      size: constraints.biggest,
                    );
                  },
                ),
              ),
            ),
          ),
          // UI Controls
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Stack(
      children: [
        // Top-right controls
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Representation mode
              _buildControlBox(
                icon: Icons.visibility,
                child: DropdownButton<MeshRepresentationMode>(
                  value: _representation,
                  underline: const SizedBox(),
                  dropdownColor: const Color(0xFF2D2D2D),
                  style: const TextStyle(fontSize: 12, color: Color(0xFFE0E0E0)),
                  icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF808080)),
                  items: const [
                    DropdownMenuItem(
                      value: MeshRepresentationMode.wireframe,
                      child: Text('Wireframe'),
                    ),
                    DropdownMenuItem(
                      value: MeshRepresentationMode.surface,
                      child: Text('Surface'),
                    ),
                    DropdownMenuItem(
                      value: MeshRepresentationMode.surfaceWithEdges,
                      child: Text('Surface + Edges'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _representation = value);
                    }
                  },
                ),
              ),
              // Data mode dropdown
              if (widget.fieldData != null) ...[
                const SizedBox(height: 8),
                _buildControlBox(
                  icon: Icons.gradient,
                  child: DropdownButton<DataModeType>(
                    value: _dataMode,
                    underline: const SizedBox(),
                    dropdownColor: const Color(0xFF2D2D2D),
                    style: const TextStyle(fontSize: 12, color: Color(0xFFE0E0E0)),
                    icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF808080)),
                    items: const [
                      DropdownMenuItem(
                        value: DataModeType.cellData,
                        child: Text('Cell Data'),
                      ),
                      DropdownMenuItem(
                        value: DataModeType.pointData,
                        child: Text('Point Data'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _dataMode = value;
                          _meshUploaded = false; // Force re-upload
                        });
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        // Color legend
        if (widget.fieldData != null)
          Positioned(
            bottom: 16,
            right: 16,
            child: _ColorLegend(fieldData: widget.fieldData!),
          ),
        // View preset buttons
        Positioned(
          right: 12,
          top: 0,
          bottom: 0,
          child: Center(
            child: _buildViewButtons(),
          ),
        ),
        // Info text
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Points: ${widget.foamCase.mesh.points.length}, '
              'Faces: ${widget.foamCase.mesh.faces.length}\n'
              'GPU Rendering: ACTIVE | Zoom: ${_zoom.toStringAsFixed(1)}',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlBox({required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF404040)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64B5F6)),
          const SizedBox(width: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildViewButtons() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF404040)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewButton(icon: Icons.arrow_upward, tooltip: 'Top View', onPressed: _setTopView),
          _ViewButton(icon: Icons.arrow_downward, tooltip: 'Bottom View', onPressed: _setBottomView),
          const Divider(height: 12, thickness: 1, color: Color(0xFF404040)),
          _ViewButton(icon: Icons.arrow_forward, tooltip: 'Front View', onPressed: _setFrontView),
          _ViewButton(icon: Icons.arrow_back, tooltip: 'Back View', onPressed: _setBackView),
          const Divider(height: 12, thickness: 1, color: Color(0xFF404040)),
          _ViewButton(icon: Icons.arrow_right_alt, tooltip: 'Right View', onPressed: _setRightView),
          _ViewButton(icon: Icons.arrow_left, tooltip: 'Left View', onPressed: _setLeftView),
          const Divider(height: 12, thickness: 1, color: Color(0xFF404040)),
          _ViewButton(icon: Icons.threed_rotation, tooltip: 'Isometric View', onPressed: _setIsometricView),
        ],
      ),
    );
  }
}

// Texture display painter (placeholder - actual implementation depends on how you expose GL textures to Flutter)
class _TextureDisplayPainter extends CustomPainter {
  final int textureId;

  _TextureDisplayPainter(this.textureId);

  @override
  void paint(Canvas canvas, Size size) {
    // Note: Displaying OpenGL textures in Flutter requires platform-specific implementation
    // This is a placeholder. You'll need to use platform channels or texture registry
    final paint = Paint()..color = const Color(0xFF1E1E1E);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    // Draw info text
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'OpenGL Texture Rendering\n(Texture integration pending)',
        style: TextStyle(color: Colors.amber, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width / 2 - 120, size.height / 2));
  }

  @override
  bool shouldRepaint(covariant _TextureDisplayPainter oldDelegate) {
    return oldDelegate.textureId != textureId;
  }
}

// Color legend widget
class _ColorLegend extends StatelessWidget {
  final FieldData fieldData;

  const _ColorLegend({required this.fieldData});

  @override
  Widget build(BuildContext context) {
    final values = fieldData.pointValues ?? fieldData.internalField;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);

    String fieldType = 'Field';
    if (fieldData.fieldClass.contains('Vector')) {
      fieldType = 'Velocity Magnitude';
    } else if (fieldData.fieldClass.contains('Scalar')) {
      fieldType = fieldData.name;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF404040)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gradient, size: 14, color: Color(0xFF64B5F6)),
              const SizedBox(width: 8),
              Text(
                fieldType,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Color(0xFFE0E0E0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: 200,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF404040)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: CustomPaint(painter: _ColorBarPainter()),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ColorMap.formatValue(minValue),
                style: const TextStyle(fontSize: 10, color: Color(0xFFB0B0B0)),
              ),
              Text(
                ColorMap.formatValue(maxValue),
                style: const TextStyle(fontSize: 10, color: Color(0xFFB0B0B0)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
      textStyle: const TextStyle(fontSize: 11, color: Colors.white),
      decoration: BoxDecoration(
        color: const Color(0xFF404040),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: const Color(0xFFB0B0B0)),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          hoverColor: const Color(0xFF404040),
        ),
      ),
    );
  }
}
