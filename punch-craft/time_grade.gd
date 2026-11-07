class_name TimeGrade
extends CanvasLayer
## The desaturated world of Temporal Break (2026-11-06, the user's idea): the
## colour drains out of the game in an expanding sphere that starts inside the
## Blur's raised hand, and stays drained while time is stopped. A screen-space
## circle (radius in screen heights, from a centre point in screen UV), so it
## works on every renderer, phones included, and only runs while it's showing.
## It sits under the HUD, so the HUD keeps its colours.

const SHADER := """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 center = vec2(0.5, 0.5);
uniform float radius = 0.0;
uniform float aspect = 1.7778;
uniform vec3 tint = vec3(0.86, 0.94, 1.06);
uniform vec3 rim = vec3(0.6, 0.85, 1.0);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec2 d = (SCREEN_UV - center) * vec2(aspect, 1.0);
	float dist = length(d);
	float inside = 1.0 - smoothstep(radius - 0.02, radius, dist);
	float edge = smoothstep(radius - 0.07, radius - 0.01, dist) * (1.0 - smoothstep(radius - 0.01, radius + 0.006, dist));
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 grey = vec3(luma) * tint;
	grey = (grey - 0.5) * 1.12 + 0.5;
	vec3 result = mix(c, grey, inside);
	result += edge * rim * 0.7 * step(0.001, radius);
	COLOR = vec4(result, 1.0);
}
"""

## How far the circle has to reach to cover the whole screen from anywhere on it.
const FULL := 3.0

var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	# Below the HUD, above the 3D view (and the film grade at -1).
	layer = 0
	visible = false
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect.material = _material
	add_child(_rect)


## The circle: centre in screen UV, radius in screen heights (0 hides it).
func set_circle(center: Vector2, radius: float) -> void:
	if _material == null:
		return
	var size := get_viewport().get_visible_rect().size
	_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_material.set_shader_parameter("center", center)
	_material.set_shader_parameter("radius", radius)
	visible = radius > 0.0
