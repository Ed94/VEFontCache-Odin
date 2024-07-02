# Scripts

All scripts provided for utilizing the example demos or backends.

## General

### build_sokol_demo.ps1

Builds example's sokol_demo.odin. Will gather necessary dependencies first.  
Its assumed the user has Odin installed and exposed to the OS enviornment's PATH.  
(Change odin_compiler_def.ps1 if not the case)

#### Note on dependency packages

All dependencies are cloned directly into a created thirdparty directory.

[harfbuzz](https://github.com/Ed94/odin_harfbuzz) is configured to pull & build the C++ library, it will use the MSVC toolchain (you can change it to use meson instead of preferred).  
[freetype](https://github.com/Ed94/odin-freetype) package has pre-built .lib files for windows (debug/release).  
[sokol](https://github.com/floooh/sokol) built using `build_sokol_library.ps`.  
[sokol-tools](https://github.com/floooh/sokol-tools) used by `compile_sokol_shaders.ps1` to compile the glsl files into odin files for the sokol backend.

### build_sokol_library.ps1

Helper script used by `build_sokol_demo.ps1`. Build's & modifies the library for its use in the examples.

### clean.ps1

Will wipe the build folder.

### compile_sokol_shaders.ps1

Will generate the odin files containing the sokol shader descriptions for the corresponding glsl shaders. Utilized by the sokol backend. Doesn't need to be runned unless modifications are made to the shaders (pre-generated files are commited to this repository).

## Helpers

### devshell.ps1

Will run `Launch-VsDevShell.ps1` for the user to populate the shell with its enviornmental definitions

### misc.ps1

A few helper functions to utilize powerhsell & github repos as package management.


### odin_compiler_defs.ps1

Just variable declarations based on flags used with the odin compiler's CLI.
