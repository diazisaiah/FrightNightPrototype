class_name DemoReel
extends SubViewportContainer
## A live gameplay loop for the fighter select screen: the fighter's own hands
## take on a training dummy in a small 3D ring, showing their signature move
## for a few seconds and then their ultimate, over and over. Everything is
## scripted (the dummy has no AI), so it always looks the same.

## Shown along the bottom while each half plays: (tag, move, how it works).
signal caption_changed(tag: String, move: String, how: String)

const SIGNATURE := {
	"berserker": ["Grudge", "Whatever hits him is marked. His next punch on it hits triple and staggers."],
	"combo_master": ["Shockwave", "Every 5th hit of a combo stuns everything nearby and freezes the combo timer."],
	"counter_master": ["Perfect Counter", "Slip the punch, then hook with the matching hand: knocked out in one."],
	"free_runner": ["Dash Punches", "Dash forward and punch: a left Spear Jab runs through a whole line, a right Haymaker blasts them back."],
	"wise_guy": ["Fuggedaboudit", "Once every 10 seconds, a hit that would've landed gets waved off. No damage, no flinch."],
	"elementalist": ["Dual Sigil", "Two powers at once: his punches burst into flame and freeze what they hit."],
}
const EYE := Vector3(0, 1.55, 2.0)
const DUMMY_SPOT := Vector3(0, 0.05, 0)
const SIDE_SPOTS := [Vector3(-3.2, 0.05, -2.6), Vector3(3.0, 0.05, -4.2)]
const LIGHTNING := Color(0.6, 0.85, 1.0)

var fighter := ""
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _fists: Fists
var _dummy: Dummy
var _extras: Array[Dummy] = []
var _overlay: ColorRect
var _overlay_label: Label
var _accent_light: OmniLight3D
var _shake := 0.0
## Bumped on every play/stop so an old loop knows to quit.
var _run_id := 0


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.size = Vector2i(1280, 720)
	_viewport.msaa_3d = Viewport.MSAA_DISABLED if Settings.use_web_profile() else Viewport.MSAA_2X
	_viewport.scaling_3d_scale = Settings.render_scale()
	add_child(_viewport)
	_build_ring()
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(0, 0, 0, 0)
	add_child(_overlay)
	_overlay_label = Label.new()
	_overlay_label.set_anchors_preset(Control.PRESET_CENTER)
	_overlay_label.offset_left = -200.0
	_overlay_label.offset_right = 520.0
	_overlay_label.offset_top = -230.0
	_overlay_label.offset_bottom = -150.0
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.add_theme_font_size_override("font_size", 46)
	_overlay_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_overlay_label.add_theme_constant_override("outline_size", 12)
	_overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay_label)


func _process(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, delta * 0.4)
	if _camera:
		_camera.h_offset = randf_range(-_shake, _shake)
		_camera.v_offset = randf_range(-_shake, _shake)


## Starts the loop for a class (stopping any other).
func play(class_id: String) -> void:
	stop()
	fighter = class_id
	_run_id += 1
	if _fists:
		_fists.queue_free()
	_fists = Fists.new()
	_fists.fighter = class_id
	_camera.add_child(_fists)
	_accent_light.light_color = GameState.fighter_color(class_id)
	_loop(_run_id)


func stop() -> void:
	_run_id += 1
	_overlay.color.a = 0.0
	_overlay_label.text = ""


# --- The ring ---------------------------------------------------------------------

