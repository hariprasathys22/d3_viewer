// native/src/foam_gl_renderer.cpp
#include "foam_gl_renderer.h"
#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <vector>
#include <string>
#include <iostream>
#include <cmath>

// Vertex shader source
const char* vertex_shader_source = R"(
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec4 aColor;

out vec4 vertexColor;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main() {
    gl_Position = projection * view * model * vec4(aPos, 1.0);
    vertexColor = aColor;
}
)";

// Fragment shader source
const char* fragment_shader_source = R"(
#version 330 core
in vec4 vertexColor;
out vec4 FragColor;

void main() {
    FragColor = vertexColor;
}
)";

// Edge shader (for wireframe)
const char* edge_vertex_shader = R"(
#version 330 core
layout (location = 0) in vec3 aPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main() {
    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
)";

const char* edge_fragment_shader = R"(
#version 330 core
out vec4 FragColor;

uniform vec4 edgeColor;

void main() {
    FragColor = edgeColor;
}
)";

// Renderer class
class FoamRenderer {
public:
    GLFWwindow* window;
    int width, height;
    
    // Shader programs
    GLuint surface_shader;
    GLuint edge_shader;
    
    // Vertex Array Objects and Buffers
    GLuint surface_vao, surface_vbo, surface_ebo, surface_color_vbo;
    GLuint edge_vao, edge_vbo, edge_ebo;
    
    // Framebuffer for offscreen rendering
    GLuint fbo, texture, rbo;
    
    // Mesh data
    std::vector<float> vertices;
    std::vector<uint32_t> indices;
    std::vector<float> vertex_colors;
    std::vector<float> cell_colors;
    int32_t vertex_count = 0;
    int32_t index_count = 0;
    int32_t cell_count = 0;
    
    // View parameters
    float rotation_x = 0.3f;
    float rotation_y = 0.3f;
    float zoom = 500.0f;
    glm::vec3 mesh_center = glm::vec3(0.0f);
    
    // Rendering mode
    MeshRepresentation representation = REPRESENTATION_SURFACE;
    DataMode data_mode = DATA_MODE_POINT;
    
    FoamRenderer(int32_t w, int32_t h) : width(w), height(h) {
        // Initialize GLFW (hidden window for offscreen rendering)
        if (!glfwInit()) {
            std::cerr << "Failed to initialize GLFW" << std::endl;
            return;
        }
        
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
        glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE); // Hidden window
        
        window = glfwCreateWindow(width, height, "FoamRenderer", nullptr, nullptr);
        if (!window) {
            std::cerr << "Failed to create GLFW window" << std::endl;
            glfwTerminate();
            return;
        }
        
        glfwMakeContextCurrent(window);
        
        // Initialize GLEW
        glewExperimental = GL_TRUE;
        if (glewInit() != GLEW_OK) {
            std::cerr << "Failed to initialize GLEW" << std::endl;
            return;
        }
        
        // Create shaders
        surface_shader = create_shader_program(vertex_shader_source, fragment_shader_source);
        edge_shader = create_shader_program(edge_vertex_shader, edge_fragment_shader);
        
        // Create VAOs and VBOs
        glGenVertexArrays(1, &surface_vao);
        glGenBuffers(1, &surface_vbo);
        glGenBuffers(1, &surface_ebo);
        glGenBuffers(1, &surface_color_vbo);
        
        glGenVertexArrays(1, &edge_vao);
        glGenBuffers(1, &edge_vbo);
        glGenBuffers(1, &edge_ebo);
        
        // Create framebuffer for offscreen rendering
        create_framebuffer(width, height);
        
        // Enable depth test
        glEnable(GL_DEPTH_TEST);
        glDepthFunc(GL_LESS);
        
