class_name PostFx
extends CanvasLayer
## Screen post-processing over the 3D view, under the HUD: a soft vignette,
## animated film grain, a little color fringing toward the edges and a gentle
## split-tone grade (cool shadows, warm highlights). Strength 0 turns it off.

const SHADER := """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.55;
uniform float grain = 0.05;
uniform float fringe = 0.0018;
uniform vec3 shadow_tint = vec3(0.92, 0.96, 1.08);
uniform vec3 highlight_tint = vec3(1.06, 1.0, 0.92);
uniform float strength = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_center = uv - 0.5;
	float edge = dot(from_center, from_center);
	// Colour fringing grows toward the corners.
	vec2 shift = from_center * fringe * edge * 8.0;
	vec3 color;
	color.r = texture(screen_tex, uv + shift).r;
	color.g = texture(screen_tex, uv).g;
	color.b = texture(screen_tex, uv - shift).b;
	vec3 original = color;
	// Split tone by brightness.
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color *= mix(shadow_tint, highlight_tint, smoothstep(0.15, 0.75, luma));
	// Vignette.
	color *= 1.0 - smoothstep(0.12, 0.62, edge * 1.6) * vignette;
	// Film grain, animated.
	float noise = hash(uv * vec2(1280.0, 720.0) + fract(TIME * 7.3) * 91.7) - 0.5;
	color += noise * grain * (1.0 - luma * 0.6);
	COLOR = vec4(mix(original, color, strength), 1.0);
}
"""

var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	# Below the HUD (layer 1+), above the 3D view.
	layer = -1
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect.material = _material
	add_child(_rect)
	_apply()
	Settings.changed.connect(_apply)


func set_param(name: String, value) -> void:
	_material.set_shader_parameter(name, value)


func _apply() -> void:
	var on: bool = Settings.get_value("post_effects")
	_rect.visible = on
