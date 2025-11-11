// native/include/foam_gl_renderer.h
#ifndef FOAM_GL_RENDERER_H
#define FOAM_GL_RENDERER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle to the renderer
typedef void* FoamRendererHandle;

// Mesh representation modes
typedef enum {
    REPRESENTATION_WIREFRAME = 0,
    REPRESENTATION_SURFACE = 1,
    REPRESENTATION_SURFACE_WITH_EDGES = 2
} MeshRepresentation;

// Data modes
typedef enum {
    DATA_MODE_CELL = 0,
    DATA_MODE_POINT = 1
} DataMode;

// Initialize OpenGL renderer
FoamRendererHandle foam_renderer_create(int32_t width, int32_t height);

// Destroy renderer and cleanup resources
void foam_renderer_destroy(FoamRendererHandle handle);

// Update mesh data on GPU
void foam_renderer_update_mesh(
    FoamRendererHandle handle,
    const float* vertices,        // Vertex positions (x,y,z)
    int32_t vertex_count,
    const uint32_t* indices,      // Triangle indices
    int32_t index_count,
    const float* colors,          // Per-vertex colors (r,g,b,a) - optional
    const float* cell_colors,     // Per-cell colors (r,g,b,a) - optional
    int32_t cell_count
);

// Set camera/view parameters
void foam_renderer_set_view(
    FoamRendererHandle handle,
    float rotation_x,
    float rotation_y,
    float zoom,
    float center_x,
    float center_y,
    float center_z
);

// Set rendering mode
void foam_renderer_set_mode(
    FoamRendererHandle handle,
    MeshRepresentation representation,
    DataMode data_mode
);

// Render frame and return texture ID
uint32_t foam_renderer_render(FoamRendererHandle handle);

// Resize viewport
void foam_renderer_resize(FoamRendererHandle handle, int32_t width, int32_t height);

// Get current FBO texture ID
uint32_t foam_renderer_get_texture(FoamRendererHandle handle);

#ifdef __cplusplus
}
#endif

#endif // FOAM_GL_RENDERER_H
