# Guide: Architecture

Overview of the package design and code-path layout.

---

The purpose of this library is to alleviate four key challenges with one encapsulating package:

* Font parsing
* Text codepoint shaping
* Glyph shape triangulation
* Glyph draw-list generation

Shaping text, getting metrics for glyphs, triangulating glyphs, and anti-aliasing their render are expensive operations to perform per frame. Therefore, any compute operations that can be cached, will be.

There are two cache types used:

* Shape cache (`Shaped_Text_Cache.state`)
* Atlas region cache (`Atlas_Region.state`)

The shape cache stores all data for a piece of text that will be utilized in a draw call that is not dependent on a specific position & scale (and is faster to lookup vs compute per draw call).  
The atlas region cache tracks what slots have glyphs rendered to the texture atlas. This essentially caches triangulation and super-sampling computations.

All caching uses [LRU.odin](../vefontcache/LRU.odin)

## Code Paths

### Lifetime

The library lifetime is straightforward: you have a startup procedure that should be called during your usual app initialization. From there you may either choose to manually shut it down or let the OS clean it up.

If hot-reload is desired, you just need to call hot_reload with the context's backing allocator to refresh the procedure references. After the DLL has been reloaded, these should be the only aspects that have been scrambled.  
Usually when hot-reloading the library for tuning or major changes, you'd also want to clear the caches. Simply call `clear_atlas_region_caches` & `clear_shape_cache` right after.

Ideally, there should be zero dynamic allocation on a per-frame basis as long as the reserves for the dynamic containers are never exceeded. It's acceptable if they do exceed as their memory locality is so large their distance in the pages to load into CPU cache won't matter - it just needs to be a low incidence.

### Shaping Pass

If using the library's cache, `shaper_shape_text_cached` handles the hashing and lookup. As long as a shape is found, it will not enter the uncached code path. By default, this library uses `shaper_shape_harfbuzz` as the `shape_text_uncached` procedure.

Shapes are cached using the following parameters to hash a key:

* font: Font_ID
* font_size: f32
* the text itself: string

All shapers fulfill the following interface:

```odin
Shaper_Shape_Text_Uncached_Proc :: #type proc( ctx : ^Shaper_Context,
    atlas             : Atlas, 
    glyph_buffer_size : Vec2,
    font              : Font_ID,
    entry             : Entry, 
    font_px_Size      : f32, 
    font_scale        : f32, 
    text_utf8         : string, 
    output            : ^Shaped_Text 
)
```

Which will resolve the output `Shaped_Text`. It has the following definition:

```odin
Shaped_Text :: struct #packed {
    glyph          : [dynamic]Glyph,
    position       : [dynamic]Vec2,
    visible        : [dynamic]i16,
    atlas_lru_code : [dynamic]Atlas_Key,
    region_kind    : [dynamic]Atlas_Region_Kind,
    bounds         : [dynamic]Range2,
    end_cursor_pos : Vec2,
    size           : Vec2,
    font           : Font_ID, 
    px_size        : f32,
}
```

The result of the shaping process is the glyphs and their positions for the the shape; historically resembling whats known as a *Slug* of prepared text for printing. The end position of where the user's "cursor" would be is also recorded which provided the end position of the shape. The size of the shape is also resolved here, which if using px_scalar must be downscaled. `measure_shape_size` does the downscaling for the user.

`visible` tracks which of the glyphs will actually be relevant for the draw_list pass. This is to avoid a conditional jump during the draw list gen pass. When accessing glyph or position during the draw_list gen, they will use visible's relative index.

The font and px_size is tracked here as well so they user does not need to provide it to the library's interface and related.

As stated under the main heading of this guide, the the following are within shaped text so that they may be resolved outside of the draw list generation (see: `generate_shape_draw_list`):

* atlas_lru_code
* region_kind
* bounds

These are the same length as the `visible` array, so indexing those will not need to use visibile's relative index.

