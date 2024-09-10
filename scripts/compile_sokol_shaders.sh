#!/bin/bash

path_root="$(git rev-parse --show-toplevel)"
path_backend="$path_root/backend"
path_scripts="$path_root/scripts"
path_thirdparty="$path_root/thirdparty"

path_sokol_tools="$path_thirdparty/sokol-tools"
sokol_shdc="$path_sokol_tools/bin/linux/sokol-shdc"

path_backend_sokol="$path_backend/sokol"

shadersrc_blit_atlas="$path_backend_sokol/blit_atlas.shdc.glsl"
shaderout_blit_atlas="$path_backend_sokol/blit_atlas.odin"

shadersrc_draw_text="$path_backend_sokol/draw_text.shdc.glsl"
shaderout_draw_text="$path_backend_sokol/draw_text.odin"

shadersrc_render_glyph="$path_backend_sokol/render_glyph.shdc.glsl"
shaderout_render_glyph="$path_backend_sokol/render_glyph.odin"

flag_input="--input"
flag_output="--output"
flag_target_lang="--slang"
flag_format_odin="--format=sokol_odin"
flag_module="--module"

pushd "$path_backend_sokol" > /dev/null

"$sokol_shdc" "$flag_input" "$shadersrc_blit_atlas" \
              "$flag_output" "$shaderout_blit_atlas" \
              "$flag_target_lang" "glsl410:glsl300es:hlsl4:metal_macos:wgsl" \
              "$flag_format_odin" "$flag_module=blit_atlas"

"$sokol_shdc" "$flag_input" "$shadersrc_render_glyph" \
              "$flag_output" "$shaderout_render_glyph" \
              "$flag_target_lang" "glsl410:glsl300es:hlsl4:metal_macos:wgsl" \
              "$flag_format_odin" "$flag_module=render_glyph"

"$sokol_shdc" "$flag_input" "$shadersrc_draw_text" \
              "$flag_output" "$shaderout_draw_text" \
              "$flag_target_lang" "glsl410:glsl300es:hlsl4:metal_macos:wgsl" \
              "$flag_format_odin" "$flag_module=draw_text"

popd > /dev/null
