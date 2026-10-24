class_name Goon
extends Node3D
## Tony's ghostly family: translucent green goons in fedoras.
##   hold:  Cousin Vinnie (The Muscle) appears behind a monster, pins its arms
##          for a moment, then fades.
##   brawl: The Family (ultimate): walks up to the nearest monster and punches
##          it until its time's up, then fades.

const COLOR := Color(0.45, 1.0, 0.6)
const SPEED := 5.5
const REACH := 1.4
const PUNCH_EVERY := 0.55

var mode := "hold"
var target: Enemy
var life := 2.0
var damage := 2.0
var _punch_timer := 0.0
var _arms: Array[Node3D] = []
var _body: Node3D
var _time := 0.0


static func make(on: Enemy, hold: float) -> Goon:
	var goon := Goon.new()
	goon.mode = "hold"
	goon.target = on
	goon.life = hold
	var away := on.global_position - on.player.global_position if is_instance_valid(on.player) else Vector3.FORWARD
	away.y = 0.0
	goon.position = on.global_position + away.normalized() * 0.6
	return goon


static func brawler(at: Vector3, seconds: float, punch: float) -> Goon:
	var goon := Goon.new()
	goon.mode = "brawl"
	goon.life = seconds
	goon.damage = punch
	goon.position = at
	return goon


func _ready() -> void:
	_build()
	scale = Vector3.ONE * 0.05
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	HitFx.burst(get_parent(), global_position + Vector3.UP, Vector3.UP, COLOR, 18, 3.0, true, 0.05)
	Sfx.play_at("slip", global_position, 0.0, 0.7)


func _physics_process(delta: float) -> void:
	_time += delta
	life -= delta
	if life <= 0.0:
		_fade()
		return
	_body.position.y = sin(_time * 3.0) * 0.05
	if mode == "hold":
		if is_instance_valid(target) and not target.is_dead():
			global_position = global_position.lerp(target.global_position + (global_position - target.global_position).normalized() * 0.6, minf(1.0, 10.0 * delta))
			look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
			for arm in _arms:
				arm.rotation.x = lerpf(arm.rotation.x, 0.0, minf(1.0, 10.0 * delta))  # Arms out, holding on.
		return
	# Brawl: find someone and hit them.
	if not is_instance_valid(target) or target.is_dead():
		target = _nearest()
		if target == null:
			return
	var to := target.global_position - global_position
	to.y = 0.0
	if to.length() > 0.1:
		look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
	if to.length() > REACH:
		global_position += to.normalized() * minf(SPEED * delta, to.length() - REACH * 0.8)
		return
	_punch_timer -= delta
	if _punch_timer <= 0.0:
		_punch_timer = PUNCH_EVERY
		var arm := _arms[randi() % _arms.size()]
		var tween := arm.create_tween()
		tween.tween_property(arm, "rotation:x", 0.05, 0.08)
		tween.tween_property(arm, "rotation:x", -0.9, 0.2)
		target.take_hit(damage, target.global_position + Vector3(0, 1.3, 0), to.normalized() * 2.0, false, "FAMILY")
		HitFx.burst(get_parent(), target.global_position + Vector3(0, 1.3, 0), Vector3.UP, COLOR, 8, 3.0, true, 0.04)
		Sfx.play_at("hit", target.global_position, -4.0, 0.9)


func _nearest() -> Enemy:
	var best: Enemy
	for node in get_parent().get_children() + (get_parent().get_node("Enemies").get_children() if get_parent().has_node("Enemies") else []):
		var enemy := node as Enemy
		if enemy and not enemy.is_dead() and (best == null or enemy.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = enemy
	return best


func _fade() -> void:
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.3, 0.05, 1.3), 0.3)
	tween.tween_callback(queue_free)


func _build() -> void:
	var ghost := StandardMaterial3D.new()
	ghost.albedo_color = Color(COLOR, 0.45)
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.emission_enabled = true
	ghost.emission = COLOR
	ghost.emission_energy_multiplier = 0.8
	var suit := StandardMaterial3D.new()
	suit.albedo_color = Color(0.08, 0.2, 0.12, 0.6)
	suit.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	suit.emission_enabled = true
	suit.emission = Color(0.1, 0.4, 0.2)
	_body = Node3D.new()
	add_child(_body)
	for side in [-1.0, 1.0]:
		_box(_body, Vector3(0.16, 0.8, 0.18), Vector3(0.12 * side, 0.45, 0), suit)
	_box(_body, Vector3(0.5, 0.6, 0.3), Vector3(0, 1.15, 0), suit)
	_box(_body, Vector3(0.12, 0.3, 0.02), Vector3(0, 1.25, -0.16), ghost)  # The shirt.
	_box(_body, Vector3(0.28, 0.3, 0.28), Vector3(0, 1.62, 0), ghost)
	# The fedora.
	_box(_body, Vector3(0.46, 0.04, 0.46), Vector3(0, 1.8, 0), suit)
	_box(_body, Vector3(0.3, 0.16, 0.3), Vector3(0, 1.88, 0), suit)
	for side in [-1.0, 1.0]:
		var eye := Enemy._glow_material(Color(0.8, 1.0, 0.8))
		_box(_body, Vector3(0.05, 0.03, 0.02), Vector3(0.06 * side, 1.65, -0.145), eye)
		var arm := Node3D.new()
		arm.position = Vector3(0.32 * side, 1.4, 0)
		_body.add_child(arm)
		_box(arm, Vector3(0.12, 0.12, 0.6), Vector3(0, 0, -0.25), ghost)
		arm.rotation.x = -0.9  # Hanging down at rest.
		_arms.append(arm)
	var light := OmniLight3D.new()
	light.light_color = COLOR
	light.light_energy = 0.8
	light.omni_range = 3.0
	light.position.y = 1.4
	add_child(light)


func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	parent.add_child(part)
