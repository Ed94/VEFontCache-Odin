# VE Font Cache

Vertex Engine GPU Font Cache: A text shaping & rendering library.

This project started as a port of the [VEFontCache](https://github.com/hypernewbie/VEFontCache) library to the Odin programming language.  
While originally intended for game engines, its rendering quality and performance make it suitable for many other applications.

Since then, the library has been overhauled to offer higher performance, improved visual fidelity, additional features, and quality of life improvements.

Features:

* Simple and well documented
* Load and unload fonts at any time
* Almost entirely configurable and tunable at runtime
* Full support for hot-reload
  * Clear the caches at any time
* Robust quality of life features:
  * Snap positioning to view for better hinting
  * Tracks text layers
  * Enforce even-only font sizing (useful for linear zoom)
  * Push and pop stack for font, font_size, color, view, position, scale, and zoom
* Basic (latin) or advanced (harfbuzz) text shaping
* All rendering is real-time, with triangulation on the CPU, vertex rendering and texture blitting on the GPU
  * Can handle thousands of draw text calls with very large or small shapes
* 4-Level Regioned Texture Atlas for caching rendered glyphs
* Text shape caching
* Glyph texture buffer for rendering text with super-sampling to downsample to the atlas or direct to target screen
* Super-sample by a font size scalar for sharper glyphs
* All caching backed by an optimized 32-bit LRU indexing cache
* Provides a backend-agnostic draw list (see [backend](./backend) for usage example)

Upcoming:

* Support choosing between top-left or bottom-left coordinate convention (currently bottom-left)
* Support for better triangulation
  * Support for triangulation method selection on a per-font basis
  * [Reference paper](https://www.microsoft.com/en-us/research/wp-content/uploads/2005/01/p1000-loop.pdf)
* Better support for tuning glyph render sampling
  * Support for sub-pixel AA
  * Ability to decide AA method & degree on a per-font basis
* Multi-threading supported job queue
  * Lift heavy-lifting portion of the library's context into a thread context
  * Synchronize threads by merging their generated layered draw list into a finished draw list for processing on the user's render thread
  * User defines how thread contexts are distributed for drawing (a basic quadrant-based selector procedure will be provided)

## Documentation

* [docs/Readme.md](docs/Readme.md) for the library's interface
* [docs/guide_backend.md](docs/guide_backend.md) for information on implementing your own backend
* [docs/guide_architecture.md](docs/guide_architecture.md) for an in-depth breakdown of significant design decisions and code-paths

For learning about text shaping & rendering see: [notes](https://github.com/Ed94/TextRendering_Notes)

## Building

See [scripts/Readme.md](scripts/Readme.md) for building examples or utilizing the provided backends.

Currently, the scripts provided & the library itself were developed & tested on Windows. There are bash scripts for building on Linux (they build on WSL but need additional testing).

The library depends on harfbuzz & stb_truetype to build.  
Note: harfbuzz could technically be removed if the user removes their definitions, however this hasn't been made into a conditional compilation option yet.

**NOTICE: All library dependencies are in the "thirdparty" collection of this repository. For their codebase, the user soley has to modify that collection specification for where they would like to put these external "vendor" dependencies not provided by odin.**

## Gallery

![sokol_demo_2025-01-11_01-32-24](https://github.com/user-attachments/assets/4aea2b23-4362-47e6-b6d1-286e84891702)

https://github.com/user-attachments/assets/db8c7725-84dd-48df-9a3f-65605d3ab444

https://github.com/user-attachments/assets/40030308-37db-492d-a196-f830e8a39f3c

https://github.com/user-attachments/assets/0985246b-74f8-4d1c-82d8-053414c44aec
