# Interface

## Lifetime

### startup

Initializes a provided context.

There are a large amount of parameters to tune the library instance to the user's preference. By default, keep in mind the library defaults to utilize stb_truetype as the font parser and harfbuzz for the shaper.

Much of the data structures within the context struct are not fixed-capacity allocations so make sure that the backing allocator can handle it.

### hot_reload

The library supports being used in a dynamically loaded module. If its hot-reloaded simply make sure to call this procedure with a reference to the backing allocator provided during startup as all dynamic containers tend to lose a proper reference to the allocator's procedure.

Call clear_atlas_region_caches & clear_shape_cache to reset the library's shape and glyph cache state to force a re-render.

### shutdown

Release resources from the context.

### load_font

Will load an instance of a font. The user needs to load the file's bytes themselves, the font entry (Entry :: struct) will by tracked by the library. The user will be given a font_id which is a direct index for the entry in the tracked array.

### unload_font

Will free an entry, (parser and shaper resources also freed)

## Scoping Context interface

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

## Miscellaneous

Stuff used by the draw list generation interface or just getters and setters.

### get_cursor_pos

Will provide the current cursor_pos for the resulting text drawn.

### get_normalized_position_scale

Will normalize the value of the position and scale based on the provided view.  
Position will also be snapped to the nearest pixel via ceil.  
Does nothing if view is 1 or 0

This is used by draw via view relative space procedures to normalize it to the intended space for the render pass.

## resolve_draw_px_size

Used to constrain the px_size used in draw calls.

The view relative space and scoping stack-based procedures support zoom. When utilizing zoom their is a nasty jitter that will occur if the user smoothly goes across different font sizes because the spacing can drastically change between even and odd font-sizes. This is applied to enforce the font sticks to a specific interval.

For the provided procedures that utilize it, they reference the context's zoom_px_interval. It can be set with `set_zoom_px_interval` and the default value is 2.

## resolve_zoom_size_scale



### configure_snap

You'll find this used immediately in draw_text it acts as a way to snap the position of the text to the nearest pixel for the width and height specified.

If snapping is not desired, set the snap_width and height before calling draw_text to 0.


### set_color

Sets the color to utilize on `Draw_Call`s for FrameBuffer.Target or .Target_Uncached passes

### get_draw_list

Get the enqueded draw_list (vertices, indices, and draw call arrays) in its entirety.
By default, if get_draw_list is called, it will first call `optimize_draw_list` to optimize the draw list's calls for the user. If this is undesired, make sure to pass `optimize_before_returning = false` in the arguments.

###  get_draw_list_layer

Get the enqueued draw_list for the current "layer".
A layer is considered the slice of the `Draw_List`'s content from the last call to `flush_draw_list_layer` onward.
By default, if `get_draw_list_layer` is called, it will first call `optimize_draw_list` for the user to optimize the slice (exlusively) of the draw list's draw calls. If this is undesired, make sure to pass `optimize_before_returning = false` in the arguments.

The draw layer offsets are cleared with `flush_draw_list`

### flush_draw_list

Will clear the draw list and draw layer offsets.

### flush_draw_list_layer

Will update the draw list layer with the latest offset based on the current lenght of the draw list vertices, indices, and calls arrays.

### measure_text_size

Provides a Vec2 the width and height occupied by the provided text string. The y is measured to be the the largest glyph box bounds height of the text. The width is derived from the `end_cursor_pos` field from a `Shaped_Text` entry.

### get_font_vertical_metrics

A wrapper for `parser_get_font_vertical_metrics`. Will provide the ascent, descent, and line_gap for a font entry.

### clear_atlas_region_caches

Clears the LRU caches of regions A-D of the Atlas & sets their next_idx to 0. Effectively will force a re-cache of all previously rendered glyphs. Shape configuration for the glyph will remain unchanged unless clear_shape_cache is also called.

### clear_shape_cache

Clears the LRU cache of the shaper along with clearing all existing storage entries. Effectively will force a re-cache of previously cached text shapes (Does not recache their rendered glyphs).
