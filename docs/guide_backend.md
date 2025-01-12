# Backend Guide

The end-user needs to adapt this library to hook into their own codebase. For reference, they can check the [examples](../examples/) and [backend](../backend/) directories for working code that demonstrates what this guide covers.

When rendering text, users need to handle two main aspects: the text to draw and its "layering". Similar to UIs, text should be drawn in layer batches, where each layer can represent a pass with arbitrary distinctions from other layers.

The following components are required:

* Vertex and Index Buffers for glyph meshes
* Glyph shader for rendering glyphs to the glyph buffer
* Atlas shader for blitting upscaled glyph quads from the glyph buffer to an atlas region slot (downsampled)
* "Screen or Target" shader for blitting glyph quads from the atlas to a render target or swapchain
* The glyph, atlas, and target image buffers

Currently, the library doesn't support sub-pixel AA, so we're only rendering to R8 images.

## Rendering Passes

There are four passes that need to be handled when rendering a draw list:

* Glyph: Rendering a glyph mesh to the glyph buffer
* Atlas: Blitting a glyph quad from the glyph buffer to an atlas slot
* Target: Blitting from the atlas image to the target image
* Target_Uncached: Blitting from the glyph buffer image to the target image

The Target & Target_Uncached passes can technically be handled in the same case. The user just needs to swap between using the atlas image and the glyph buffer image. This is how the backend_soko.odin's `render_text_layer` has these passes set up.

## Vertex Buffer Layout

The vertex buffer has the following layout for all passes:

* `[2]f32` for positions
* `[2]f32` for texture coords (Offset is naturally `[2]f32`)
* Total stride: `[4]f32`

---

The index buffer is a simple u32 stream.

For quad mesh layout details, see `blit_quad` in [draw.odin](../vefontcache/draw.odin).

For glyph shape triangulation meshes, the library currently only uses a triangle fanning technique, implemented in `fill_path_via_fan_triangulation` within [draw.odin](../vefontcache/draw.odin). Eventually, the library will support other modes on a per-font basis.

## UV Coordinate Conventions (GLSL vs HLSL)

DirectX, Metal, and Vulkan consider the top-left corner as (0, 0), where the Y axis increases downward (traditional screenspace). This library follows OpenGL's convention, where (0, 0) is at the bottom-left (Y goes up).

Adjust the UV coordinates in your shader accordingly:

```c
#if !OpenGL
uv = vec2(v_texture.x, 1.0 - v_texture.y);
#else
uv = vec2(v_texture.x, v_texture.y);
#endif
```

Eventually, the library will support both conventions as a comp-time conditional.

## Retrieving & Processing the layer

`get_draw_list_layer` will provide the layer's vertex, index, and draw call slices. Unless the default is overwritten, it will call `optimize_draw_list` before returning the slices (profile to see whats better for your use case).  
Once those are retrived, call `flush_draw_list_layer` to update the layer offsets tracked by the library's `Context`.

The vertex and index slices just needed to be appended to your backend's vertex and index buffers.  
The draw calls need to be iterated with a switch statement for the aforementioned pass types. Within the case you can construct the enqueue the passes.

---
