# native/CMakeLists.txt
cmake_minimum_required(VERSION 3.15)
project(foam_renderer)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(OpenGL REQUIRED)

# GLFW (you may need to install or use vcpkg/conan)
find_package(glfw3 CONFIG REQUIRED)

# GLEW (you may need to install or use vcpkg/conan)
find_package(GLEW REQUIRED)

# GLM (header-only library)
find_package(glm CONFIG REQUIRED)

# Source files
set(SOURCES
    src/foam_gl_renderer.cpp
)

# Header files
set(HEADERS
    include/foam_gl_renderer.h
)

# Create shared library
add_library(foam_renderer SHARED ${SOURCES} ${HEADERS})

# Include directories
target_include_directories(foam_renderer
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        ${OPENGL_INCLUDE_DIR}
        ${GLEW_INCLUDE_DIRS}
)

# Link libraries
target_link_libraries(foam_renderer
    PRIVATE
        ${OPENGL_LIBRARIES}
        glfw
        GLEW::GLEW
        glm::glm
)

# Platform-specific settings
if(WIN32)
    # Windows-specific settings
    set_target_properties(foam_renderer PROPERTIES
        PREFIX ""
        OUTPUT_NAME "foam_renderer"
        SUFFIX ".dll"
    )
elseif(UNIX AND NOT APPLE)
    # Linux-specific settings
    set_target_properties(foam_renderer PROPERTIES
        PREFIX "lib"
        OUTPUT_NAME "foam_renderer"
        SUFFIX ".so"
    )
elseif(APPLE)
    # macOS-specific settings
    set_target_properties(foam_renderer PROPERTIES
        PREFIX "lib"
        OUTPUT_NAME "foam_renderer"
        SUFFIX ".dylib"
    )
endif()

# Install rules
install(TARGETS foam_renderer
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)
