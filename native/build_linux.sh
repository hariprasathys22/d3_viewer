#!/bin/bash
# Build script for Linux

echo "===================================="
echo "Building OpenGL Renderer for Linux"
echo "===================================="

# Check dependencies
echo "Checking dependencies..."
if ! dpkg -l | grep -q libglfw3-dev; then
    echo "Installing dependencies..."
    sudo apt-get update
    sudo apt-get install -y libglfw3-dev libglew-dev libglm-dev cmake build-essential
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
make -j$(nproc)

if [ $? -ne 0 ]; then
    echo "ERROR: Build failed"
    exit 1
fi

# Copy library to project root
echo "Copying libfoam_renderer.so to project root..."
cp libfoam_renderer.so ../../libfoam_renderer.so

echo "===================================="
echo "Build completed successfully!"
echo "Output: libfoam_renderer.so"
echo "===================================="
