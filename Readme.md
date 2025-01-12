# VE Font Cache

Vertex Engine GPU Font Cache: A text rendering libary.

This started off as a port of the [VEFontCache](https://github.com/hypernewbie/VEFontCache) library to the Odin programming language.
Its original purpose was for use in game engines, however its rendeirng quality and performance is more than adequate for many other applications.

Since then the library has been overhauled to offer higher performance, improved visual fidelity, additional features, and quality of life improvements.

Features:

* Simple and well documented.
* Load and unload fonts at anytime
* Almost entirely configurabe and tunable at runtime!
* Full support for hot-reload
  * Clear the caches at any-time!
* Robust quality of life features:
  * Tracks text layers!
  * Push and pop stack for font, font_size, colour, view, position, scale and zoom!
  * Enforce even only font-sizing (useful for linear-zoom)
  * Snap-positioning to view for better hinting
* Basic or advanced text shaping via Harfbuzz
* All rendering is real-time, triangulation done on the CPU, vertex rendering and texture blitting on the gpu.
  * Can hand thousands of draw text calls with very large or small shapes.
* 4-Level Regioned Texture Atlas for caching rendered glyphs
* Text shape caching
* Glyph texture buffer for rendering the text with super-sampling to downsample to the atlas or direct to target screen.
* Super-sample by a font size scalar for sharper glyphs
* All caching backed by an optimized 32-bit LRU indexing cache
* Provides a draw list that is backend agnostic (see [backend](./backend) for usage example).

Upcoming:

* Support for ear-clipping triangulation, or just better triangulation..
  * Support for which triangulation method used on a by font basis?
  * [paper](https://www.microsoft.com/en-us/research/wp-content/uploads/2005/01/p1000-loop.pdf)
* Multi-threading supported job queue.
  * Lift heavy-lifting portion of the library's context into a thread context.
  * Synchronize threads by merging their generated layered draw list into a finished draw-list for processing on the user's render thread.
  * User defines how thread context's are distributed for drawing (a basic quandrant based selector procedure will be provided.)

## Documentation

* [docs/Readme.md](docs/Readme.md) for the library's interface.
* [docs/guide_backend.md](docs/guide_backend.md) for information on whats needed rolling your own backend.
* [docs/guide_architecture.md](docs/guide_architecture.md) for an in-depth breakdown of the significant design decisions, and codepaths.

## Building

See [scripts/Readme.md](scripts/Readme.md) for building examples or utilizing the provided backends.

Currently the scripts provided & the library itself were developed & tested on Windows. There are bash scripts for building on linux (they build on WSL but need additional testing).

The library depends on harfbuzz, & stb_truetype to build.  
Note: harfbuzz could technically be gutted if the user removes their definitions, however they have not been made into a conditional compilation option (yet).

# Gallery

![sokol_demo_2025-01-11_01-32-24](https://github.com/user-attachments/assets/4aea2b23-4362-47e6-b6d1-286e84891702)

https://github.com/user-attachments/assets/db8c7725-84dd-48df-9a3f-65605d3ab444

https://github.com/user-attachments/assets/40030308-37db-492d-a196-f830e8a39f3c

https://github.com/user-attachments/assets/0985246b-74f8-4d1c-82d8-053414c44aec
