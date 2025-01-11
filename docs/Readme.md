# Interface

## Lifetime

### startup

Initializes a provided context.

There are a large amount of parameters to tune the library instance to the user's preference. By default, keep in mind the library defaults to utilize stb_truetype as the font parser and harfbuzz for the shaper.

Much of the data structures within the context struct are not fixed-capacity allocations so make sure that the backing allocator can handle it.

### hot_reload

The library supports being used in a dynamically loaded module. If its hot-reloaded simply make sure to call this procedure with a reference to the backing allocator provided during startup as all dynamic containers tend to lose a proper reference to the allocator's procedure.

Call `clear_atlas_region_caches` & `clear_shape_cache` to reset the library's shape and glyph cache state to force a re-render.

### shutdown

Release resources from the context.

### clear_atlas_region_caches

Clears the LRU caches of regions A-D of the Atlas & sets their next_idx to 0. Effectively will force a re-cache of all previously rendered glyphs. Shape configuration for the glyph will remain unchanged unless clear_shape_cache is also called.

### clear_shape_cache

Clears the LRU cache of the shaper along with clearing all existing storage entries. Effectively will force a re-cache of previously cached text shapes (Does not recache their rendered glyphs).

### load_font

Will load an instance of a font. The user needs to load the file's bytes themselves, the font entry (Entry :: struct) will by tracked by the library. The user will be given a font_id which is a direct index for the entry in the tracked array.

### unload_font

Will free an entry, (parser and shaper resources also freed)

## Shaping

Ideally the user should track the shapes themselves in a time-scale beyond the per-frame draw call. This avoids having to do caching/lookups of the shope.

### shape_text

Will shape the text using the `shaper_proc` arugment (user overloadable). Shape will be cached by the library.

### shape_text_uncached

Will shape the text using the `shaper_proc` arugment (user overloadable).
Shape will NOT be cached by the library. Use this if you want to roll your own solution for tracking shapes.

## Draw list generation

### get_draw_list

Get the enqueded draw_list (vertices, indices, and draw call arrays) in its entirety.
By default, if get_draw_list is called, it will first call `optimize_draw_list` to optimize the draw list's calls for the user. If this is undesired, make sure to pass `optimize_before_returning = false` in the arguments.

### get_draw_list_layer

Get the enqueued draw_list for the current "layer".
A layer is considered the slice of the `Draw_List`'s content from the last call to `flush_draw_list_layer` onward.
By default, if `get_draw_list_layer` is called, it will first call `optimize_draw_list` for the user to optimize the slice (exlusively) of the draw list's draw calls. If this is undesired, make sure to pass `optimize_before_returning = false` in the arguments.

The draw layer offsets are cleared with `flush_draw_list`

### flush_draw_list

Will clear the draw list and draw layer offsets.

### flush_draw_list_layer

Will update the draw list layer with the latest offset based on the current lenght of the draw list vertices, indices, and calls arrays.

## Metrics

### measure_shape_size

This provide's the shape size scaled down by the ctx.px_scale to get intended usage size. Size is equivalent to `measure_text_size`.

### measure_text_size

Provides a Vec2 the width and height occupied by the provided text string. The y is measured to be the the largest glyph box bounds height of the text. The width is derived from the `end_cursor_pos` field from a `Shaped_Text` entry.

### get_font_vertical_metrics

A wrapper for `parser_get_font_vertical_metrics`. Will provide the ascent, descent, and line_gap for a font entry.

## Miscellaneous

Stuff used by the draw list generation interface or just getters and setters.

### get_cursor_pos

Will provide the current cursor_pos for the resulting text drawn.

### get_normalized_position_scale

Will normalize the value of the position and scale based on the provided view.  
Position will also be snapped to the nearest pixel via ceil.  
Does nothing if view is 1 or 0

This is used by draw via view relative space procedures to normalize it to the intended space for the render pass.

### resolve_draw_px_size

Used to constrain the px_size used in `resolve_zoom_size_scale`.

The view relative space and scoping stack-based procedures support zoom. When utilizing zoom their is a nasty jitter that will occur if the user smoothly goes across different font sizes because the spacing can drastically change between even and odd font-sizes. This is applied to enforce the font sticks to a specific interval.

The library uses the context's zoom_px_interval as the reference interval in the draw procedures. It can be set with `set_zoom_px_interval` and the default value is 2.

### resolve_zoom_size_scale

Provides a way to get a "zoom" on the font size and scale, similar conceptually to a canvas UX zoom
Does nothing when zoom is 1.0

Uses `resolve_draw_px_size` to constrain which font size is used for the zoom.

### set_alpha_scalar

This is an artifact feature of the current shader, it *may* be removed in the future... Increasing the alpha of the colour draw with above 1.0 increases the edge contrast of the glyph shape.

For the value to be added to the colour, the alph of the text must already be at 1.0 or greater.

### set_px_scalar

This another "super-scalar" applied to rendering glyphs. In each draw procedure the following is computed before passing the values to the shaper and draw list generation passes:

```go
target_px_size    := px_size * ctx.px_scalar
target_scale      := scale   * (1 / ctx.px_scalar)
target_font_scale := parser_scale( entry.parser_info, target_px_size )
```

Essentially, `ctx.px_scalar` is used to upscale the px_size by its value and then downscale the render target scale back the indended size. Doing so provides better shape positioning and futher improves text hinting. The downside is that small text tends to become more jagged (as its really hitting the limits of of how well the shader can blend those edges at that resolution).

This will most likely be preserved with future shader upgrades, however it will most likely not be as necessary as it is right now to achieve crisp text.

### set_zoom_px_interval

Used with by draw procedures with `resolve_draw_px_size` & `resolve_zoom_size_scale`. Provides the interval to use when constraining the px_size to a specific set of values when using zoom scaling.

### set_snap_glyph_shape_position

During the shaping pass, the position of each glyph can be rounded up to the integer to (ussually) allow better hinting.

### set_snap_glyph_render_height

During the draw list generation pass, the position of each glyph when blitting to atlas can have teh quad size rounded up to the integer.
Can yield better hinting but may significantly stretch the glyphs at small scales.

## Scope Stack

These are a set of push & pop pairs of functions that operator ont he context's stack containers. They are used with the draw_shape and draw_text procedures. This mainly for quick scratch usage where the user wants to directly compose a large amount of text without having a UI framework directly handle the text backend.

* font
* font_size
* colour: Linear colour.
* view: Width and height of the 2D area the text will be drawn within.
* position: Uses relative positioning will offset the incoming position by the given amount.
* scale: Uses relative scaling, will scale the procedures incoming scale by the given amount.
* zoom: Affects scaling, will scale the procedure's incoming font size & scale based on an *UX canvas camera's* notion of it.

Procedure types:

* `scope_<stack_option>`: push with a defer pop
* `push_<stack_option>`
* `pop_<stack_option>`
