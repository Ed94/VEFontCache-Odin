clear-host

$misc = join-path $PSScriptRoot 'helpers/misc.ps1'
. $misc

$path_root       = git rev-parse --show-toplevel
$path_backend    = join-path $path_root 'backend'
$path_build      = join-path $path_root 'build'
$path_examples   = join-path $path_root 'examples'
$path_scripts    = join-path $path_root 'scripts'
$path_thirdparty = join-path $path_root 'thirdparty'

verify-path $path_build
verify-path $path_thirdparty

#region CPU_Info
$path_system_details = join-path $path_build 'system_details.ini'
if ( test-path $path_system_details ) {
    $iniContent = Get-IniContent $path_system_details
    $CoreCount_Physical = $iniContent["CPU"]["PhysicalCores"]
    $CoreCount_Logical  = $iniContent["CPU"]["LogicalCores"]
}
elseif ( $IsWindows ) {
	$CPU_Info = Get-CimInstance –ClassName Win32_Processor | Select-Object -Property NumberOfCores, NumberOfLogicalProcessors
	$CoreCount_Physical, $CoreCount_Logical = $CPU_Info.NumberOfCores, $CPU_Info.NumberOfLogicalProcessors

	new-item -path $path_system_details -ItemType File
    "[CPU]"                             | Out-File $path_system_details
    "PhysicalCores=$CoreCount_Physical" | Out-File $path_system_details -Append
    "LogicalCores=$CoreCount_Logical"   | Out-File $path_system_details -Append
}
write-host "Core Count - Physical: $CoreCount_Physical Logical: $CoreCount_Logical"
#endregion CPU_Info

$url_freetype       = 'https://github.com/Ed94/odin-freetype.git'
$url_harfbuzz       = 'https://github.com/Ed94/harfbuzz-odin.git'
$url_sokol          = 'https://github.com/floooh/sokol-odin.git'
$url_sokol_tools    = 'https://github.com/floooh/sokol-tools-bin.git'

$path_freetype      = join-path $path_thirdparty 'freetype'
$path_harfbuzz      = join-path $path_thirdparty 'harfbuzz'
$path_sokol         = join-path $path_thirdparty 'sokol'
$path_sokol_tools   = join-path $path_thirdparty 'sokol-tools'

$sokol_build_clibs_command = join-path $path_scripts 'build_sokol_library.ps1'

clone-gitrepo $path_freetype    $url_freetype
clone-gitrepo $path_sokol_tools $url_sokol_tools

Update-GitRepo -path $path_sokol    -url $url_sokol     -build_command $sokol_build_clibs_command
Update-GitRepo -path $path_harfbuzz -url $url_harfbuzz  -build_command '.\scripts\build.ps1'

push-location $path_thirdparty
	$path_sokol_dlls    = $path_sokol
	$path_harfbuzz_dlls = join-path $path_harfbuzz 'lib/win64'

	$third_party_dlls = Get-ChildItem -Path $path_sokol_dlls -Filter '*.dll'
	foreach ($dll in $third_party_dlls) {
		$destination = join-path $path_build $dll.Name
		Copy-Item $dll.FullName -Destination $destination -Force
	}

	$third_party_dlls = Get-ChildItem -path $path_harfbuzz_dlls -Filter '*.dll'
	foreach ($dll in $third_party_dlls) {
		$destination = join-path $path_build $dll.Name
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

	# $compile_shaders = join-path $path_scripts "compile_sokol_shaders.ps1"
	# & $compile_shaders

	$executable = join-path $path_build 'sokol_demo.exe'
	$pdb        = join-path $path_build 'sokol_demo.pdb'

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
	# $build_args += $flag_debug
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