func _build_ring() -> void:
	_world = Node3D.new()
	_viewport.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.32, 0.45)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.05, 0.09)
	env.fog_density = 0.06
	Look.tune_environment(env, "ring")
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_world.add_child(world_env)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = Enemy._box(Vector3(14, 0.1, 14))
	floor_mesh.mesh.material = Enemy._material(Color(0.28, 0.26, 0.3))
	floor_mesh.position.y = -0.05
	_world.add_child(floor_mesh)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(14, 0.1, 14)
	shape.shape = box
	shape.position.y = -0.05
	ground.add_child(shape)
	_world.add_child(ground)
	var rope := Enemy._material(Color(0.65, 0.1, 0.08))
	for z in [-3.5]:
		for h in [0.5, 0.85, 1.2]:
			var line := MeshInstance3D.new()
			line.mesh = Enemy._box(Vector3(9, 0.04, 0.04))
			line.mesh.material = rope
			line.position = Vector3(0, h, z)
			_world.add_child(line)
	for x in [-4.5, 4.5]:
		var post := MeshInstance3D.new()
		post.mesh = Enemy._cylinder(0.08, 1.4)
		post.mesh.material = Enemy._material(Color(0.12, 0.12, 0.14))
		post.position = Vector3(x, 0.7, -3.5)
		_world.add_child(post)
	var key := DirectionalLight3D.new()
	key.light_color = Color(0.7, 0.75, 1.0)
	key.light_energy = 0.5
	key.rotation = Vector3(deg_to_rad(-45), deg_to_rad(30), 0)
	_world.add_child(key)
	for x in [-3.0, 3.0]:
		var torch := OmniLight3D.new()
		torch.light_color = Color(1.0, 0.6, 0.3)
		torch.light_energy = 2.0
		torch.omni_range = 8.0
		torch.position = Vector3(x, 2.2, -1.5)
		_world.add_child(torch)
	_accent_light = OmniLight3D.new()
	_accent_light.light_energy = 3.0
	_accent_light.omni_range = 6.0
	_accent_light.position = Vector3(0, 2.5, -2.0)
	_world.add_child(_accent_light)
	_camera = Camera3D.new()
	_camera.fov = 80.0
	_camera.position = EYE
	_world.add_child(_camera)
	_camera.look_at(Vector3(0, 1.35, 0))
	_dummy = _make_dummy(DUMMY_SPOT)
	for spot in SIDE_SPOTS:
		var extra := _make_dummy(spot)
		extra.visible = false
		_extras.append(extra)


func _make_dummy(spot: Vector3) -> Dummy:
	var dummy: Dummy = load("res://dummy.tscn").instantiate()
	dummy.setup(null, false)
	dummy.position = spot
	_world.add_child(dummy)
	dummy.set_level(2)
	dummy.set_telegraph(2)
	# Face the camera (enemies face -Z).
	dummy.rotation.y = atan2(-(EYE.x - spot.x), -(EYE.z - spot.z))
	dummy.remove_from_group("enemies")
	return dummy


# --- The loop ---------------------------------------------------------------------

func _loop(id: int) -> void:
	while id == _run_id and is_inside_tree():
		_reset()
		var signature: Array = SIGNATURE[fighter]
		caption_changed.emit("Signature move", signature[0], signature[1])
		await _signature(id)
		if id != _run_id:
			return
		await _wait(0.6)
		_reset()
		caption_changed.emit("Ultimate", Ult.NAMES[fighter].capitalize(), Ult.DESCRIPTIONS[fighter])
		_fists.set_power_state(false, true)
		await _wait(0.9)
		await _ultimate(id)
		_fists.set_power_state(false, false)
		await _wait(0.9)


func _reset() -> void:
	_camera.position = EYE
	_camera.look_at(Vector3(0, 1.35, 0))
	_fists.move_amount = 0.0
	_fists.set_power_state(false, false)
	for dummy in [_dummy] + _extras:
		dummy.velocity = Vector3.ZERO
		dummy._knockback = Vector3.ZERO
		dummy._burn_time = 0.0
		dummy._enter(Boxer.State.IDLE, 99.0)
		_hide_label(dummy)
	_dummy.position = DUMMY_SPOT
	for i in _extras.size():
		_extras[i].position = SIDE_SPOTS[i]
		_extras[i].visible = false
	_overlay.color.a = 0.0
	_overlay_label.text = ""


