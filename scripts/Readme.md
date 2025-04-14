# Scripts

All scripts provided for utilizing the example demos or backends.

## Windows

### build_sokol_demo.ps1

Builds example's sokol_demo.odin. Will gather necessary dependencies first.  
Its assumed the user has Odin installed and exposed to the OS enviornment's PATH.  
(Change odin_compiler_def.ps1 if not the case)

#### Note on dependency packages

A custom version of the vendor:stb/truetype is maintained by this library:

* Added ability to set the stb_truetype allocator for `STBTT_MALLOC` and `STBTT_FREE`.
* Changed procedure signatures to pass the font_info struct by immutable ptr (#by_ptr) when the C equivalent has their parameter as `const*`.

All other dependencies are provided directly into the thirdparty directory (EXCEPT sokol-tools, its cloned). However they can be cloned from their corresponding github repos:

[harfbuzz](https://github.com/Ed94/odin_harfbuzz) is configured to pull & build the C++ library, it will use the MSVC toolchain (you can change it to use meson instead of preferred).  
[sokol](https://github.com/floooh/sokol) built using `build_sokol_library.ps1`.  
[sokol-tools](https://github.com/floooh/sokol-tools) used by `compile_sokol_shaders.ps1` to compile the glsl files into odin files for the sokol backend.

### build_sokol_library.ps1

Helper script used by `build_sokol_demo.ps1`. Build's & modifies the library for its use in the examples.

### clean.ps1

Will wipe the build folder.

### compile_sokol_shaders.ps1

Will generate the odin files containing the sokol shader descriptions for the corresponding glsl shaders. Utilized by the sokol backend. Doesn't need to be run unless modifications are made to the shaders (pre-generated files are commited to this repository).

## Helpers

### devshell.ps1

Will run `Launch-VsDevShell.ps1` for the user to populate the shell with its enviornmental definitions

### misc.ps1

A few helper functions to utilize powerhsell & github repos as package management.

### odin_compiler_defs.ps1

Just variable declarations based on flags used with the odin compiler's CLI.

# Mac & Linux

Essentially equivalent scripts from the PS scripts used on windows were ported to bash. Tested in WSL ubuntu image for Linux, and a github action workflow for MacOS.

Build sokol manually if not using a fresh clone.

#### Note on dependency packages

All other dependencies are provided directly into the thirdparty directory (EXCEPT sokol-tools, its cloned). However they can be cloned from their corresponding github repos:

[harfbuzz](https://github.com/Ed94/odin_harfbuzz) is configured to pull & build the C++ library, it will use the gcc toolchain (you can change it to use meson instead of preferred).  

* On MacOS, harbuzz imports through system:harfbuzz instead as there is an issue with importing via relative directories.
  * Use for example `brew install harfbuzz`

[sokol](https://github.com/floooh/sokol) built using `build_sokol_library.sh`.  
[sokol-tools](https://github.com/floooh/sokol-tools) used by `compile_sokol_shaders.sh` to compile the glsl files into odin files for the sokol backend.

Caveats:

* The Freetype library's binary must be installed by the user ( Ex: `sudo apt install libfreetype6-dev` )
* Sokol needs gl, x11, and alsa libs. The `build_sokol_library.sh` script has basic implementation listing which libraries those are for ubuntu.
