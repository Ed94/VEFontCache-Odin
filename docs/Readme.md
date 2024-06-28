# Interface

Notes
---

Freetype implementation supports specifying a FT_Memory handle which is a pointer to a FT_MemoryRect. This can be used to define an allocator for the parser. Currently this library does not wrap this interface (yet). If using freetype its recommend to update `parser_init` with the necessary changes to wrap the context's backing allocator for freetype to utilize.

```c
  struct  FT_MemoryRec_
  {
    void*            user;
    FT_Alloc_Func    alloc;
    FT_Free_Func     free;
    FT_Realloc_Func  realloc;
  };
  ```

This library (seems) to perform best if the text commands are fed in 'whitespace aware chunks', where instead of feeding it entire blobs of text, the user identfies the "words" in the text and feeding the visible and whitespce chunks derived from this to draw_text as separate calls. This improves the caching of the text shapes. The downside is there has to be a time where the text is parsed into tokens beforehand so that the this iteration does not have to occur continously.

### startup

Initializes a provided context.

There are a large amount of parameters to tune the library instance to the user's preference. By default, keep in mind the library defaults to utilize stb_truetype as the font parser and harfbuzz (soon...) for the shaper.

Much of the data structures within the context struct are not fixed-capacity allocations so make sure that the backing allocator utilized can handle it.

### hot_reload

The library supports being used in a dynamically loaded module. If this occurs simply make sure to call this procedure with a reference to the backing allocator provided during startup as all dynamic containers tend to lose a proper reference to the allocator's procedure.

### shutdown

Release resources from the context.

### configure_snap

You'll find this used immediately in draw_text it acts as a way to snap the position of the text to the nearest pixel for the width and height specified.

If snapping is not desired, set the snap_width and height before calling draw_text to 0.

## get_cursor_pos

Will provide the current cursor_pos for the resulting text drawn.

## set_color

Sets the color to utilize on `DrawCall`s for FrameBuffer.Target or .Target_Uncached passes

### get_draw_list

Get the enqueded draw_list (vertices, indices, and draw call arrays) in its entirety.
By default, if get_draw_list is called, it will first call `optimize_draw_list` to optimize the draw list's calls for the user. If this is undesired, make sure to pass `optimize_before_returning = false` in the arguments.

###  get_draw_list_layer

Get the enqueued draw_list for the current "layer".
A layer is considered the slice of the drawlist's content from the last call to `flush_draw_list_layer` onward.
By default, if get_draw_list_layer is called, it will first call `optimize_draw_list` for the user to optimize the slice (exlusively) of the draw list's draw calls. If this is undesired, make sure to pass `optimize_before_returning = false` in the arguments.

The draw layer offsets are cleared with `flush_draw_list`

### flush_draw_list

Will clear the draw list and draw layer offsets.

### flush_draw_list_layer

Will update the draw list layer with the latest offset based on the current lenght of the draw list vertices, indices, and calls arrays.

### measure_text_size

Provides a Vec2 the width and height occupied by the provided text string. The y is measured to be the the largest glyph box bounds height of the text. The width is derived from the `end_cursor_pos` field from a `ShapedText` entry.

## get_font_vertical_metrics

A wrapper for `parser_get_font_vertical_metrics`. Will provide the ascent, descent, and line_gap for a font entry.
