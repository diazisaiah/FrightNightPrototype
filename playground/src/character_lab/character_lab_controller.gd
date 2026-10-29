class_name PlaygroundCharacterLab
extends Node
## Owns the playground-only playable avatar, camera modes, reference viewer,
## animation command adapter and simulated remote avatars. Production combat
## stays authoritative; this node only mirrors presentation state.

signal mode_changed(mode: String)

const AvatarScript = preload("res://playground/character_lab/fighter_avatar.gd")
const MODES := ["first_person", "third_person", "inspect"]
const MODE_LABELS := {"first_person": "First person", "third_person": "Third-person follow", "inspect": "Character inspect"}

const DEFAULT_VOXEL := {
	"berserker": "res://art/fighter_berserker_voxel_model.png",
	"counter_master": "res://art/fighter_counter_master_voxel_model.png",
	"combo_master": "res://art/fighter_combo_master_voxel_model.png",
	"free_runner": "res://art/fighter_free_runner_voxel_model.png",
	"wise_guy": "res://art/fighter_tony_voxel_model.png",
	"elementalist": "res://art/fighter_catalyst_voxel_model.png",
}
const DEFAULT_ART := {
	"berserker": "res://art/fighter_berserker_detailed_v2.png",
	"counter_master": "res://art/fighter_counter_master_detailed_v2.png",
	"combo_master": "res://art/fighter_combo_master_detailed_v2.png",
	"free_runner": "res://art/fighter_free_runner_detailed_v2.png",
	"wise_guy": "res://art/fighter_tony.png",
	"elementalist": "res://art/fighter_elementalist.jpg",
}
const ALT_VOXEL := {
	"obsidian_furnace": "res://art/alternate_skins/fighter_berserker_obsidian_furnace_voxel.png",
	"white_noise": "res://art/alternate_skins/fighter_counter_master_white_noise_voxel.png",
	"hyperlight": "res://art/alternate_skins/fighter_combo_master_hyperlight_voxel.png",
	"rooftop_ghost": "res://art/alternate_skins/fighter_free_runner_rooftop_ghost_voxel.png",
	"sunday_best": "res://art/alternate_skins/fighter_wise_guy_sunday_best_voxel.png",
	"verdant_sigil": "res://art/alternate_skins/fighter_elementalist_verdant_sigil_voxel.png",
}
const ALT_ART := {
	"obsidian_furnace": "res://art/alternate_skins/fighter_berserker_obsidian_furnace_art.png",
	"white_noise": "res://art/alternate_skins/fighter_counter_master_white_noise_art.png",
	"hyperlight": "res://art/alternate_skins/fighter_combo_master_hyperlight_art.png",
	"rooftop_ghost": "res://art/alternate_skins/fighter_free_runner_rooftop_ghost_art.png",
	"sunday_best": "res://art/alternate_skins/fighter_wise_guy_sunday_best_art.png",
	"verdant_sigil": "res://art/alternate_skins/fighter_elementalist_verdant_sigil_art.png",
}

var player: Player
var hud: Hud
var avatar: PlaygroundFighterAvatar
var mode := "first_person"
var camera_distance := 3.4
var camera_shoulder := 0.28
var camera_smoothing := 12.0
var camera_relative := true
var facing_mode := "camera_aim"
var hit_direction := "front"
var turntable := false
var neutral_lighting := false

var _camera: Camera3D
var _inspect_yaw := PI
var _inspect_pitch := 0.13
var _dragging := false
var _turntable_yaw := 0.0
var _previous_cooldown := 0.0
var _previous_defense := ""
var _previous_emote := ""
var _previous_active := true
var _inspect_player_state: Dictionary = {}
var _frozen_nodes: Dictionary = {}
var _remotes: Array[PlaygroundFighterAvatar] = []
var _comparison_avatar: PlaygroundFighterAvatar
var _preview_index := 0
var _reference_panel: PanelContainer
var _reference_image: TextureRect
var _reference_title: Label
var _reference_kind := "off"
var _fill: OmniLight3D
var _key: DirectionalLight3D
var _rim: DirectionalLight3D
var _studio_backdrop: MeshInstance3D
var _stats_clock := 0.0
var _cached_triangles := 0
var _hud_hidden := false
var _hand_preview_active := false


