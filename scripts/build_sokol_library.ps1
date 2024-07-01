$devshell = Join-Path $PSScriptRoot 'devshell.ps1'
& $devshell -arch amd64

$path_root       = '../..'
$path_backend    = join-path $path_root 'backend'
$path_build      = join-path $path_root 'build'
$path_scripts    = join-path $path_root 'scripts'
$path_thirdparty = join-path $path_root 'thirdparty'

$path_sokol          = join-path $path_thirdparty 'sokol'
$path_sokol_examples = join-path $path_sokol      'examples'
if ( (test-path $path_sokol) -and (test-path "$path_sokol/sokol") )
{
	Move-Item   -Path "$path_sokol/sokol/*" -Destination $path_sokol -Force
	Remove-Item -Path "$path_sokol/sokol"   -Recurse -Force
	Remove-Item -Path $path_sokol_examples  -Recurse -Force
}

push-location $path_sokol
& '.\build_clibs_windows.cmd'
pop-location
