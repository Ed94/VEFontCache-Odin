# VE Font Cache : Odin Port

This is a port of the [VEFontCache](https://github.com/hypernewbie/VEFontCache) library.

Its original purpose was for use in game engines, however its rendeirng quality and performance is more than adequate for many other applications.

See: [docs/Readme.md](docs/Readme.md) for the library's interface

## Building

See [scripts/Readme.md](scripts/Readme.md) for building examples or utilizing the provided backends.

Currently the scripts provided & the library itself where developed & tested on Windows. The library itself should not be limited to that OS platform however, just don't have the configuration setup for alternative platforms (yet).

The library depends on freetype, harfbuzz, & stb_truetype currently to build.  
Note: freetype and harfbuzz could technically be gutted if the user removes their definitions, however they have not been made into a conditional compilation option (yet).

## Changes from orignal

* Font Parser & Glyph shaper are abstracted to their own interface
* ve_fontcache_loadfile not ported (ust use core:os or os2, then call load_font)
* Macro defines have been coverted (mostly) to runtime parameters
* Support for hot_reloading
* Curve quality step granularity for glyph rendering can be set on a per font basis.

## TODOs

### Documentation:

* Pureref outline of draw_text exectuion
* Markdown general documentation

### Content:

* Port over the original demo utilizing sokol libraries instead

### Additional Features:

* Support for freetype (WIP, Untested)
* Support for harfbuzz (WIP, Untested)
* Add ability to conditionally compile dependencies (so that the user may not need to resolve those packages). 
  * Related to usage of //+build tags?
* Ability to set a draw transform, viewport and projection
  * By default the library's position is in unsigned normalized render space
  * Could implement a similar design to sokol_gp's interface

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
  * How the contexts are given jobs should be left up to the user (can recommend a screen quadrant based approach in demo examples)

Failed Attempts:

* Attempted to chunk the text to more granular 'shapes' from `draw_list` before doing the actual call to `draw_text_shape`. This lead to a larger performance cost due to the additional iteration across the text string.
* Attempted to cache the shape draw_list for future calls. Led to larger performance cost due to additional iteration in the `merge_draw_list`.
  * The shapes glyphs must still be traversed to identify if the glyph is cached. This arguably could be handled in `shape_text_uncached`, however that would require a significan't amount of refactoring to identify... (and would be more unergonomic when shapers libs are processing the text)
