$misc = join-path $PSScriptRoot 'helpers/misc.ps1'
. $misc

$path_root  = git rev-parse --show-toplevel
$path_lib   = join-path $path_root 'lib'
$path_win64 = join-path $path_lib  'win64'

$url_harfbuzz  = 'https://github.com/harfbuzz/harfbuzz.git'
$path_harfbuzz = join-path $path_root 'harfbuzz'

function build-repo {
	verify-path $script:path_lib
	verify-path $path_win64

	clone-gitrepo $path_harfbuzz $url_harfbuzz

	push-location $path_harfbuzz

    $library_type = "shared"
    $build_type   = "release"

    # Meson configure and build
    $mesonArgs = @(
        "build",
        "--default-library=$library_type",
        "--buildtype=$build_type",
        "--wrap-mode=forcefallback",
        "-Dglib=disabled",
        "-Dgobject=disabled",
        "-Dcairo=disabled",
        "-Dicu=disabled",
        "-Dgraphite=disabled",
        "-Dfreetype=disabled",
        "-Ddirectwrite=disabled",
        "-Dcoretext=disabled"
    )
    & meson $mesonArgs
	& meson compile -C build

	pop-location

	$path_build      = join-path $path_harfbuzz 'build'
	$path_src        = join-path $path_build    'src'
	$path_dll        = join-path $path_src      'harfbuzz.dll'
	$path_lib        = join-path $path_src      'harfbuzz.lib'
	$path_lib_static = join-path $path_src      'libharfbuzz.a'
	$path_pdb        = join-path $path_src      'harfbuzz.pdb'

	# Copy files based on build type and library type
	if ($build_type -eq "debug") {
		copy-item -Path $path_pdb -Destination $path_win64 -Force
	}

	if ($library_type -eq "static") {
		copy-item -Path $path_lib_static -Destination (join-path $path_win64 'harfbuzz.lib') -Force
	}
	else {
		copy-item -Path $path_lib -Destination $path_win64 -Force
		copy-item -Path $path_dll -Destination $path_win64 -Force
	}

	write-host "Build completed and files copied to $path_win64"
}
# build-repo

