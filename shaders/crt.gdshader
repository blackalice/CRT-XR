shader_type spatial;
render_mode unshaded, cull_disabled;
// The TV's phosphor surface. The picture itself is in crt_screen.gdshaderinc,
// shared with flat screen mode; curvature is geometry only.
#define CRT_OUTPUT_IS_SRGB OUTPUT_IS_SRGB
#include "res://shaders/include/crt_screen.gdshaderinc"
void fragment() {
 ALBEDO = crt_screen(UV);
}
