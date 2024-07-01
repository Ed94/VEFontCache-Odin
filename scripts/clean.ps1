$path_root       = git rev-parse --show-toplevel
$path_backend    = join-path $path_root 'backend'
$path_build      = join-path $path_root 'build'
$path_examples   = join-path $path_root 'examples'
$path_scripts    = join-path $path_root 'scripts'
$path_thirdparty = join-path $path_root 'thirdparty'

if ( test-path $path_build )     { Remove-Item $path_build -Verbose -Force -Recurse }
# if ( test-path $path_thirdparty) { Remove-Item $path_thirdparty -Verbose -Force -Recurse }
