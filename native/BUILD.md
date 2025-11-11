# Build Instructions for FoamRenderer Native Library

## Prerequisites

### Windows
Install dependencies using vcpkg:
```bash
vcpkg install glfw3:x64-windows glew:x64-windows glm:x64-windows
```

### Linux
Install dependencies using apt:
```bash
sudo apt-get install libglfw3-dev libglew-dev libglm-dev
```

### macOS
Install dependencies using Homebrew:
```bash
brew install glfw glew glm
```

## Building

### Windows
```bash
cd native
mkdir build
cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=[path to vcpkg]/scripts/buildsystems/vcpkg.cmake
cmake --build . --config Release
```

### Linux/macOS
```bash
cd native
mkdir build
cd build
cmake ..
make
```

## Output

The build will produce:
- Windows: `foam_renderer.dll`
- Linux: `libfoam_renderer.so`
- macOS: `libfoam_renderer.dylib`

Copy the output file to your Flutter project's root or appropriate platform directory.

## Integration with Flutter

Add the library path to your Dart code or place the library in:
- Windows: `windows/` or project root
- Linux: `linux/` or project root
- macOS: `macos/` or project root