`shaper_shape_text_latin` does naive shaping by utilizing the codepoint's kern_advance and detecting newlines.  
`shaper_shape_harfbuzz` is an actual shaping *engine*. Here is the general idea of how the library utilizes it for shaping:

1. Reset the state of the hb_buffer
2. Determine the line height
3. Go through the codepoints: (for each)
    1. Determine the codepoint's script
    2. If the script is netural (Uknown, Inherited, or of Common type), the script has not changed, or this is the first codepoint of the shape we can add the codepoint to the buffer.
    3. Otherwise we will have to start a shaping run if we do encounter a significant script change. After, we can add the codepoint to the post-run-cleared hb_buffer.
    4. This continues until all codepoints have been processed.
4. We do a final shape run after iterating to make sure all codepoints have been processed.
5. Set the size of the shape: X is max line width, Y is line height multiplied by the line count.
6. Resolve the atlas_lru_code, region_kind, and bounds for all visible glyphs
7. Store the font and px_size information.

The `shape_run` procedure within does the following:

1. Setup the buffer for the batch
2. Have harfbuzz shape the buffer
3. Extract glyph infos and positions from the buffer.
4. Iterate through all glyphs
    1. If the hb_glyph cluster is > 0, we need to treat it as the indication of a newline glyph. ***(We update position and skip)***
    2. Update positioning and other metrics and append output shape's glyph and position.
    3. If the glyph is visible we append it to shape's visible (harfbuzz must specify it as not .nodef, and parser must identify it as non-empty)
5. We update the output.end_cursor_pos with the last position processed by the iteration
6. Clear the hb_buffer's contents to prepare for a possible upcoming shape run.

**Note on shape_run.4: The iteration doesn't preserve tracking the clusters, so that information is lost.**  
*In the future cluster tracking may be added if its found to be important for high level text features beyond rendering.*

**Note on shape_run.4.1: Don't know if the glyph signifiying newline should be preserved**  

