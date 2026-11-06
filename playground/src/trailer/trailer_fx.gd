extends Node
## Custom counter / knockout effects for the trailer's real-game fights: a
## cold wash and colour split on every slip and roll, white speed lines, a
## ring and lightning on a counter, and all of it bigger on a knockout.
## attach(player, scene, color) wires it to a real Player.

const IMPACT_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float lines = 0.0;
uniform float split = 0.0;
uniform float tint_a = 0.0;
uniform vec3 tint = vec3(0.4, 0.7, 1.0);
uniform float seed = 0.0;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r = length(d * vec2(1.78, 1.0));
	vec2 off = normalize(d + vec2(0.00001)) * split * r;
	vec3 c = vec3(texture(screen, uv + off).r, texture(screen, uv).g, texture(screen, uv - off).b);
	float ang = atan(d.y, d.x);
	float ray = step(0.55, hash(floor(ang * 36.0) + seed));
	float streak = ray * smoothstep(0.22, 0.85, r) * lines;
	c = mix(c, vec3(1.0), streak);
	c = mix(c, tint, tint_a * smoothstep(0.15, 0.9, r));
	COLOR = vec4(c, 1.0);
}
"""

var player: Player
var scene: Node
var color := Color(0.35, 0.7, 1.0)
var _mat: ShaderMaterial
var _kind := ""
var _time := -10.0
var _seed := 0.0
var _last_dodge := -10.0
var _bolts: Array = []
var _flash_rect: ColorRect
var _clock := 0.0
## Quieter flashes and lines (a fight crowded with other effects).
var calm := false


func attach(p: Player, s: Node, c: Color) -> void:
	player = p
	scene = s
	color = c
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = Shader.new()
	_mat.shader.code = IMPACT_SHADER
	rect.material = _mat
	layer.add_child(rect)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	layer.add_child(_flash_rect)
	p.dodged.connect(_on_dodged)
	p.punch_landed.connect(_on_landed)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _on_dodged(move: String) -> void:
	_last_dodge = _clock
	_kind = "clean" if move.begins_with("clean") else "dodge"
	_time = _clock
	_seed = float(Engine.get_process_frames())
	_flash(color, 0.18)


func _on_landed(kind: String, killed: bool) -> void:
	var foe := _target()
	var big := killed
	if killed:
		_kind = "ko"
	elif kind == "counter" or _clock - _last_dodge < 1.8:
		_kind = "counter"
	else:
		return
	_time = _clock
	_seed = float(Engine.get_process_frames())
	_flash(Color(0.85, 0.95, 1.0) if big else color, (0.2 if calm else 0.55) if big else (0.06 if calm else 0.2))
	if foe == null:
		return
	var at := foe.global_position + Vector3(0, 1.3, 0)
	var parent := player.get_parent()
	HitFx.ring(parent, at, color.lightened(0.4), (1.1 if calm else 2.4) if big else (0.8 if calm else 1.6))
	HitFx.burst(parent, at, Vector3.UP, color, 30 if big else 16, 9.0 if big else 6.0, true, 0.07)
	if not calm:
		HitFx.flash(parent, at, Color(0.8, 0.95, 1.0), 0.9 if big else 0.4)
	player.shake(0.3 if big else 0.15)
	if not calm:
		_lightning(foe.global_position, 1.1, color.lerp(Color.WHITE, 0.45))
		if big:
			_lightning(foe.global_position + Vector3(0, 0.2, 0), 1.4, Color.WHITE)


## The nearest living monster in front of the player.
func _target() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	var forward := -player.global_basis.z
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var to := enemy.global_position - player.global_position
		if enemy.is_dead() and not enemy._flying:
			continue
		if to.length() < best_d and forward.dot(to.normalized()) > 0.3:
			best_d = to.length()
			best = enemy
	return best


func _flash(c: Color, strength: float) -> void:
	_flash_rect.color = Color(c, strength)


func _lightning(at: Vector3, tall: float, bright: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Engine.get_process_frames()
	var material := StandardMaterial3D.new()
	material.albedo_color = bright
	material.emission_enabled = true
	material.emission = bright
	material.emission_energy_multiplier = 7.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var parent := player.get_parent()
	for bolt in 6:
		var a := bolt * TAU / 6.0 + rng.randf_range(-0.3, 0.3)
		var point := at + Vector3(cos(a) * 0.3, rng.randf_range(0.9, 1.6), sin(a) * 0.25) * tall
		var heading := Vector3(cos(a), rng.randf_range(-0.2, 0.7), sin(a) * 0.6).normalized()
		for step in 6:
			var turn := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.5, 0.5), rng.randf_range(-0.6, 0.6))
			var next := point + (heading + turn).normalized() * rng.randf_range(0.12, 0.22) * tall
			var bar := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.025, 0.025, point.distance_to(next))
			box.material = material
			bar.mesh = box
			parent.add_child(bar)
			bar.look_at_from_position((point + next) * 0.5, next, Vector3.UP if absf((next - point).normalized().y) < 0.95 else Vector3.RIGHT)
			_bolts.append({"node": bar, "born": _clock})
			point = next


func _process(delta: float) -> void:
	_clock += delta
	_flash_rect.color.a = maxf(0.0, _flash_rect.color.a - 0.09)
	var age := _clock - _time
	var lines := 0.0
	var split := 0.0
	var tint_a := 0.0
	var tint := color
	match _kind:
		"dodge", "clean":
			tint_a = (0.5 if _kind == "clean" else 0.32) * exp(-age * 6.0)
			split = 0.008 * exp(-age * 9.0)
		"counter":
			lines = 0.8 * exp(-age * 7.0)
			split = 0.014 * exp(-age * 9.0)
			tint = Color(1.0, 0.8, 0.4)
			tint_a = 0.3 * exp(-age * 8.0)
		"ko":
			lines = 1.0 * exp(-age * 3.5)
			split = 0.022 * exp(-age * 6.0)
			tint = Color.WHITE
			tint_a = 0.55 * exp(-age * 5.0)
	if calm:
		lines *= 0.2
		split *= 0.3
		tint_a *= 0.3
	_mat.set_shader_parameter("lines", lines)
	_mat.set_shader_parameter("split", split)
	_mat.set_shader_parameter("tint_a", tint_a)
	_mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	_mat.set_shader_parameter("seed", _seed + floorf(age * 12.0))
	for entry in _bolts.duplicate():
		if _clock - entry.born > 0.33 or not is_instance_valid(entry.node):
			if is_instance_valid(entry.node):
				entry.node.queue_free()
			_bolts.erase(entry)
