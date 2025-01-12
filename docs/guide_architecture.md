# Guide: Architecture

Overview on the state of package design and codepath layout.

---

The purpose of this library to really allieviate four issues with one encapsulation:

* font parsing
* text codepoint shaping
* glyph shape triangulation
* glyph draw-list generation

Shaping text, getting metrics for the glyphs, triangulating glyphs, and anti-aliasing their render are expensive todo per frame. So anything related to that compute that may be cached, will be.

There are two cache types used:

* shape cache (`Shaped_Text_Cache.state`)
* atlas region cache (`Atlas_Region.state`)

The shape cache stores all data for a piece of text that will be utilized in a draw call that is not dependent on a specific position & scale (and is faster to lookup vs compute per draw call).  
The atlas region cache tracks what slots have glyphs rendered to the texture atlas. This essentially is caching of triangulation and super-sampling compute.

All caching uses the [LRU.odin](../vefontcache/LRU.odin)

## Codepaths

### Lifetime

The library lifetime is pretty straightfoward, you have a startup to do that should just be called sometime in your usual app start.s. From there you may either choose to manually shut it down or let the OS clean it up.

If hot-reload is desired, you just need to call hot_reload with the context's backing allocator to refresh the procedure references. After the dll has been reloaded those should be the only aspects that have been scrambled.

Usually when hot-reloading the library for tuning or major changes, you'd also want to clear the caches. So just call the clear_atlas_region_caches` & `clear_shape_cache` right after.

Ideally there should be zero dynamic allocation on a per-frame basis so long as the reserves for the dynamic containers are never exceeded. Its alright if they do as their memory locality is so large their distance in the pages to load into cpu cache won't matter, just needs to be a low incidence.

### Shaping Pass

If the user is using the library's cache, then at some point `shaper_shape_text_cached` which handles the hasing and lookup. So long as a shape is found it will not enter uncached codepath. By default this library uses `shaper_shape_harfbuzz` as the `shape_text_uncached` procedure.

Shapes are cached using the following parameters to hash a key:

* font: Font_ID
* font_size: f32
* the text itself: string

All shapers fullfill the following interface:

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

Which will resolve the output `Shaped_Text`. Which has the following structure:

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

What is actually the result of the shaping process is the arrays of glyphs and their positions for the the shape or most historically known as: *Slug*, of prepared text for printing. The end position of where the user's "cursor" would be is also recorded which provided the end position of the shape. The size of the shape is also resolved here, which if using px_scalar must be downscaled. `measure_shape_size` does the downscaling for the user.

`visible` tracks which of the glyphs will actually be relevant for the draw_list pass. This is to avoid a conditional jump during the draw list gen pass. When accessing glyph or position during the draw_list gen, they will use visible's relative index.

The font and px_size is tracked here as well so they user does not need to provide it to the library's interface and related.

As stated under the main heading of this guide, the the following are within shaped text so that they may be resolved outside of the draw list generation (see: `generate_shape_draw_list`):

* atlas_lru_code
* region_kind
* bounds

They're arrays are the same length as `visible`, so indexing those will not need to use visibile's relative index.

`shaper_shape_text_latin` does naive shaping by utilizing the codepoint's kern_advance and detecting newlines.

`shaper_shape_harfbuzz` is an actual shaping *engine*. Here is the general idea of how the library utilizes it for shaping:

1. Reset the state of the hb_buffer
2. Determine the line height
3. Go through the codepoints: (for each)
    1. Determine the codepoint's script
    2. If the script is netural (Uknown, Inherited, or of Common type), or the script has not changed, or this is the first codepoint of the shape we can add the codepoint to the buffer.
    3. Otherwise we may have to start a shaping run if we do encounter a significant script change. After we can add the codepoint to the post-run-cleared hb_buffer.
    4. This continues until all codepoints have been processed.
4. We do a final shape run after iterating to make sure all codepoints have been processed.
5. Set the size of the shape: x is max line width, y is line height multiplied by the line count.
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

There is consideration to instead explicitly have a draw list with more contextual information of the start and end of each layer. So that batching can be orchestrated in a section of their pipline.

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