func initialize(target: Player, target_hud: Hud = null) -> void:
	player = target
	hud = target_hud
	avatar = AvatarScript.new(GameState.player_class, GameState.skin())
	avatar.name = "AnimatedProductionPlayerBody"
	add_child(avatar)
	avatar.visible = false
	_camera = Camera3D.new()
	_camera.name = "CharacterLabCamera"
	_camera.top_level = true
	_camera.near = 0.04
	_camera.fov = 66.0
	add_child(_camera)
	_build_lighting()
	_build_reference_ui()
	_connect_player()
	_previous_cooldown = float(player._cooldown)
	_previous_defense = String(player._defense)
	_previous_active = player.active
	set_process(true)


func _connect_player() -> void:
	player.attacked.connect(_on_attacked)
	player.grazed.connect(func() -> void: avatar.play_action({"action": "block"}))
	player.dodged.connect(_on_dodged)
	player.knuckles_broken.connect(_on_knocked_out)
	if player.ult:
		player.ult.used.connect(_on_ultimate_used)


func _build_lighting() -> void:
	_fill = OmniLight3D.new()
	_fill.name = "AvatarFill"
	_fill.light_cull_mask = PlaygroundFighterAvatar.BODY_LAYER
	_fill.light_color = Color(1.0, 0.88, 0.78)
	_fill.light_energy = 0.8
	_fill.omni_range = 7.0
	_fill.position = Vector3(1.4, 2.7, -1.8)
	avatar.add_child(_fill)
	_key = DirectionalLight3D.new()
	_key.name = "NeutralReviewKey"
	_key.light_cull_mask = PlaygroundFighterAvatar.BODY_LAYER
	_key.light_color = Color(0.72, 0.82, 1.0)
	_key.light_energy = 0.65
	_key.rotation_degrees = Vector3(-48, -34, 0)
	_key.shadow_enabled = true
	_key.visible = false
	avatar.add_child(_key)
	_rim = DirectionalLight3D.new()
	_rim.name = "NeutralReviewRim"
	_rim.light_cull_mask = PlaygroundFighterAvatar.BODY_LAYER
	_rim.light_color = Color(0.38, 0.58, 1.0)
	_rim.light_energy = 0.9
	_rim.rotation_degrees = Vector3(-24, 152, 0)
	_rim.visible = false
	avatar.add_child(_rim)

	# A large inward-facing cube gives inspection mode a consistent dark studio
	# without replacing or mutating the arena environment resource.
	_studio_backdrop = MeshInstance3D.new()
	_studio_backdrop.name = "NeutralStudioBackdrop"
	_studio_backdrop.top_level = true
	_studio_backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var studio_mesh := BoxMesh.new()
	studio_mesh.size = Vector3(14.0, 8.0, 14.0)
	var studio_material := StandardMaterial3D.new()
	studio_material.albedo_color = Color(0.018, 0.022, 0.03)
	studio_material.roughness = 1.0
	studio_material.cull_mode = BaseMaterial3D.CULL_FRONT
	studio_mesh.material = studio_material
	_studio_backdrop.mesh = studio_mesh
	_studio_backdrop.visible = false
	add_child(_studio_backdrop)


func _build_reference_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CharacterReferenceLayer"
	layer.layer = 28
	add_child(layer)
	_reference_panel = PanelContainer.new()
	_reference_panel.name = "ReferencePanel"
	_reference_panel.anchor_left = 0.69
	_reference_panel.anchor_top = 0.07
	_reference_panel.anchor_right = 0.985
	_reference_panel.anchor_bottom = 0.93
	_reference_panel.offset_left = 0.0
	_reference_panel.offset_top = 0.0
	_reference_panel.offset_right = 0.0
	_reference_panel.offset_bottom = 0.0
	_reference_panel.visible = false
	layer.add_child(_reference_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_reference_panel.add_child(box)
	_reference_title = Label.new()
	_reference_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reference_title.add_theme_font_size_override("font_size", 18)
	box.add_child(_reference_title)
	_reference_image = TextureRect.new()
	_reference_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reference_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reference_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reference_image.custom_minimum_size = Vector2(280, 360)
	box.add_child(_reference_image)
	var note := Label.new()
	note.text = "Reference only · live model stays interactive"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 12)
	box.add_child(note)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_stats_clock += delta
	if _stats_clock >= 0.5:
		_stats_clock = 0.0
		_cached_triangles = _visible_triangle_count()
	_poll_player_actions()
	if mode == "first_person":
		return
	if mode == "inspect":
		_update_inspect_stick(delta)
	_sync_avatar(delta)
	_update_camera(delta)
	if _studio_backdrop:
		_studio_backdrop.global_position = player.global_position + Vector3.UP * 3.0
	if turntable and mode == "inspect":
		_turntable_yaw = wrapf(_turntable_yaw + delta * 0.55, -PI, PI)


