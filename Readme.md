# VE Font Cache : Odin Port

This is a port of the library based on [fork](https://github.com/hypernewbie/VEFontCache)

Its original purpose was for use in game engines, however its rendeirng quality and performance is more than adequate for many other applications.

See: [docs/Readme.md](docs/Readme.md) for the library's interface

## TODOs

### (Making it a more idiomatic library):

* Setup freetype, harfbuzz, depedency management within the library

### Documentation:

* Pureref outline of draw_text exectuion
* Markdown general documentation

### Content:

* Port over the original demo utilizing sokol libraries instead
* Provide a sokol_gfx backend package

### Additional Features:

* Support for freetype
* Support for harfbuzz
* Ability to set a draw transform, viewport and projection
  * By default the library's position is in unsigned normalized render space
* Allow curve_quality to be set on a per-font basis

### Optimization:

* Look into setting up multi-threading by giving each thread a context
  * There is a heavy performance bottleneck in iterating the text/shape/glyphs on the cpu (single-thread) vs the actual rendering
  * draw_text can provide in the context a job list per thread for the user to thenk hookup to their own threading solution to handle.
  * Context would need to be segregated into staged data structures for each thread to utilize
    * Each should have their own?
      * draw_list
      * draw_layer
      * atlas.next_idx
      * glyph_draw_buffer
      * shape_cache
    * This would need to converge to the singlar draw_list on a per layer basis (then user reqeusts a draw_list layer there could a yield to wait for the jobs to finish); if the interface expects the user to issue the commands single-threaded unless, we just assume the user is going to feed the gpu the commands & data through separate threads as well (not ideal ux).

Failed Attempts:

* Attempted to chunk the text to more granular 'shapes' from `draw_list` before doing the actual call to `draw_text_shape`. This lead to a larger performance cost due to the additional iteration across the text string.
* Attempted to cache the shape draw_list for future calls. Led to larger performance cost due to additional iteration in the `merge_draw_list`. 
  * The shapes glyphs must still be traversed to identify if the glyph is cached. This arguably could be handled in `shape_text_uncached`, however that would require a significan't amount of refactoring to identify... (and would be more unergonomic when shapers libs are processing the text)
