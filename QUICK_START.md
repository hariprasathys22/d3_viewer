# Quick Start Guide - GPU-Accelerated OpenFOAM Renderer

## Step 1: Install Dependencies

### Windows
1. Install vcpkg:
```bash
git clone https://github.com/Microsoft/vcpkg.git C:\vcpkg
cd C:\vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg integrate install
```

2. Install required packages:
```bash
vcpkg install glfw3:x64-windows glew:x64-windows glm:x64-windows
```

### Linux (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install libglfw3-dev libglew-dev libglm-dev cmake build-essential
```

### macOS
```bash
brew install glfw glew glm cmake
```

## Step 2: Build the Native Library

### Windows
```bash
cd native
build_windows.bat
```

### Linux
```bash
cd native
chmod +x build_linux.sh
./build_linux.sh
```

### macOS
```bash
cd native
chmod +x build_macos.sh
./build_macos.sh
```

The build script will automatically:
- Check dependencies
- Configure CMake
- Build the library
- Copy output to project root

## Step 3: Install Flutter Dependencies

```bash
flutter pub get
```

## Step 4: Use GPU Renderer in Your App

Replace your existing `FoamViewer` with `FoamViewerGPU`:

```dart
import 'package:d3_viewer/widgets/foam_viewer_gpu.dart';

// In your widget:
FoamViewerGPU(
  foamCase: yourOpenFoamCase,
  fieldData: yourFieldData,
  showInternalMesh: true,
  boundaryVisibility: {},
)
```

## Step 5: Run Your App

```bash
flutter run
```

## Expected Performance

| Mesh Size | CPU Renderer FPS | GPU Renderer FPS | Speedup |
|-----------|------------------|------------------|---------|
| 1K faces  | 60 FPS           | 60 FPS           | 1x      |
| 10K faces | 20-30 FPS        | 60 FPS           | 2-3x    |
| 100K faces| 2-5 FPS          | 60 FPS           | 12-30x  |
| 1M faces  | < 1 FPS          | 30-60 FPS        | 30-60x+ |

## Troubleshooting

### "DynamicLibrary.open failed"
- **Cause**: Library file not found
- **Solution**: Ensure the `.dll`/`.so`/`.dylib` file is in the project root or platform folder

### "Failed to initialize GLEW"
- **Cause**: Graphics drivers outdated or OpenGL not supported
- **Solution**: Update graphics drivers to support OpenGL 3.3+

### "No mesh data displayed"
- **Cause**: Mesh conversion issue
- **Solution**: Check that your OpenFOAM case has valid mesh data

### Performance still slow
- **Cause**: GPU renderer might not be active
- **Solution**: Check console for "GPU Rendering: ACTIVE" message

## Verify GPU Rendering is Active

Look for these indicators in your app:
1. Info panel shows "GPU Rendering: ACTIVE"
2. Smooth 60 FPS interaction even with large meshes
3. Instant camera rotation and zooming

## Fallback to CPU Renderer

If GPU renderer fails, you can fallback:

```dart
Widget build(BuildContext context) {
  try {
    return FoamViewerGPU(foamCase: foamCase);
  } catch (e) {
    return FoamViewer(foamCase: foamCase); // CPU fallback
  }
}
```

## Next Steps

- Experiment with different mesh representations (wireframe, surface, surface+edges)
- Load field data for colored visualization
- Use preset camera views for quick navigation
- Test with increasingly large meshes to see performance gains

## Need Help?

Check the detailed documentation in:
- `GPU_RENDERER_README.md` - Complete technical details
- `native/BUILD.md` - Detailed build instructions
- `INTEGRATION_EXAMPLE.dart` - Code examples
