#!/bin/bash
# Build script for macOS

echo "===================================="
echo "Building OpenGL Renderer for macOS"
echo "===================================="

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "ERROR: Homebrew not found"
    echo "Please install Homebrew first:"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

# Check dependencies
echo "Checking dependencies..."
if ! brew list glfw &> /dev/null; then
    echo "Installing dependencies..."
    brew install glfw glew glm cmake
fi

# Create build directory
mkdir -p build
cd build

# Configure with CMake
echo "Configuring CMake..."
cmake ..

if [ $? -ne 0 ]; then
    echo "ERROR: CMake configuration failed"
    exit 1
fi

# Build
echo "Building..."
make -j$(sysctl -n hw.ncpu)

if [ $? -ne 0 ]; then
    echo "ERROR: Build failed"
    exit 1
fi

# Copy library to project root
echo "Copying libfoam_renderer.dylib to project root..."
cp libfoam_renderer.dylib ../../libfoam_renderer.dylib

echo "===================================="
echo "Build completed successfully!"
echo "Output: libfoam_renderer.dylib"
echo "===================================="
