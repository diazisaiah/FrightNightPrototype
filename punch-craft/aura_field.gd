class_name AuraField
extends Node
## Cash Out's green aura field (2026-11-06, the user's idea instead of a third-
## person shot): while the shield is up the Blur stands in a pulsing green
## field: a glowing disc and ring on the ground, green motes rising round him,
## and a soft green glow at the screen's edges. It shrinks and dims as the
## shield is used up, flashes when it soaks a hit, and fades when it's gone.

const COLOR := Color(0.35, 1.0, 0.55)
const DISC_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec3 color = vec3(0.35, 1.0, 0.55);
uniform float level = 1.0;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float ring = smoothstep(0.74, 0.9, d) * (1.0 - smoothstep(0.95, 1.0, d));
	float fill = (1.0 - smoothstep(0.0, 0.95, d)) * 0.22;
	float spokes = (0.5 + 0.5 * sin(atan(UV.y - 0.5, UV.x - 0.5) * 12.0 + TIME * 2.0)) * smoothstep(0.35, 0.8, d) * 0.12;
	ALBEDO = color;
	ALPHA = (ring * 0.85 + fill + spokes) * level;
}
"""
const EDGE_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform vec3 color = vec3(0.35, 1.0, 0.55);
uniform float intensity = 1.0;
void fragment() {
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.25, 1.0);
	float e = smoothstep(0.26, 0.72, length(d));
	COLOR = vec4(color, e * intensity * 0.42);
}
"""

var _player: Player
var _disc: MeshInstance3D
var _disc_material: ShaderMaterial
var _motes: CPUParticles3D
var _layer: CanvasLayer
var _edge_material: ShaderMaterial
## How much of the shield is left (0-1), a flash that fades, and how far it has faded out.
var _strength := 1.0
var _flash := 0.0
var _fade := 1.0
var _ending := false


func setup(player: Player) -> void:
	_player = player
	var parent := player.get_parent()
	# The ground disc.
	_disc = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.8, 3.8)
	_disc.mesh = plane
	_disc_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = DISC_SHADER
	_disc_material.shader = shader
	_disc.material_override = _disc_material
	_disc.top_level = true
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(_disc)
	# Motes rising round him.
	_motes = CPUParticles3D.new()
	_motes.amount = maxi(10, roundi(40.0 * (0.6 if Settings.use_web_profile() else 1.0)))
	_motes.lifetime = 1.4
	_motes.local_coords = false
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_motes.emission_ring_axis = Vector3.UP
	_motes.emission_ring_radius = 1.5
	_motes.emission_ring_inner_radius = 1.0
	_motes.emission_ring_height = 0.1
	_motes.direction = Vector3.UP
	_motes.spread = 8.0
	_motes.initial_velocity_min = 0.7
	_motes.initial_velocity_max = 1.4
	_motes.gravity = Vector3.ZERO
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh.material = material
	_motes.mesh = mesh
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(COLOR, 0.0), Color(COLOR.lightened(0.3), 1.0), Color(COLOR, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	_motes.color_ramp = ramp
	_motes.emitting = true
	parent.add_child(_motes)
	# The glow at the screen's edges, under the HUD.
	_layer = CanvasLayer.new()
	_layer.layer = 0
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_material = ShaderMaterial.new()
	var edge_shader := Shader.new()
	edge_shader.code = EDGE_SHADER
	_edge_material.shader = edge_shader
	rect.material = _edge_material
	_layer.add_child(rect)
	add_child(_layer)


## What's left of the shield, 0-1.
func set_strength(value: float) -> void:
	_strength = clampf(value, 0.0, 1.0)


## A hit soaked: the field flares.
func pulse() -> void:
	_flash = 1.0


## The shield's gone: fade out and free.
func finish() -> void:
	_ending = true


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_free()
		return
	_flash = maxf(0.0, _flash - delta * 3.0)
	if _ending:
		_fade = move_toward(_fade, 0.0, delta * 2.5)
		if _fade <= 0.0:
			_free()
			return
	var level := _fade * (0.35 + 0.65 * _strength) * (0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.006)) * (1.0 + _flash * 0.8)
	_disc.global_position = Vector3(_player.global_position.x, _player.global_position.y + 0.05, _player.global_position.z)
	_disc.scale = Vector3.ONE * (0.55 + 0.45 * _strength) * (1.0 + _flash * 0.12)
	_disc_material.set_shader_parameter("level", level)
	_motes.global_position = _player.global_position
	_motes.emitting = not _ending and _strength > 0.0
	_motes.speed_scale = 1.0 + _flash
	_edge_material.set_shader_parameter("intensity", level * 0.8)


func _free() -> void:
	if is_instance_valid(_disc):
		_disc.queue_free()
	if is_instance_valid(_motes):
		_motes.queue_free()
	queue_free()