See [Harfbuzz documentation](https://harfbuzz.github.io) for additional information.

There are other shapers out there:

* [hamza](https://github.com/saidwho12/hamza): A notable C library that could be setup with bindings.

***Note: Monospace fonts may have a much more trivial shaper (however for fonts with ligatures this may not be the case)***  
***They should only need the kern advance of a single glyph as they're all the same. ligatures (I believe) should preserve this kern advance.***

### Draw List Generation

All interface draw text procedures will ultimately call `generate_shape_draw_list`. If the draw procedure is given text, it will call `shaper_shape_text_cached` the text immediately before calling it.

Its implementation uses a batched-pipeline approach where its goal is to populate three arrays behavings as queues:  

* oversized: For drawing oversized glyphs
* to_cache: For glyphs that need triangulation & rendering to glyph buffer then blitting to atlas.
* cache: For glyphs that are already cached in the atlas and just need to be blit to the render target.

And then sent those off to `batch_generate_glyphs_draw_list` for further actual generation to be done. The size of a batch is determined by the capacity of the glyph_buffer's `batch_cache`. This can be set in `glyph_draw_params` for startup.

`glyph_buffer.glyph_pack` is utilized by both `generate_shape_draw_list` and `batch_generate_glyphs_draw_list` to various computed data in an SOA data structure for the glyphs.

generate_shape_draw_list outline:

1. Prepare glyph_pack, oversized, to_cache, cached, and reset the batch cache
    * `glyph_pack` is resized to to the length of `shape.visible`
    * The other arrays populated have their reserved set to that length as well (they will not bounds check capacity on append)
2. Iterate through the shape.visible and resolve glyph_pack's positions.
3. Iterate through shape.visible this time for final region resolution and segregation of glyphs to their appropriate queue.
    1. If the glyphs assigned region is `.E` its oversized. The `oversample` used for rendering to render target will either be 2x or 1x depending on how huge it is.
    2. The following glyphs are checked to see if their assigned region has the glyph `cached`.
        1. If it does, its just appended to cached and marked as seen in the `batch_cache`.
        2. If its doesn't then a slot is reserved for within the atlas's region and the glyph is appended to `to_cache`.
        3. For either case the atlas_region_bbox is computed.
    3. After a batch has been resolved, `batch_generate_glyphs_draw_list` is called.
4. If there is an partially filled batch (the usual case), batch_generate_glyphs_draw_list will be called for it.
5. The cursor_pos is updated with the shape's end cursor position adjusted for the target space.

batch_generate_glyphs_draw_list outline:

The batch is organized into three major stages:

1. glyph transform & draw quads compute
2. glyph_buffer draw list generation (`oversized` & `to_cache`)
3. blit-from-atlas to render target draw list generation (`to_cache` & `cached`)

Glyph transform & draw quads compute does an iteration for each of the 3 arrays.  
Nearly all the math for all three is done there *except* for `to_cache`, which does its blitting compute in its glyph_buffer draw-list gen pass.

glyph_buffer draw list generation paths for `oversized` and `to_cache` are unique to each.

For `oversized`:

1. Allocate glyph shapes
2. Iterate oversized:
    1. Flush the glyph buffer if flagged todo so (reached glyph allocation limit)
    2. Call `generate_glyph_pass_draw_list` for trianglation and rendering to buffer.
    3. blit quad.
3. flush the glyph buffer's draw list.
4. free glyph shapes

For `to_cached`:

1. Allocate glyph shapes
2. Iterate to_cache:
    1. Flush the glyph buffer if flagged todo so (reached glyph allocation limit)
    2. Compute & blit quads for clearing the atlas region and blitting from the buffer to the atlas.
    3. Call `generate_glyph_pass_draw_list` for trianglation and rendering to buffer.
3. flush the glyph buffer's draw list.
4. free glyph shapes
5. Do blits from atlas to draw list.

`cached` only needs to blit from the atlas to the render target.

`generate_glyph_pass_draw_list`: sets up the draw call for glyph to the glyph buffer. Currently it also handles triangulation as well. For now the shape triangulation is rudimentary and uses triangle fanning. Eventually it would be nice to offer alternative modes that can be specified on a per-font basis.

`flush_glyph_buffer_draw_list`: Will merge the draw_lists contents of the glyph buffer over to the library's general draw_list, the clear the buffer's draw lists.

### On Layering

The base draw list generation pippline provided by the library allows the user to batch whatever the want into a single "layer".
However, the user most likely would want take into consideration: font instances, font size, colors; these are things that may benefit from having shared locality during a layer batch. Overlaping text benefits from the user to handle the ordering via layers.

Layers (so far) are just a set of offssets tracked by the library's `Context.draw_layer` struct. When `flush_draw_list_layer` is called, the offsets are set to the current leng of the draw list. This allows the rendering backend to retrieve the latest set of vertices, indices, and calls to render on a per-layer basis with: `get_draw_list_layer`.

Importantly, this leads to the following pattern when enuquing a layer to render:

1. Begin render pass
2. For codepath that will deal with text layers
    1. Process user-level code-path that calls the draw text interface, populating the draw list layer (usually a for loop)
    2. After iteration on the layer is complete render the text layer
        1. grab the draw list layer
        2. flush the layer so the draw list offsets are reset
    3. Repeat until all layers for the codepath are exhausted.

There is consideration to instead explicitly have a draw list with more contextual information of the start and end of each layer. So that batching can be orchestrated in an isolated section of their pipline.

This would involve just tracking *slices* of thier draw-list that represents layers:

```odin
Draw_List_Layer :: struct {
    vertices : []Vertex,
    indices  : []u32,
    calls    : []Draw_Call,
}
```

Eventually the library may provide this since adding that feature is relatively cheap and and a low line-count addition to the interface.
There should be little to no perfomrance loss from doing so as the iteration size is two large of a surface area to matter (so its just pipeline ergonomics)
