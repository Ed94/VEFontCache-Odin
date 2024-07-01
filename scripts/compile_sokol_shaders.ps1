$path_root       = git rev-parse --show-toplevel
$path_backend    = join-path $path_root 'backend'
$path_scripts    = join-path $path_root 'scripts'
$path_thirdparty = join-path $path_root 'thirdparty'

$path_sokol_tools = join-path $path_thirdparty 'sokol-tools'
$sokol_shdc       = join-path $path_sokol_tools 'bin/win32/sokol-shdc.exe'

$path_backend_sokol = join-path $path_backend 'sokol'

$shadersrc_blit_atlas   = join-path $path_backend_sokol 'blit_atlas.shdc.glsl'
$shaderout_blit_atlas   = join-path $path_backend_sokol 'blit_atlas.odin'

$shadersrc_draw_text    = join-path $path_backend_sokol 'draw_text.shdc.glsl'
$shaderout_draw_text    = join-path $path_backend_sokol 'draw_text.odin'

$shadersrc_render_glyph = join-path $path_backend_sokol 'render_glyph.shdc.glsl'
$shaderout_render_glyph = join-path $path_backend_sokol 'render_glyph.odin'

$flag_input       = '--input '
$flag_output      = '--output '
$flag_target_lang = '--slang '
$flag_format_odin = '--format=sokol_odin'
$flag_module      = '--module'

push-location $path_backend_sokol
& $sokol_shdc --input $shadersrc_blit_atlas   --output $shaderout_blit_atlas   --slang 'glsl410:glsl300es:hlsl4:metal_macos:wgsl' $flag_format_odin $flag_module='blit_atlas'
& $sokol_shdc --input $shadersrc_render_glyph --output $shaderout_render_glyph --slang 'glsl410:glsl300es:hlsl4:metal_macos:wgsl' $flag_format_odin $flag_module='render_glyph'
& $sokol_shdc --input $shadersrc_draw_text    --output $shaderout_draw_text    --slang 'glsl410:glsl300es:hlsl4:metal_macos:wgsl' $flag_format_odin $flag_module='draw_text'
pop-location
