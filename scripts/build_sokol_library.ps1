$devshell = Join-Path $PSScriptRoot 'devshell.ps1'
& $devshell -arch amd64

$path_root       = git rev-parse --show-toplevel
$path_backend    = join-path $path_backend 'backend'
$path_binaries   = join-path $path_bin     'binaries'
$path_scripts    = join-path $path_root    'scripts'
$path_thirdparty = join-path $path_root    'thirdparty'

$path_sokol = Join-Path $path_thirdparty 'sokol'
if (test-path $path_sokol)
{
	Move-Item   -Path "$path_sokol/sokol/*" -Destination $path_sokol -Force
	Remove-Item -Path $path_sokol -Recurse -Force
	Remove-Item -Path $path_sokol_examples -Recurse -Force
}

& '.\build_clibs_windows.cmd'