func _update_inspect_stick(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down", 0.16)
	if look == Vector2.ZERO:
		return
	look *= look.length()
	var sensitivity := float(Settings.get_value("stick_sensitivity"))
	_inspect_yaw -= look.x * 2.6 * sensitivity * delta
	_inspect_pitch = clampf(_inspect_pitch + look.y * 1.8 * sensitivity * delta, -0.25, 0.85)


func _poll_player_actions() -> void:
	var cooldown := float(player._cooldown)
	if cooldown > _previous_cooldown + 0.045:
		# _last_type is committed only when a punch lands. Infer the just-started
		# clip from the authoritative cooldown and the exact speed multiplier so
		# third-person windup begins on the click, not on impact.
		var type := _punch_type_from_cooldown(cooldown)
		var hand := String(player._last_punch_hand)
		var base: Dictionary = Player.PUNCHES.get(type, {})
		var impact_fraction := float(base.get("impact", cooldown * 0.4)) / maxf(float(base.get("cooldown", cooldown)), 0.01)
		avatar.play_action({
			"action": type, "hand": hand, "duration": cooldown,
			"impact_fraction": impact_fraction, "started_at": Time.get_ticks_msec() / 1000.0,
		})
	_previous_cooldown = cooldown
	var defense := String(player._defense)
	if defense != "" and defense != _previous_defense:
		avatar.play_action({"action": defense, "duration": float(Player.DEFENSES.get(defense, {}).get("window", 0.45)) + 0.2})
	_previous_defense = defense
	if player.emote != _previous_emote:
		_previous_emote = player.emote
		if player.emote != "":
			avatar.play_action({"action": "taunt", "duration": 1.4})
	if player.active and not _previous_active:
		avatar.play_action({"action": "get_up"})
	_previous_active = player.active


func _punch_type_from_cooldown(cooldown: float) -> String:
	var speed := GameState.get_punch_speed() * player.cards.speed_mult()
	var best := "jab"
	var best_gap := INF
	for type in Player.PUNCHES:
		var expected := float(Player.PUNCHES[type].cooldown) / maxf(speed, 0.01)
		var gap := absf(expected - cooldown)
		if gap < best_gap:
			best_gap = gap
			best = type
	return best


func _sync_avatar(delta: float) -> void:
	avatar.visible = true
	var base_yaw := _presentation_yaw()
	var display_yaw := base_yaw + (_turntable_yaw if mode == "inspect" else 0.0)
	var compare_offset := Basis(Vector3.UP, player.global_rotation.y).x * 0.72
	avatar.global_position = player.global_position - (compare_offset if mode == "inspect" and _comparison_avatar else Vector3.ZERO)
	avatar.global_rotation = Vector3(0, display_yaw, 0)
	avatar.set_motion(player.velocity, Basis(Vector3.UP, player.global_rotation.y), player.is_on_floor())
	if _comparison_avatar:
		_comparison_avatar.visible = mode == "inspect"
		_comparison_avatar.global_position = player.global_position + compare_offset
		_comparison_avatar.global_rotation = Vector3(0, display_yaw, 0)
		# Comparison must use the exact same phase, not merely the same clip.
		_comparison_avatar._clock = avatar._clock
		_comparison_avatar._action = avatar._action
		_comparison_avatar._action_time = avatar._action_time
		_comparison_avatar._action_duration = avatar._action_duration
		_comparison_avatar._command = avatar._command.duplicate(true)
		_comparison_avatar._move_local = avatar._move_local
		_comparison_avatar._move_amount = avatar._move_amount
		_comparison_avatar._on_floor = avatar._on_floor
		_comparison_avatar._knocked_down = avatar._knocked_down
		_comparison_avatar._knock_direction = avatar._knock_direction
		_comparison_avatar._apply_pose()
	# Production's emote body must never overlap the lab body.
	player._body.visible = false
	player._fists.visible = false
	if not _camera.current:
		_camera.make_current()
	if mode == "third_person" and camera_relative:
		# Production movement already uses player basis. Mouse/right-stick rotate
		# that basis, so following it makes movement camera-relative without
		# altering combat code.
		_turntable_yaw = move_toward(_turntable_yaw, 0.0, delta * 4.0)


func _presentation_yaw() -> float:
	if facing_mode == "movement_direction":
		var horizontal := Vector3(player.velocity.x, 0, player.velocity.z)
		if horizontal.length_squared() > 0.05:
			return atan2(-horizontal.x, -horizontal.z)
	elif facing_mode == "locked_target":
		var nearest: Node3D
		var nearest_distance := INF
		for candidate in get_tree().get_nodes_in_group("enemies"):
			if candidate is Node3D:
				var distance := player.global_position.distance_squared_to((candidate as Node3D).global_position)
				if distance < nearest_distance:
					nearest = candidate
					nearest_distance = distance
		if nearest:
			var toward := nearest.global_position - player.global_position
			return atan2(-toward.x, -toward.z)
	return player.global_rotation.y


func _update_camera(delta: float) -> void:
	var focus := player.global_position + Vector3.UP * 1.12
	var yaw: float
	var pitch: float
	if mode == "inspect":
		yaw = _inspect_yaw + player.global_rotation.y
		pitch = _inspect_pitch
	else:
		yaw = player.global_rotation.y
		pitch = clampf(0.17 - player._camera.rotation.x * 0.45, -0.12, 0.62)
	var backward := Vector3(sin(yaw), 0, cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var away := backward * cos(pitch) * camera_distance + Vector3.UP * sin(pitch) * camera_distance
	var desired := focus + away + right * camera_shoulder
	var query := PhysicsRayQueryParameters3D.create(focus, desired, 1, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position - (desired - focus).normalized() * 0.22
	var target := Transform3D(Basis.IDENTITY, desired).looking_at(focus, Vector3.UP)
	var weight := 1.0 - exp(-camera_smoothing * delta)
	_camera.global_transform = target if _camera.global_position == Vector3.ZERO else _camera.global_transform.interpolate_with(target, weight)


func set_mode(next_mode: String) -> void:
	if not next_mode in MODES or next_mode == mode:
		return
	if mode == "first_person" and next_mode != "first_person":
		finish_hand_preview()
	var leaving_inspect := mode == "inspect" and next_mode != "inspect"
	if leaving_inspect:
		_set_inspect_frozen(false)
	mode = next_mode
	if mode == "first_person":
		avatar.visible = false
		if _comparison_avatar: _comparison_avatar.visible = false
		_reference_panel.visible = false
		player._body.visible = false
		player._fists.visible = player.emote == ""
		player._camera.make_current()
	elif mode == "third_person":
		player._stop_emote(true)
		avatar.visible = true
		if _comparison_avatar: _comparison_avatar.visible = false
		player._body.visible = false
		player._fists.visible = false
		_camera.global_transform = player._camera.global_transform
		_camera.make_current()
	else:
		player._stop_emote(true)
		avatar.visible = true
		player._body.visible = false
		player._fists.visible = false
		_set_inspect_frozen(true)
		_camera.global_transform = player._camera.global_transform
		_camera.make_current()
	_update_studio_visibility()
	mode_changed.emit(mode)


func toggle_third_person() -> void:
	set_mode("first_person" if mode != "first_person" else "third_person")


func _set_inspect_frozen(frozen: bool) -> void:
	if frozen:
		_inspect_player_state = {
			"process": player.is_processing(), "physics": player.is_physics_processing(),
			"unhandled": player.is_processing_unhandled_input(),
		}
		player.set_process(false)
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		_frozen_nodes.clear()
		for node in get_tree().get_nodes_in_group("enemies"):
			if node is Node:
				_frozen_nodes[node] = [node.is_processing(), node.is_physics_processing()]
				node.set_process(false)
				node.set_physics_process(false)
	else:
		if not _inspect_player_state.is_empty():
			player.set_process(bool(_inspect_player_state.process))
			player.set_physics_process(bool(_inspect_player_state.physics))
			player.set_process_unhandled_input(bool(_inspect_player_state.unhandled))
		for node in _frozen_nodes:
			if is_instance_valid(node):
				node.set_process(bool(_frozen_nodes[node][0]))
				node.set_physics_process(bool(_frozen_nodes[node][1]))
		_frozen_nodes.clear()
		_inspect_player_state.clear()


func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_PAGEUP:
			set_camera_distance(camera_distance - 0.25)
			return true
		if event.physical_keycode == KEY_PAGEDOWN:
			set_camera_distance(camera_distance + 0.25)
			return true
	if mode != "first_person" and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_camera_distance(camera_distance - 0.2)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_camera_distance(camera_distance + 0.2)
			return true
	if mode != "inspect":
		return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			return true
	if event is InputEventMouseMotion and (_dragging or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		_inspect_yaw -= event.relative.x * 0.006
		_inspect_pitch = clampf(_inspect_pitch + event.relative.y * 0.004, -0.25, 0.85)
		return true
	return false


func set_camera_distance(value: float) -> void:
	camera_distance = clampf(value, 1.8, 6.5)


func set_view_preset(preset: String) -> void:
	match preset:
		"front": _inspect_yaw = PI
		"three_quarter": _inspect_yaw = PI * 0.75
		"side": _inspect_yaw = PI * 0.5
		"back": _inspect_yaw = 0.0
	_inspect_pitch = 0.12


func set_neutral_lighting(enabled: bool) -> void:
	neutral_lighting = enabled
	_key.visible = enabled
	_rim.visible = enabled
	_fill.light_energy = 1.15 if enabled else 0.8
	_update_studio_visibility()


func _update_studio_visibility() -> void:
	if _studio_backdrop:
		_studio_backdrop.visible = neutral_lighting and mode == "inspect"


func set_hud_hidden(hidden: bool) -> void:
	_hud_hidden = hidden
	if hud:
		hud.visible = not hidden


func set_reference_opacity(value: float) -> void:
	if _reference_panel:
		_reference_panel.modulate.a = clampf(value, 0.15, 1.0)


func set_reference(kind: String) -> void:
	_reference_kind = kind
	if kind == "off" or kind == "first_person_hands":
		_reference_panel.visible = false
		if kind == "first_person_hands":
			set_mode("first_person")
		return
	var path := ""
	var alternate_id := _alternate_skin_id()
	match kind:
		"default_voxel": path = DEFAULT_VOXEL.get(avatar.fighter_id, "")
		"default_art": path = DEFAULT_ART.get(avatar.fighter_id, "")
		"alternate_voxel": path = ALT_VOXEL.get(alternate_id, "")
		"alternate_art": path = ALT_ART.get(alternate_id, "")
	if path == "":
		_reference_panel.visible = false
		return
	var texture := load(path) as Texture2D
	if texture == null:
		_reference_panel.visible = false
		return
	_reference_image.texture = texture
	_reference_title.text = "%s · %s" % [GameState.fighter_name(avatar.fighter_id), kind.replace("_", " ").to_upper()]
	_reference_panel.visible = true


func _alternate_skin_id() -> String:
	var skins: Array = Skins.of(avatar.fighter_id)
	return String(skins[0]) if not skins.is_empty() else ""


func refresh_reference() -> void:
	set_reference(_reference_kind)


func play_preview(action: String) -> void:
	if mode != "inspect":
		set_mode("inspect")
	_preview_index = maxi(0, PlaygroundFighterAvatar.ACTIONS.find(action))
	avatar.preview(action)


func next_preview() -> void:
	_preview_index = (_preview_index + 1) % PlaygroundFighterAvatar.ACTIONS.size()
	play_preview(PlaygroundFighterAvatar.ACTIONS[_preview_index])


func set_skin(id: String) -> void:
	avatar.set_skin(id)
	_replace_first_person_hands(id)
	if _comparison_avatar:
		_comparison_avatar.queue_free()
		_comparison_avatar = null
	refresh_reference()


func _replace_first_person_hands(id: String) -> void:
	var previous: Fists = player._fists
	var hand_parent := previous.get_parent()
	var replacement := Fists.new()
	replacement.name = "Fists"
	replacement.fighter = avatar.fighter_id
	replacement.skin_id = id
	previous.name = "RetiredFists"
	hand_parent.add_child(replacement)
	replacement.move_amount = previous.move_amount
	replacement.drop = previous.drop
	replacement.visible = mode == "first_person" and player.emote == ""
	player._fists = replacement
	replacement.set_hurt(1.0 - player.knuckles / maxf(player.max_knuckles, 0.001))
	player._update_hand_effects()
	previous.queue_free()


func preview_hands(pose: String) -> void:
	set_reference("first_person_hands")
	_hand_preview_active = true
	var fists: Fists = player._fists
	for tween in fists._tweens.values():
		(tween as Tween).kill()
	fists._tweens.clear()
	fists.stop_idle(false)
	fists._closing = false
	fists.set_power_state(false, false)
	_set_static_hand_pose(fists, "guard" if pose in ["left_punch", "right_punch", "ultimate_ready"] else pose)
	match pose:
		"left_punch":
			fists.play_punch("jab", "left", 0.28, 0.72)
		"right_punch":
			fists.play_punch("cross", "right", 0.3, 0.76)
		"ultimate_ready":
			fists.set_power_state(false, true)


func finish_hand_preview() -> void:
	if not _hand_preview_active or player == null or not is_instance_valid(player._fists):
		return
	var fists: Fists = player._fists
	for tween in fists._tweens.values():
		(tween as Tween).kill()
	fists._tweens.clear()
	fists.stop_idle(false)
	fists._closing = false
	_set_static_hand_pose(fists, "guard")
	player._update_hand_effects()
	_hand_preview_active = false


func _set_static_hand_pose(fists: Fists, pose: String) -> void:
	var shape_id := "fist"
	var pose_offset := Vector3.ZERO
	var rotation_offset := Vector3.ZERO
	if pose == "relaxed":
		shape_id = "relax"
		pose_offset = Vector3(0.035, -0.075, 0.075)
		rotation_offset = Vector3(0.16, -0.04, 0.12)
	elif pose == "open":
		shape_id = "open"
		pose_offset = IdleAnims.POSES.palm_face[0]
		rotation_offset = IdleAnims.POSES.palm_face[1]
	for hand in ["left", "right"]:
		var mirror := -1.0 if hand == "left" else 1.0
		var arm: Node3D = fists._arms[hand]
		arm.position = fists._mirror_pos(Fists.REST_POS + pose_offset, mirror)
		arm.rotation = fists._mirror_rot(Fists.REST_ROT + rotation_offset, mirror)
		fists._apply_shape(hand, IdleAnims.shape(shape_id))


func toggle_skin_comparison() -> void:
	if _comparison_avatar:
		_comparison_avatar.queue_free()
		_comparison_avatar = null
		return
	var skins: Array = Skins.of(avatar.fighter_id)
	if skins.is_empty():
		return
	var other_skin := "" if avatar.skin_id != "" else String(skins[0])
	_comparison_avatar = AvatarScript.new(avatar.fighter_id, other_skin)
	_comparison_avatar.name = "SkinComparisonAvatar"
	add_child(_comparison_avatar)
	_comparison_avatar.set_process(false)
	set_mode("inspect")


func trigger_hit(direction: String, heavy := false) -> void:
	var action := "hit_%s_%s" % [direction, "heavy" if heavy else "light"]
	play_preview(action)


func trigger_knockdown(direction: String) -> void:
	play_preview("knockdown_" + direction)


func trigger_get_up(face_down := false) -> void:
	avatar._knock_direction = "front" if face_down else "back"
	play_preview("get_up_face_down" if face_down else "get_up_face_up")


func trigger_gameplay_punch(type: String, hand: String) -> void:
	if mode == "inspect":
		set_mode("third_person")
	finish_hand_preview()
	player._punch(type, hand)
	_poll_player_actions()


func preview_ultimate(index: int) -> void:
	play_preview("ultimate_1" if index <= 1 else "ultimate_2")


func spawn_remote(count := 1) -> void:
	for unused in mini(count, 4 - (1 + _remotes.size())):
		var candidates: Array = PlaygroundFighterAvatar.FIGHTERS.filter(func(id: String) -> bool: return id != avatar.fighter_id)
		var remote_fighter := String(candidates[_remotes.size() % candidates.size()])
		var remote_skins: Array = Skins.of(remote_fighter)
		var remote_skin := String(remote_skins[0]) if _remotes.size() % 2 == 1 and not remote_skins.is_empty() else ""
		var remote: PlaygroundFighterAvatar = AvatarScript.new(remote_fighter, remote_skin)
		remote.name = "SimulatedRemote%d" % (_remotes.size() + 1)
		add_child(remote)
		var index := _remotes.size()
		var slots := [Vector2(-2.3, -2.15), Vector2(2.3, -2.15), Vector2(1.0, -3.75)]
		var slot: Vector2 = slots[index]
		remote.global_position = player.global_position + player.global_basis.x * slot.x - player.global_basis.z * -slot.y
		remote.global_rotation = Vector3(0, player.global_rotation.y + PI, 0)
		remote.loop_action = true
		remote.apply_locomotion({"local_velocity": Vector3(0.7 if index == 0 else -0.5, 0, -2.4), "grounded": true})
		remote.play_action({
			"action": ["jab", "hook", "hit"][index % 3],
			"hand": "left" if index != 1 else "right",
			"direction": "left", "severity": 0.25,
			"started_at": Time.get_ticks_msec() / 1000.0,
		})
		_remotes.append(remote)


func clear_remotes() -> void:
	for remote in _remotes:
		if is_instance_valid(remote):
			remote.queue_free()
	_remotes.clear()


func _on_attacked(from: Vector3) -> void:
	var local := player.global_basis.inverse() * (from - player.global_position).normalized()
	var direction := "front"
	if absf(local.x) > absf(local.z):
		direction = "right" if local.x > 0.0 else "left"
	elif local.z > 0.0:
		direction = "back"
	avatar.play_action({"action": "hit", "direction": direction, "severity": 0.25, "started_at": Time.get_ticks_msec() / 1000.0})


func _on_dodged(move: String) -> void:
	var clean_move := move.trim_prefix("clean_")
	if clean_move in ["slip_left", "slip_right", "roll_left", "roll_right", "back_step"]:
		avatar.play_action({"action": clean_move})


## Knocked out: down, and back up once the fighter is (the playground and
## training refill the knuckles at once, so active never drops to trigger the
## get-up in _process).
const GET_UP_DELAY := 1.4


func _on_knocked_out() -> void:
	avatar.play_action({"action": "knockdown_" + (["left", "right", "back"].pick_random())})
	get_tree().create_timer(GET_UP_DELAY).timeout.connect(func() -> void:
		if is_instance_valid(avatar) and is_instance_valid(player) and player.active and avatar._knocked_down:
			avatar.play_action({"action": "get_up"}))


func _on_ultimate_used(_fighter: String) -> void:
	var equipped := GameState.ultimate()
	var choices: Array = Abilities.ultimates(GameState.player_class)
	var index := 0
	for i in choices.size():
		if String(choices[i].id) == equipped:
			index = i
	avatar.play_action({"action": "ultimate_1" if index == 0 else "ultimate_2", "ultimate_id": equipped})


func status_text() -> String:
	if avatar == null:
		return "Character Lab is starting…"
	var skin_name := Skins.name_of(avatar.skin_id)
	var fps := int(Performance.get_monitor(Performance.TIME_FPS))
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var frame_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	return "%s · %s · %s\n%s  %d%% · %d FPS / %.2f ms\n%d draws · %dK prims · %dK model tris · %d avatars" % [
		MODE_LABELS[mode], GameState.fighter_name(avatar.fighter_id), skin_name,
		avatar.current_action().replace("_", " ").to_upper(), int(avatar.normalized_time() * 100.0),
		fps, frame_ms, draws, primitives / 1000, _cached_triangles / 1000, _visible_avatar_count(),
	]


func _visible_avatars() -> Array[PlaygroundFighterAvatar]:
	var visible: Array[PlaygroundFighterAvatar] = []
	if avatar and avatar.visible:
		visible.append(avatar)
	for remote in _remotes:
		if is_instance_valid(remote) and remote.visible:
			visible.append(remote)
	if _comparison_avatar and is_instance_valid(_comparison_avatar) and _comparison_avatar.visible:
		visible.append(_comparison_avatar)
	return visible


func _visible_avatar_count() -> int:
	return _visible_avatars().size()


func _visible_triangle_count() -> int:
	var total := 0
	for visible_avatar in _visible_avatars():
		total += visible_avatar.approximate_triangle_count()
	return total


func capture_views() -> void:
	if mode != "inspect":
		set_mode("inspect")
	var before := _inspect_yaw
	var folder := ProjectSettings.globalize_path("user://character_lab_captures")
	DirAccess.make_dir_recursive_absolute(folder)
	for preset in ["front", "three_quarter", "side", "back"]:
		set_view_preset(preset)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var file := "%s_%s_%s.png" % [avatar.fighter_id, avatar.skin_id if avatar.skin_id != "" else "default", preset]
		image.save_png(folder.path_join(file))
	_inspect_yaw = before