        // Enable blending
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }
    
    ~FoamRenderer() {
        // Cleanup
        glDeleteVertexArrays(1, &surface_vao);
        glDeleteBuffers(1, &surface_vbo);
        glDeleteBuffers(1, &surface_ebo);
        glDeleteBuffers(1, &surface_color_vbo);
        
        glDeleteVertexArrays(1, &edge_vao);
        glDeleteBuffers(1, &edge_vbo);
        glDeleteBuffers(1, &edge_ebo);
        
        glDeleteFramebuffers(1, &fbo);
        glDeleteTextures(1, &texture);
        glDeleteRenderbuffers(1, &rbo);
        
        glDeleteProgram(surface_shader);
        glDeleteProgram(edge_shader);
        
        if (window) {
            glfwDestroyWindow(window);
        }
        glfwTerminate();
    }
    
    void create_framebuffer(int w, int h) {
        // Delete old framebuffer if exists
        if (fbo) {
            glDeleteFramebuffers(1, &fbo);
            glDeleteTextures(1, &texture);
            glDeleteRenderbuffers(1, &rbo);
        }
        
        // Create framebuffer
        glGenFramebuffers(1, &fbo);
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);
        
        // Create texture for color attachment
        glGenTextures(1, &texture);
        glBindTexture(GL_TEXTURE_2D, texture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
        
        // Create renderbuffer for depth and stencil
        glGenRenderbuffers(1, &rbo);
        glBindRenderbuffer(GL_RENDERBUFFER, rbo);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, w, h);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, rbo);
        
        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            std::cerr << "Framebuffer is not complete!" << std::endl;
        }
        
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }
    
    GLuint create_shader_program(const char* vs_source, const char* fs_source) {
        // Compile vertex shader
        GLuint vertex_shader = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(vertex_shader, 1, &vs_source, nullptr);
        glCompileShader(vertex_shader);
        check_shader_compile(vertex_shader, "VERTEX");
        
        // Compile fragment shader
        GLuint fragment_shader = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(fragment_shader, 1, &fs_source, nullptr);
        glCompileShader(fragment_shader);
        check_shader_compile(fragment_shader, "FRAGMENT");
        
        // Link program
        GLuint program = glCreateProgram();
        glAttachShader(program, vertex_shader);
        glAttachShader(program, fragment_shader);
        glLinkProgram(program);
        check_program_link(program);
        
        glDeleteShader(vertex_shader);
        glDeleteShader(fragment_shader);
        
        return program;
    }
    
    void check_shader_compile(GLuint shader, const char* type) {
        GLint success;
        GLchar info_log[1024];
        glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
        if (!success) {
            glGetShaderInfoLog(shader, 1024, nullptr, info_log);
            std::cerr << "Shader compilation error (" << type << "): " << info_log << std::endl;
        }
    }
    
    void check_program_link(GLuint program) {
        GLint success;
        GLchar info_log[1024];
        glGetProgramiv(program, GL_LINK_STATUS, &success);
        if (!success) {
            glGetProgramInfoLog(program, 1024, nullptr, info_log);
            std::cerr << "Program linking error: " << info_log << std::endl;
        }
    }
    
    void update_mesh_data(
        const float* verts, int32_t vert_count,
        const uint32_t* inds, int32_t ind_count,
        const float* colors, const float* c_colors, int32_t c_count
    ) {
        vertex_count = vert_count;
        index_count = ind_count;
        cell_count = c_count;
        
        // Copy vertex data
        vertices.assign(verts, verts + vert_count * 3);
        indices.assign(inds, inds + ind_count);
        
        if (colors) {
            vertex_colors.assign(colors, colors + vert_count * 4);
        } else {
            // Default white color
            vertex_colors.resize(vert_count * 4);
            for (int i = 0; i < vert_count; i++) {
                vertex_colors[i * 4 + 0] = 0.5f;
                vertex_colors[i * 4 + 1] = 0.7f;
                vertex_colors[i * 4 + 2] = 1.0f;
                vertex_colors[i * 4 + 3] = 1.0f;
            }
        }
        
        if (c_colors) {
            cell_colors.assign(c_colors, c_colors + c_count * 4);
        }
        
        // Upload to GPU
        upload_mesh_to_gpu();
    }
    
    void upload_mesh_to_gpu() {
        // Bind surface VAO
        glBindVertexArray(surface_vao);
        
        // Upload vertex positions
        glBindBuffer(GL_ARRAY_BUFFER, surface_vbo);
        glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), vertices.data(), GL_STATIC_DRAW);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
        glEnableVertexAttribArray(0);
        
        // Upload vertex colors
        glBindBuffer(GL_ARRAY_BUFFER, surface_color_vbo);
        glBufferData(GL_ARRAY_BUFFER, vertex_colors.size() * sizeof(float), vertex_colors.data(), GL_STATIC_DRAW);
        glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
        glEnableVertexAttribArray(1);
        
        // Upload indices
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, surface_ebo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(uint32_t), indices.data(), GL_STATIC_DRAW);
        
        glBindVertexArray(0);
        
        // Edge rendering setup (same geometry)
        glBindVertexArray(edge_vao);
        
        glBindBuffer(GL_ARRAY_BUFFER, edge_vbo);
        glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), vertices.data(), GL_STATIC_DRAW);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
        glEnableVertexAttribArray(0);
        
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, edge_ebo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(uint32_t), indices.data(), GL_STATIC_DRAW);
        
        glBindVertexArray(0);
    }
    
    uint32_t render() {
        glfwMakeContextCurrent(window);
        
        // Bind framebuffer
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);
        glViewport(0, 0, width, height);
        
        // Clear
        glClearColor(0.117f, 0.117f, 0.117f, 1.0f); // Dark background
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        if (vertex_count == 0 || index_count == 0) {
            glBindFramebuffer(GL_FRAMEBUFFER, 0);
            return texture;
        }
        
        // Setup matrices
        glm::mat4 model = glm::mat4(1.0f);
        model = glm::translate(model, -mesh_center);
        model = glm::rotate(model, rotation_y, glm::vec3(0.0f, 1.0f, 0.0f));
        model = glm::rotate(model, rotation_x, glm::vec3(1.0f, 0.0f, 0.0f));
        
        glm::mat4 view = glm::mat4(1.0f);
        view = glm::translate(view, glm::vec3(0.0f, 0.0f, -zoom));
        
        float aspect = (float)width / (float)height;
        glm::mat4 projection = glm::perspective(glm::radians(45.0f), aspect, 0.1f, 10000.0f);
        
        // Render surface
        if (representation == REPRESENTATION_SURFACE || representation == REPRESENTATION_SURFACE_WITH_EDGES) {
            glUseProgram(surface_shader);
            
            GLuint model_loc = glGetUniformLocation(surface_shader, "model");
            GLuint view_loc = glGetUniformLocation(surface_shader, "view");
            GLuint proj_loc = glGetUniformLocation(surface_shader, "projection");
            
            glUniformMatrix4fv(model_loc, 1, GL_FALSE, glm::value_ptr(model));
            glUniformMatrix4fv(view_loc, 1, GL_FALSE, glm::value_ptr(view));
            glUniformMatrix4fv(proj_loc, 1, GL_FALSE, glm::value_ptr(projection));
            
            glBindVertexArray(surface_vao);
            glDrawElements(GL_TRIANGLES, index_count, GL_UNSIGNED_INT, 0);
        }
        
        // Render edges
        if (representation == REPRESENTATION_WIREFRAME || representation == REPRESENTATION_SURFACE_WITH_EDGES) {
            glUseProgram(edge_shader);
            
            GLuint model_loc = glGetUniformLocation(edge_shader, "model");
            GLuint view_loc = glGetUniformLocation(edge_shader, "view");
            GLuint proj_loc = glGetUniformLocation(edge_shader, "projection");
            GLuint color_loc = glGetUniformLocation(edge_shader, "edgeColor");
            
            glUniformMatrix4fv(model_loc, 1, GL_FALSE, glm::value_ptr(model));
            glUniformMatrix4fv(view_loc, 1, GL_FALSE, glm::value_ptr(view));
            glUniformMatrix4fv(proj_loc, 1, GL_FALSE, glm::value_ptr(projection));
            
            if (representation == REPRESENTATION_WIREFRAME) {
                glUniform4f(color_loc, 0.25f, 0.5f, 1.0f, 1.0f); // Blue
            } else {
                glUniform4f(color_loc, 0.0f, 0.0f, 0.0f, 0.3f); // Semi-transparent black
            }
            
            glBindVertexArray(edge_vao);
            glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
            glDrawElements(GL_TRIANGLES, index_count, GL_UNSIGNED_INT, 0);
            glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
        }
        
        glBindVertexArray(0);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        
        return texture;
    }
    
    void resize(int32_t w, int32_t h) {
        width = w;
        height = h;
        create_framebuffer(w, h);
    }
};

