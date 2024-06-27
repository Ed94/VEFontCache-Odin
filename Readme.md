# VE Font Cache : Odin Port

This is a port of the library base on [fork](https://github.com/hypernewbie/VEFontCache)

Its original purpose was for use in game engines, however its rendeirng quality and performance is more than adequate for many other applications.

See: [docs/Readme.md](docs/Readme.md) for the library's interface

TODO (Making it a more idiomatic library):

* Setup freetype, harfbuzz, depedency management within the library

TODO Documentation:

* Pureref outline of draw_text exectuion
* Markdown general documentation

TODO Content:

* Port over the original demo utilizing sokol libraries instead
* Provide a sokol_gfx backend package

TODO Additional Features:

* Support for freetype
* Support for harfbuzz
* Ability to set a draw transform, viewport and projection
  * By default the library's position is in unsigned normalized render space
* Allow curve_quality to be set on a per-font basis
