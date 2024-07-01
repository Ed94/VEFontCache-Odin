$path_root       = git rev-parse --show-toplevel
$path_backend    = join-path $path_backend  'backend'
$path_binaries   = join-path $path_bin      'binaries'
$path_examples   = join-path $path_examples 'examples'
$path_scripts    = join-path $path_root     'scripts'
$path_thirdparty = join-path $path_root     'thirdparty'

verify-path $path_binaries
verify-path $path_thirdparty

$misc = join-path $PSScriptRoot 'helpers/misc.ps1'
. $misc

$url_sokol          = 'https://github.com/Ed94/sokol-odin.git'
$url_sokol_tools    = 'https://github.com/floooh/sokol-tools-bin.git'

$path_sokol         = join-path $path_thirdparty 'sokol'
$path_sokol_tools   = join-path $path_thirdparty 'sokol-tools'

$sokol_build_clibs_command = join-path $path_scripts 'build_sokol_library.ps1'

clone-gitrepo $path_sokol_tools $url_sokol_tools
Update-GitRepo -path $path_sokol -url $url_sokol -build_command $sokol_build_clibs_command

push-location $path_thirdparty
	$path_sokol_dlls = join-path $path_sokol 'sokol'

	$third_party_dlls = Get-ChildItem -Path $path_sokol_dlls -Filter '*.dll'
	foreach ($dll in $third_party_dlls) {
		$destination = join-path $path_binaries $dll.Name
		Copy-Item $dll.FullName -Destination $destination -Force
	}
pop-location

$odin_compiler_defs = join-path $PSScriptRoot 'helpers/odin_compiler_defs.ps1'
. $odin_compiler_defs

$pkg_collection_backend    = 'backend='    + $path_backend
$pkg_collection_thirdparty = 'thirdparty=' + $path_thirdparty

push-location $path_examples

function build-SokolBackendDemo
{
	write-host 'Building VEFontCache: Sokol Backend Demo'

	$build_args = @()
	$build_args += $command_build
	$build_args += './sokol_demo'
	$build_args += $flag_output_path + $executable
	$build_args += ($flag_collection + $pkg_collection_backend)
	$build_args += ($flag_collection + $pkg_collection_thirdparty)
	# $build_args += $flag_micro_architecture_native
	$build_args += $flag_use_separate_modules
	$build_args += $flag_thread_count + $CoreCount_Physical
	# $build_args += $flag_optimize_none
	# $build_args += $flag_optimize_minimal
	# $build_args += $flag_optimize_speed
	$build_args += $falg_optimize_aggressive
	$build_args += $flag_debug
	$build_args += $flag_pdb_name + $pdb
	$build_args += $flag_subsystem + 'windows'
	# $build_args += ($flag_extra_linker_flags + $linker_args )
	$build_args += $flag_show_timings
	# $build_args += $flag_show_system_call
	# $build_args += $flag_no_bounds_check
	# $build_args += $flag_no_thread_checker
	# $build_args += $flag_default_allocator_nil
	$build_args += ($flag_max_error_count + '10')
	# $build_args += $flag_sanitize_address
	# $build_args += $flag_sanitize_memory

	Invoke-WithColorCodedOutput { & $odin_compiler $build_args }
}
build-SokolBackendDemo

pop-location
