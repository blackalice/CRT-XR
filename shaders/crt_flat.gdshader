shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Flat screen mode (scripts/rendering/flat_screen.gd): the TV's own picture,
// drawn straight to the window without the room. Canvas items sample and write
// sRGB values unchanged in the Compatibility renderer, as the TV's surface does
// with OUTPUT_IS_SRGB, so the same code gives the same colours.
#define CRT_OUTPUT_IS_SRGB true
#include "res://shaders/include/crt_screen.gdshaderinc"
void fragment() {
 COLOR = vec4(crt_screen(UV), 1.0);
}
