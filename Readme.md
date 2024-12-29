# VE Font Cache : Odin Port

https://github.com/user-attachments/assets/b74f1ec1-f980-45df-b604-d6b7d87d40ff

This is a port of the [VEFontCache](https://github.com/hypernewbie/VEFontCache) library.

Its original purpose was for use in game engines, however its rendeirng quality and performance is more than adequate for many other applications.

See: [docs/Readme.md](docs/Readme.md) for the library's interface.

## Building

See [scripts/Readme.md](scripts/Readme.md) for building examples or utilizing the provided backends.

Currently the scripts provided & the library itself were developed & tested on Windows. There are bash scripts for building on linux & mac.

The library depends on freetype, harfbuzz, & stb_truetype to build.  
Note: freetype and harfbuzz could technically be gutted if the user removes their definitions, however they have not been made into a conditional compilation option (yet).

## Changes from orignal

* Font Parser & Glyph shaper are abstracted to their own warpper interface
* ve_fontcache_loadfile not ported (ust use core:os or os2, then call load_font)
* Macro defines have been coverted (mostly) to runtime parameters
* Support for hot_reloading
* Curve quality step interpolation for glyph rendering can be set on a per font basis.