func _signature(id: int) -> void:
	match fighter:
		"elementalist":
			for _round in 2:
				await _punch("jab", "left", 8.0, "")
				await _punch("hook", "right", 16.0, "HOOK!")
				var at := _dummy.global_position + Vector3(0, 1.2, 0)
				HitFx.burst(_world, at, Vector3.UP, Color(1.0, 0.45, 0.1), 30, 5.0, true, 0.08)
				HitFx.burst(_world, at, Vector3.UP, Color(0.55, 0.85, 1.0), 24, 3.5, true, 0.06)
				_popup(_dummy, "BURN + CHILL", Color(0.95, 0.4, 0.7))
				_dummy.ignite(3.0, 2.0)
				Sfx.play("fire", -6.0)
				await _wait(0.9)
				if id != _run_id:
					return
		"wise_guy":
			for attack in ["cross", "left_hook"]:
				await _enemy_swing(attack, 0.75)
				_flash(GameState.fighter_color("wise_guy"), 0.3)
				_popup(_dummy, "FUGGEDABOUDIT!", GameState.fighter_color("wise_guy"))
				Sfx.play("block", -10.0, 1.25)
				await _punch("cross", "right", 12.0, "")
				await _punch("hook", "left", 18.0, "HOOK!")
				await _wait(0.6)
				if id != _run_id:
					return
		"berserker":
			for attack in ["cross", "right_hook"]:
				await _enemy_swing(attack, 0.75)
				_flash(Color(1.0, 0.45, 0.1), 0.35)
				_popup(_dummy, "GRUDGE", Color(1.0, 0.15, 0.1))
				Sfx.play("hurt", -10.0, 0.8)
				await _punch("hook", "right", 24.0, "GRUDGE!")
				await _punch("uppercut", "left", 22.0, "UPPERCUT!")
				await _wait(0.6)
				if id != _run_id:
					return
		"combo_master":
			for _round in 2:
				var hands := ["left", "right"]
				for i in 5:
					var type: String = "hook" if i == 4 else ("jab" if i % 2 == 0 else "cross")
					await _punch(type, hands[i % 2], 4.0 + i, "", 0.07, 0.1)
				_shockwave()
				await _wait(0.9)
				if id != _run_id:
					return
		"counter_master":
			for pair in [["jab", "slip_right", "right"], ["cross", "slip_left", "left"]]:
				await _enemy_swing(pair[0], 0.75, pair[1])
				_flash(GameState.fighter_color("counter_master"), 0.25)
				_popup(_dummy, "CLEAN SLIP", GameState.fighter_color("counter_master"))
				await _wait(0.15)
				await _punch("hook", pair[2], 999.0, "PERFECT KO!", 0.12, 0.3, true)
				HitFx.burst(_world, _dummy.global_position + Vector3(0, 1.4, 0), Vector3.UP, GameState.fighter_color("counter_master"), 30, 5.0, true, 0.05)
				await _wait(1.0)
				if id != _run_id:
					return
				_dummy.position = DUMMY_SPOT
		"free_runner":
			for _round in 2:
				_camera.position = EYE + Vector3(0, 0, 4.5)
				_camera.look_at(Vector3(0, 1.35, 0))
				_fists.move_amount = 1.0
				var tween := create_tween()
				tween.tween_property(_camera, "position", EYE, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				await tween.finished
				_fists.move_amount = 0.0
				await _punch("cross", "right", 26.0, "HAYMAKER!", 0.1, 0.3, true)
				await _wait(1.1)
				if id != _run_id:
					return
				_dummy.position = DUMMY_SPOT


func _ultimate(id: int) -> void:
	match fighter:
		"elementalist":
			_flash(Color(0.95, 0.4, 0.7), 0.35)
			_banner("ELEMENTAL FISTS!", Color(0.95, 0.4, 0.7))
			await _wait(0.4)
			for pair in [["jab", "left", Color(1.0, 0.45, 0.1), "FIREBALL"], ["cross", "right", Color(0.55, 0.85, 1.0), "ICICLE"],
					["hook", "left", Color(0.65, 0.45, 1.0), "ZAP"], ["uppercut", "right", Color(0.95, 0.1, 0.15), "+HEAL"]]:
				await _punch(pair[0], pair[1], 14.0, "", 0.1, 0.25, pair[0] == "uppercut")
				var at := _dummy.global_position + Vector3(0, 1.3, 0)
				HitFx.burst(_world, at, Vector3.UP, pair[2], 26, 5.0, true, 0.07)
				_popup(_dummy, pair[3], pair[2])
				if id != _run_id:
					return
			await _wait(1.0)
		"wise_guy":
			var line := Insults.insult()
			_banner(line, GameState.fighter_color("wise_guy"))
			if Insults.censored(line):
				Sfx.play("bleep", -12.0)
			await _wait(0.9)
			if id != _run_id:
				return
			_flash(Color(1.0, 0.2, 0.1), 0.3)
			_popup(_dummy, "ENRAGED!", Color(1.0, 0.25, 0.15))
			Sfx.play("growl", -6.0, 0.8)
			await _enemy_swing("cross", 0.6, "slip_left")
			for pair in [["jab", "left", 16.0, "x2!"], ["cross", "right", 22.0, "x2!"], ["uppercut", "right", 40.0, "WISE UP!"]]:
				await _punch(pair[0], pair[1], pair[2], pair[3], 0.1, 0.3, pair[0] == "uppercut")
				if id != _run_id:
					return
			_banner(Insults.knockout(), GameState.fighter_color("wise_guy"))
			await _wait(1.4)
		"berserker":
			await _enemy_swing("cross", 0.75)
			_flash(Color(1.0, 0.45, 0.1), 0.45)
			_banner("INFERNO!", Color(1.0, 0.5, 0.15))
			await _wait(0.35)
			_fists.play_punch("uppercut", "right", 0.12, 0.5)
			await _wait(0.12)
			var at := _dummy.global_position + Vector3(0, 1.3, 0)
			_dummy.take_hit(140.0, at, Vector3(0, 0, -2), true, "INFERNO UPPERCUT!")
			_hide_label(_dummy)
			HitFx.burst(_world, at, Vector3.UP, Color(1.0, 0.3, 0.05), 40, 8.0, true, 0.06)
			HitFx.burst(_world, at, Vector3.UP, Color(1.0, 0.6, 0.15), 24, 6.0, true, 0.035)
			_dummy.velocity.y = 6.0
			_dummy.ignite(4.0, 3.0)
			_shake = 0.08
			Sfx.play("heavy", -6.0, 0.6)
			await _wait(2.2)
		"combo_master":
			_overlay.color = Color(0.35, 0.45, 0.75, 0.25)
			var jab := Controls.key_name("punch_left").to_upper()
			var cross := Controls.key_name("punch_right").to_upper()
			var direct := Controls.direct_punches() or Controls.pad()
			var hook_keys := Controls.text("hook").to_upper() if direct else "%s + %s" % [Controls.key_name("sprint").to_upper(), jab]
			var uppercut_keys := Controls.text("uppercut").to_upper() if direct else "%s + %s" % [Controls.key_name("uppercut_modifier").to_upper(), cross]
			var prompts := [[jab, "jab", "left"], [cross, "cross", "right"], [hook_keys, "hook", "left"], [uppercut_keys, "uppercut", "right"]]
			for i in 12:
				var p: Array = prompts[i % prompts.size()]
				_banner(p[0] + "\n%d HITS" % (i + 1), Color(1.0, 0.85, 0.35))
				await _punch(p[1], p[2], 6.0 + i, "", 0.05, 0.12)
				if id != _run_id:
					return
			_overlay.color.a = 0.0
			_banner("12 HITS!", GameState.fighter_color("combo_master"))
			_dummy.stun(1.0)
			_hide_label(_dummy)
			await _wait(1.4)
		"counter_master":
			_banner("RIPOSTE STANCE", GameState.fighter_color("counter_master"))
			for pair in [["jab", "slip_right", "right"], ["left_hook", "roll_right", "right"], ["cross", "slip_left", "left"]]:
				await _enemy_swing(pair[0], 0.5, pair[1])
				_flash(GameState.fighter_color("counter_master"), 0.2)
				await _punch("hook", pair[2], 30.0, "RIPOSTE!", 0.08, 0.25, true)
				if id != _run_id:
					return
				_dummy.position = DUMMY_SPOT
				await _wait(0.25)
			await _wait(0.8)
		"free_runner":
			for extra in _extras:
				extra.visible = true
			_banner("HIGHLIGHT REEL!", GameState.fighter_color("free_runner"))
			var targets: Array[Dummy] = [_dummy, _extras[0], _extras[1]]
			for i in targets.size():
				var target := targets[i]
				var to := target.global_position - _camera.global_position
				to.y = 0.0
				var stand := target.global_position - to.normalized() * 1.4
				stand.y = EYE.y
				var from := _camera.global_position
				_bolt(from + Vector3(0, -0.6, 0), stand + Vector3(0, -0.6, 0))
				var tween := create_tween()
				tween.tween_property(_camera, "position", stand, 0.12)
				await tween.finished
				_camera.look_at(target.global_position + Vector3(0, 1.3, 0))
				var last := i == targets.size() - 1
				await _punch_at(target, "hook" if last else ("jab" if i % 2 == 0 else "cross"), "left" if i % 2 == 0 else "right",
						60.0 if last else 25.0, "HAYMAKER!" if last else "HIGHLIGHT!")
				if id != _run_id:
					return
				await _wait(0.15)
			await _wait(1.0)


# --- Moves ------------------------------------------------------------------------

func _punch(type: String, hand: String, damage: float, caption := "", impact := 0.12, total := 0.35, stagger := false) -> void:
	await _punch_at(_dummy, type, hand, damage, caption, impact, total, stagger)


func _punch_at(target: Dummy, type: String, hand: String, damage: float, caption := "", impact := 0.12, total := 0.35, stagger := false) -> void:
	_fists.play_punch(type, hand, impact, total)
	await _wait(impact)
	var at := target.global_position + Vector3(randf_range(-0.12, 0.12), randf_range(1.2, 1.5), 0.25)
	var push := (target.global_position - _camera.global_position)
	push.y = 0.0
	target.take_hit(damage, at, push.normalized() * (4.0 if stagger else 1.5), stagger, caption)
	_hide_label(target)
	_shake = maxf(_shake, 0.025 if not stagger else 0.06)
	Sfx.play("heavy" if stagger else "hit", -12.0, randf_range(0.9, 1.15))
	await _wait(maxf(total - impact, 0.05))


## The dummy winds up an attack (its glove flashes the dodge color), then
## throws it; dodge (a camera lean) answers it at the last moment.
func _enemy_swing(attack: String, windup: float, dodge := "") -> void:
	_dummy._begin_attack(attack, windup)
	await _wait(maxf(windup - Enemy.TELL_FLASH_TIME, 0.05))
	_dummy._flashed = true
	_dummy._flash_tell(Boxer.CUES[attack].color)
	await _wait(Enemy.TELL_FLASH_TIME - 0.08)
	if dodge != "":
		_lean(dodge)
	await _wait(0.08)
	_dummy._enter(Boxer.State.STRIKE, 0.15)
	await _wait(0.15)
	_dummy._enter(Boxer.State.RECOVER, 0.5)


func _lean(move: String) -> void:
	var offset := Vector3.ZERO
	match move:
		"slip_left":
			offset = Vector3(-0.35, -0.1, 0)
		"slip_right":
			offset = Vector3(0.35, -0.1, 0)
		"roll_left":
			offset = Vector3(-0.35, -0.4, 0)
		"roll_right":
			offset = Vector3(0.35, -0.4, 0)
	var tween := create_tween()
	tween.tween_property(_camera, "position", EYE + offset, 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(0.15)
	tween.tween_property(_camera, "position", EYE, 0.25).set_trans(Tween.TRANS_SINE)
	Sfx.play("slip", -14.0)


func _shockwave() -> void:
	var center := _dummy.global_position + Vector3(0, 1.0, 0)
	HitFx.burst(_world, center, Vector3.UP, Color(1, 0.8, 0.3), 40, 7.0, true, 0.05)
	_popup(_dummy, "SHOCKWAVE!", Color(1, 0.8, 0.3))
	_dummy.stun(0.8)
	_hide_label(_dummy)
	_shake = 0.05
	Sfx.play("counter", -10.0, 0.7)


func _bolt(from: Vector3, to: Vector3) -> void:
	var bolt := Node3D.new()
	_world.add_child(bolt)
	var material := Enemy._glow_material(LIGHTNING)
	var points: Array[Vector3] = [from]
	var side := (to - from).cross(Vector3.UP).normalized()
	for i in range(1, 6):
		points.append(from.lerp(to, i / 6.0) + side * randf_range(-0.3, 0.3) + Vector3.UP * randf_range(-0.2, 0.2))
	points.append(to)
	for i in points.size() - 1:
		var segment := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.04, 0.04, points[i].distance_to(points[i + 1]) + 0.03)
		box.material = material
		segment.mesh = box
		bolt.add_child(segment)
		segment.global_position = (points[i] + points[i + 1]) / 2.0
		if not points[i].is_equal_approx(points[i + 1]):
			segment.look_at(points[i + 1], Vector3.UP)
	var tween := bolt.create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(bolt.queue_free)


func _flash(color: Color, strength: float) -> void:
	_overlay.color = Color(color, strength * 0.5)
	var tween := _overlay.create_tween()
	tween.tween_property(_overlay, "color:a", 0.0, 0.35)


func _banner(text: String, color: Color) -> void:
	_overlay_label.text = text
	_overlay_label.add_theme_color_override("font_color", color)
	_overlay_label.modulate.a = 1.0
	var tween := _overlay_label.create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(_overlay_label, "modulate:a", 0.0, 0.4)


func _popup(target: Dummy, text: String, color: Color) -> void:
	DamagePopup.spawn(_world, text, color, 44, target.global_position + Vector3(0, 2.0, 0))


func _hide_label(dummy: Dummy) -> void:
	dummy._hp_label.visible = false


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
