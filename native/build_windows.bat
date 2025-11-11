@echo off
REM Build script for Windows using vcpkg

echo ====================================
echo Building OpenGL Renderer for Windows
echo ====================================

REM Check if vcpkg is installed
if not exist "E:\Projects\flutter\vcpkg" (
    echo ERROR: vcpkg not found at E:\Projects\flutter\vcpkg
    echo Please install vcpkg first:
    echo   git clone https://github.com/Microsoft/vcpkg.git E:\Projects\flutter\vcpkg
    echo   cd E:\Projects\flutter\vcpkg
    echo   bootstrap-vcpkg.bat
    echo   vcpkg integrate install
    pause
    exit /b 1
)

REM Check if dependencies are installed
echo Checking dependencies...
E:\vcpkg\vcpkg list glfw3:x64-windows >nul 2>&1
if errorlevel 1 (
    echo Installing dependencies via vcpkg...
    E:\vcpkg\vcpkg install glfw3:x64-windows glew:x64-windows glm:x64-windows
)

REM Create build directory
if not exist "build" mkdir build
cd build

REM Configure with CMake
echo Configuring CMake...
cmake .. -DCMAKE_TOOLCHAIN_FILE=C:\vcpkg\scripts\buildsystems\vcpkg.cmake -A x64

if errorlevel 1 (
    echo ERROR: CMake configuration failed
    pause
    exit /b 1
)

REM Build
echo Building...
cmake --build . --config Release

if errorlevel 1 (
    echo ERROR: Build failed
    pause
    exit /b 1
)

REM Copy DLL to project root
echo Copying foam_renderer.dll to project root...
copy /Y Release\foam_renderer.dll ..\..\foam_renderer.dll

echo ====================================
echo Build completed successfully!
echo Output: foam_renderer.dll
echo ====================================
pause