function Build-RepoWithoutMeson {
    $devshell = join-path $PSScriptRoot 'helpers/devshell.ps1'
    & $devshell -arch amd64

    verify-path $script:path_lib
    verify-path $path_win64

    clone-gitrepo $path_harfbuzz $url_harfbuzz

    $path_harfbuzz_build = join-path $path_harfbuzz 'build'
    verify-path $path_harfbuzz_build

    $library_type = "shared"
    $build_type   = "release"

    push-location $path_harfbuzz

    $compiler_args = @(
        "/nologo",
        "/W3",
        "/D_CRT_SECURE_NO_WARNINGS",
        "/DHAVE_FALLBACK=1",
        "/DHAVE_OT=1",
        "/DHAVE_SUBSET=1",
        "/DHB_USE_INTERNAL_PARSER",
        "/DHB_NO_COLOR",
        "/DHB_NO_DRAW",
        "/DHB_NO_PARSE",
        "/DHB_NO_MT",
        "/DHB_NO_GRAPHITE2",
        "/DHB_NO_ICU",
        "/DHB_NO_DIRECTWRITE",
        "/I$path_harfbuzz\src",
        "/I$path_harfbuzz"
    )

    if ( $library_type -eq "shared" ) {
        $compiler_args += "/DHAVE_DECLSPEC"
        $compiler_args += "/DHARFBUZZ_EXPORTS"
    }

    if ($build_type -eq "debug") {
        $compiler_args += "/MDd", "/Od", "/Zi"
    } else {
        $compiler_args += "/MD", "/O2"
    }

    $compiler_args = $compiler_args -join " "

    $config_h_content = @"
#define HB_VERSION_MAJOR 9
#define HB_VERSION_MINOR 0
#define HB_VERSION_MICRO 0
#define HB_VERSION_STRING "9.0.0"
#define HAVE_ROUND 1
#define HB_NO_BITMAP 1
#define HB_NO_CFF 1
#define HB_NO_OT_FONT_CFF 1
#define HB_NO_SUBSET_CFF 1
#define HB_HAVE_SUBSET 0
#define HB_HAVE_OT 0
#define HB_USER_DATA_KEY_DEFINE1(_name) extern HB_EXTERN hb_user_data_key_t _name
"@
    set-content -Path (join-path $path_harfbuzz "config.h") -Value $config_h_content

    $unity_content = @"
#define HB_EXTERN __declspec(dllexport)

// base
#include "config.h"
#include "hb-aat-layout.cc"
#include "hb-aat-map.cc"
#include "hb-blob.cc"
#include "hb-buffer-serialize.cc"
#include "hb-buffer-verify.cc"
#include "hb-buffer.cc"
#include "hb-common.cc"

//#include "hb-draw.cc"
//#include "hb-paint.cc"
//#include "hb-paint-extents.cc"

#include "hb-face.cc"
#include "hb-face-builder.cc"
#include "hb-fallback-shape.cc"
#include "hb-font.cc"
#include "hb-map.cc"
#include "hb-number.cc"
#include "hb-ot-cff1-table.cc"
#include "hb-ot-cff2-table.cc"
#include "hb-ot-color.cc"
#include "hb-ot-face.cc"
#include "hb-ot-font.cc"

#include "hb-outline.cc"
#include "OT/Var/VARC/VARC.cc"

#include "hb-ot-layout.cc"
#include "hb-ot-map.cc"
#include "hb-ot-math.cc"
#include "hb-ot-meta.cc"
#include "hb-ot-metrics.cc"
#include "hb-ot-name.cc"

#include "hb-ot-shaper-arabic.cc"
#include "hb-ot-shaper-default.cc"
#include "hb-ot-shaper-hangul.cc"
#include "hb-ot-shaper-hebrew.cc"
#include "hb-ot-shaper-indic-table.cc"
#include "hb-ot-shaper-indic.cc"
#include "hb-ot-shaper-khmer.cc"
#include "hb-ot-shaper-myanmar.cc"
#include "hb-ot-shaper-syllabic.cc"
#include "hb-ot-shaper-thai.cc"
#include "hb-ot-shaper-use.cc"
#include "hb-ot-shaper-vowel-constraints.cc"

#include "hb-ot-shape-fallback.cc"
#include "hb-ot-shape-normalize.cc"
#include "hb-ot-shape.cc"
#include "hb-ot-tag.cc"
#include "hb-ot-var.cc"

#include "hb-set.cc"
#include "hb-shape-plan.cc"
#include "hb-shape.cc"
#include "hb-shaper.cc"
#include "hb-static.cc"
#include "hb-style.cc"
#include "hb-ucd.cc"
#include "hb-unicode.cc"

// libharfbuzz-subset
//#include "hb-subset-input.cc"
//#include "hb-subset-cff-common.cc"
//#include "hb-subset-cff1.cc"
//#include "hb-subset-cff2.cc"
//#include "hb-subset-instancer-iup.cc"
//#include "hb-subset-instancer-solver.cc"
//#include "hb-subset-plan.cc"
//#include "hb-subset-repacker.cc"

//#include "graph/gsubgpos-context.cc"

//#include "hb-subset.cc"
"@
    $unity_file = join-path $path_harfbuzz_build "harfbuzz_unity.cc"
    set-content -Path $unity_file -Value $unity_content

    # Compile unity file
    $obj_file = "harfbuzz_unity.obj"
    $command  = "cl.exe $compiler_args /c $unity_file /Fo$path_harfbuzz_build\$obj_file"

    write-host "Compiling: $command"
    invoke-expression $command

    if ($LASTEXITCODE -ne 0) {
        write-error "Compilation failed for unity build"
        pop-location
        return
    }

    push-location $path_harfbuzz_build

    # Create library
    if ($library_type -eq "static")
    {
        $lib_command = "lib.exe /OUT:harfbuzz.lib $obj_file"

        write-host "Creating static library: $lib_command"
        invoke-expression $lib_command

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Static library creation failed"
            pop-location
            pop-location
            return
        }
        $output_file = "harfbuzz.lib"
    }
    else
    {
        $linker_args = "/DLL", "/OUT:harfbuzz.dll"

        if ($build_type -eq "debug") {
            $linker_args += "/DEBUG"
        }

        $link_command = "link.exe $($linker_args -join ' ') $obj_file"

        write-host "Creating shared library: $link_command"
        invoke-expression $link_command

        if ($LASTEXITCODE -ne 0) {
            write-error "Shared library creation failed"
            pop-location
            pop-location
            return
        }
        $output_file = "harfbuzz.dll"
    }

    pop-location # path_harfbuzz_build
    pop-location # path_harfbuzz

    # Copy files
    $path_output = join-path $path_harfbuzz_build $output_file

    if (test-path $path_output) {
        copy-item -Path $path_output -Destination $path_win64 -Force
        if ($library_type -eq "shared") {
            $path_lib = join-path $path_harfbuzz_build "harfbuzz.lib"
            if (test-path $path_lib) {
                copy-item -Path $path_lib -Destination $path_win64 -Force
            }
        }
    } else {
        write-warning "Output file not found: $path_output"
    }

    write-host "Build completed and files copied to $path_win64"
}
Build-RepoWithoutMeson

function grab-binaries {
	verify-path $script:path_lib
	verify-path $path_win64

	$url_harfbuzz_8_5_0_win64 = 'https://github.com/harfbuzz/harfbuzz/releases/latest/download/harfbuzz-win64-8.5.0.zip'
	$path_harfbuzz_win64_zip  = join-path $path_win64 'harfbuzz-win64-8.5.0.zip'
	$path_harfbuzz_win64      = join-path $path_win64 'harfbuzz-win64'

	grab-zip $url_harfbuzz_8_5_0_win64 $path_harfbuzz_win64_zip $path_win64
	get-childitem -path $path_harfbuzz_win64 | move-item -destination $path_win64 -force

	# Clean up the ZIP file and the now empty harfbuzz-win64 directory
	remove-item $path_harfbuzz_win64_zip -force
	remove-item $path_harfbuzz_win64 -recurse -force
}
# grab-binaries
