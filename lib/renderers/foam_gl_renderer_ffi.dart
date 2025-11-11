// lib/renderers/foam_gl_renderer_ffi.dart

import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

// Mesh representation modes
enum MeshRepresentation {
  wireframe(0),
  surface(1),
  surfaceWithEdges(2);

  final int value;
  const MeshRepresentation(this.value);
}

// Data modes
enum DataMode {
  cellData(0),
  pointData(1);

  final int value;
  const DataMode(this.value);
}

// Load the native library
final ffi.DynamicLibrary _nativeLib = () {
  if (Platform.isWindows) {
    return ffi.DynamicLibrary.open('foam_renderer.dll');
  } else if (Platform.isLinux) {
    return ffi.DynamicLibrary.open('libfoam_renderer.so');
  } else if (Platform.isMacOS) {
    return ffi.DynamicLibrary.open('libfoam_renderer.dylib');
  } else {
    throw UnsupportedError('Unsupported platform');
  }
}();

// Native function signatures
typedef _CreateRendererNative = ffi.Pointer<ffi.Void> Function(
    ffi.Int32 width, ffi.Int32 height);
typedef _CreateRendererDart = ffi.Pointer<ffi.Void> Function(int width, int height);

typedef _DestroyRendererNative = ffi.Void Function(ffi.Pointer<ffi.Void> handle);
typedef _DestroyRendererDart = void Function(ffi.Pointer<ffi.Void> handle);

typedef _UpdateMeshNative = ffi.Void Function(
  ffi.Pointer<ffi.Void> handle,
  ffi.Pointer<ffi.Float> vertices,
  ffi.Int32 vertexCount,
  ffi.Pointer<ffi.Uint32> indices,
  ffi.Int32 indexCount,
  ffi.Pointer<ffi.Float> colors,
  ffi.Pointer<ffi.Float> cellColors,
  ffi.Int32 cellCount,
);
typedef _UpdateMeshDart = void Function(
  ffi.Pointer<ffi.Void> handle,
  ffi.Pointer<ffi.Float> vertices,
  int vertexCount,
  ffi.Pointer<ffi.Uint32> indices,
  int indexCount,
  ffi.Pointer<ffi.Float> colors,
  ffi.Pointer<ffi.Float> cellColors,
  int cellCount,
);

typedef _SetViewNative = ffi.Void Function(
  ffi.Pointer<ffi.Void> handle,
  ffi.Float rotationX,
  ffi.Float rotationY,
  ffi.Float zoom,
  ffi.Float centerX,
  ffi.Float centerY,
  ffi.Float centerZ,
);
typedef _SetViewDart = void Function(
  ffi.Pointer<ffi.Void> handle,
  double rotationX,
  double rotationY,
  double zoom,
  double centerX,
  double centerY,
  double centerZ,
);

typedef _SetModeNative = ffi.Void Function(
  ffi.Pointer<ffi.Void> handle,
  ffi.Int32 representation,
  ffi.Int32 dataMode,
);
typedef _SetModeDart = void Function(
  ffi.Pointer<ffi.Void> handle,
  int representation,
  int dataMode,
);

typedef _RenderNative = ffi.Uint32 Function(ffi.Pointer<ffi.Void> handle);
typedef _RenderDart = int Function(ffi.Pointer<ffi.Void> handle);

typedef _ResizeNative = ffi.Void Function(
    ffi.Pointer<ffi.Void> handle, ffi.Int32 width, ffi.Int32 height);
typedef _ResizeDart = void Function(ffi.Pointer<ffi.Void> handle, int width, int height);

typedef _GetTextureNative = ffi.Uint32 Function(ffi.Pointer<ffi.Void> handle);
typedef _GetTextureDart = int Function(ffi.Pointer<ffi.Void> handle);

// Bind native functions
final _createRenderer = _nativeLib
    .lookup<ffi.NativeFunction<_CreateRendererNative>>('foam_renderer_create')
    .asFunction<_CreateRendererDart>();

final _destroyRenderer = _nativeLib
    .lookup<ffi.NativeFunction<_DestroyRendererNative>>('foam_renderer_destroy')
    .asFunction<_DestroyRendererDart>();

