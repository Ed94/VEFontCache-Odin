# harfbuzz-odin

Harbuzz bindings for odin.  

Its not the full amount, just enough to utilize its base shaping functionality.

## scripts/build.ps1

I only have support for building on Windows & Linux. However, Mac and Linux technically can just reference the library from their respective package managers.
Will pull the latest source from the harfbuzz repository and build requisite libraries. Adjust the code as needed, by default a custom unity build is done (see `Build-RepoWithoutMeson`).
