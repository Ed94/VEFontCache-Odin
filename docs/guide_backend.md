# Backend Guide

The end-user needs adapt this library for hookup into their own codebase. As an example they may see the [examples](../examples/) and [backend](../backend/) for working code of what this guide will go over.

When rendering text, the two products the user has to deal with: The text to draw and their "layering". Similar to UIs text should be drawn in layer batches, where each layer can represent a pass on some arbitrary set of distictions between the other layers.

The following are generally needed:

* Vertex and Index Buffers for glyph meshes
* Glyph shader for rendering the glyph to the glyph buffer
* Atlas shader for blitting the upscaled glyph quads from the glyph buffer to an atlas region slot downsampled.
* "Screen or Target" shader for blitting glyph quads from the atlas to a render target or swapchain
* The glyph, atlas, and some "target" image buffers

Currently the library doesn't support sub-pixel AA so we're just rendering to R8 images.

## There are four passes that need to be handled when rendering a draw list

* Glyph: Rendering a glyph mesh to the glyph buffer
* Atlas: Blitting a glyph quad from the glyph buffer to an atlas slot
* Target: Blit from the atlas image to the target image
* Target_Uncached: Blit from the glyph buffer image to the target image

The Target & Target_Uncached passes can technically be handled in the same case. The user just needs to swap out using the atlas image with the glyph buffer image. This is how the backend_soko.odin's `render_text_layer` has those passes setup.

## The vertex buffer will have the following alyout for all passes

`[2]f32` for positions  
`[2]f32` for texture coords (Offset is naturally `[2]f32`)  
With a total stride of `[4]f32`

---

The index buffer is just a u32 stream.

For how a quad mesh is laid out see `blit_quad` in [draw.odin](../vefontcache/draw.odin)

For how glyph shape triangulation meshes, the library currently only uses a triangle fanning technique so `fill_path_via_fan_triangulation` within [draw.odin](../vefontcache/draw.odin) is where that is being done. Eventually the libary will also support other modes on a per-font basis.

## Keep in mind GLSL vs HLSL UV (texture) coordinate convention

The UV coordinates used DirectX, Metal, and Vulkan all consider the top-left corner (0, 0), Where the Y axis increases downwards (traditional screenspace). This library follows the convention of (0, 0) being at the bottom-left (Y goes up) which is what OpenGL uses.

In the shader the UV just has to be adjusted accordingly:

```c
#if ! OpenGL
uv = vec2( v_texture.x, 1.0 - v_texture.y );
#else
uv = vec2( v_texture.x, v_texture.y );
#endif
```