final _updateMesh = _nativeLib
    .lookup<ffi.NativeFunction<_UpdateMeshNative>>('foam_renderer_update_mesh')
    .asFunction<_UpdateMeshDart>();

final _setView = _nativeLib
    .lookup<ffi.NativeFunction<_SetViewNative>>('foam_renderer_set_view')
    .asFunction<_SetViewDart>();

final _setMode = _nativeLib
    .lookup<ffi.NativeFunction<_SetModeNative>>('foam_renderer_set_mode')
    .asFunction<_SetModeDart>();

final _render = _nativeLib
    .lookup<ffi.NativeFunction<_RenderNative>>('foam_renderer_render')
    .asFunction<_RenderDart>();

final _resize = _nativeLib
    .lookup<ffi.NativeFunction<_ResizeNative>>('foam_renderer_resize')
    .asFunction<_ResizeDart>();

final _getTexture = _nativeLib
    .lookup<ffi.NativeFunction<_GetTextureNative>>('foam_renderer_get_texture')
    .asFunction<_GetTextureDart>();

// Dart wrapper class
class FoamGLRenderer {
  ffi.Pointer<ffi.Void>? _handle;
  int _width;
  int _height;

  FoamGLRenderer(this._width, this._height) {
    _handle = _createRenderer(_width, _height);
  }

  void dispose() {
    if (_handle != null) {
      _destroyRenderer(_handle!);
      _handle = null;
    }
  }

  void updateMesh({
    required List<double> vertices,
    required List<int> indices,
    List<double>? colors,
    List<double>? cellColors,
  }) {
    if (_handle == null) return;

    // Convert to native arrays
    final verticesPtr = malloc<ffi.Float>(vertices.length);
    for (int i = 0; i < vertices.length; i++) {
      verticesPtr[i] = vertices[i];
    }

    final indicesPtr = malloc<ffi.Uint32>(indices.length);
    for (int i = 0; i < indices.length; i++) {
      indicesPtr[i] = indices[i];
    }

    ffi.Pointer<ffi.Float> colorsPtr = ffi.nullptr;
    if (colors != null) {
      colorsPtr = malloc<ffi.Float>(colors.length);
      for (int i = 0; i < colors.length; i++) {
        colorsPtr[i] = colors[i];
      }
    }

    ffi.Pointer<ffi.Float> cellColorsPtr = ffi.nullptr;
    int cellCount = 0;
    if (cellColors != null) {
      cellCount = cellColors.length ~/ 4;
      cellColorsPtr = malloc<ffi.Float>(cellColors.length);
      for (int i = 0; i < cellColors.length; i++) {
        cellColorsPtr[i] = cellColors[i];
      }
    }

    _updateMesh(
      _handle!,
      verticesPtr,
      vertices.length ~/ 3,
      indicesPtr,
      indices.length,
      colorsPtr,
      cellColorsPtr,
      cellCount,
    );

    // Cleanup
    malloc.free(verticesPtr);
    malloc.free(indicesPtr);
    if (colorsPtr != ffi.nullptr) malloc.free(colorsPtr);
    if (cellColorsPtr != ffi.nullptr) malloc.free(cellColorsPtr);
  }

  void setView({
    required double rotationX,
    required double rotationY,
    required double zoom,
    required double centerX,
    required double centerY,
    required double centerZ,
  }) {
    if (_handle == null) return;
    _setView(_handle!, rotationX, rotationY, zoom, centerX, centerY, centerZ);
  }

  void setMode({
    required MeshRepresentation representation,
    required DataMode dataMode,
  }) {
    if (_handle == null) return;
    _setMode(_handle!, representation.value, dataMode.value);
  }

  int render() {
    if (_handle == null) return 0;
    return _render(_handle!);
  }

  void resize(int width, int height) {
    if (_handle == null) return;
    _width = width;
    _height = height;
    _resize(_handle!, width, height);
  }

  int getTexture() {
    if (_handle == null) return 0;
    return _getTexture(_handle!);
  }

  int get width => _width;
  int get height => _height;
}
