# stb_truetype-odin

A modification of the stb_truetype vendor library.

Adds support for:

* Allocator assignement via gb/zpl allocators (essentially equivalent to odin's allocator procedure/data struct)
* Pass #by_ptr on font_info's when they are expected to be immutable (library has the proc signature as `const font_info*`)