// C API implementation
extern "C" {

FoamRendererHandle foam_renderer_create(int32_t width, int32_t height) {
    return new FoamRenderer(width, height);
}

void foam_renderer_destroy(FoamRendererHandle handle) {
    if (handle) {
        delete static_cast<FoamRenderer*>(handle);
    }
}

void foam_renderer_update_mesh(
    FoamRendererHandle handle,
    const float* vertices,
    int32_t vertex_count,
    const uint32_t* indices,
    int32_t index_count,
    const float* colors,
    const float* cell_colors,
    int32_t cell_count
) {
    if (handle) {
        auto* renderer = static_cast<FoamRenderer*>(handle);
        renderer->update_mesh_data(vertices, vertex_count, indices, index_count, colors, cell_colors, cell_count);
    }
}

void foam_renderer_set_view(
    FoamRendererHandle handle,
    float rotation_x,
    float rotation_y,
    float zoom,
    float center_x,
    float center_y,
    float center_z
) {
    if (handle) {
        auto* renderer = static_cast<FoamRenderer*>(handle);
        renderer->rotation_x = rotation_x;
        renderer->rotation_y = rotation_y;
        renderer->zoom = zoom;
        renderer->mesh_center = glm::vec3(center_x, center_y, center_z);
    }
}

void foam_renderer_set_mode(
    FoamRendererHandle handle,
    MeshRepresentation representation,
    DataMode data_mode
) {
    if (handle) {
        auto* renderer = static_cast<FoamRenderer*>(handle);
        renderer->representation = representation;
        renderer->data_mode = data_mode;
    }
}

uint32_t foam_renderer_render(FoamRendererHandle handle) {
    if (handle) {
        auto* renderer = static_cast<FoamRenderer*>(handle);
        return renderer->render();
    }
    return 0;
}

void foam_renderer_resize(FoamRendererHandle handle, int32_t width, int32_t height) {
    if (handle) {
        auto* renderer = static_cast<FoamRenderer*>(handle);
        renderer->resize(width, height);
    }
}

uint32_t foam_renderer_get_texture(FoamRendererHandle handle) {
    if (handle) {
        auto* renderer = static_cast<FoamRenderer*>(handle);
        return renderer->texture;
    }
    return 0;
}

} // extern "C"
