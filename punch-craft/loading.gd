extends CanvasLayer
## The loading screen between scenes (autoload "Loading"). Instead of a grey
## frame: a portrait, with its aura breathing behind it, embers rising in its
## color and a slow push-in, its name, tagline and a line. Each load picks one
## at random from the Dead League contenders and the playable fighters; the
## Coffin King only once he's been reached, Tony only once he's unlocked.
## Heading into a Dead League bout always shows that bout's contender. Every
## scene change goes through Loading.go(path).
## 2026-10-29: the contender portraits are in-engine renders, and full-screen
## scenes join the pool (SCENES: the four fighters, the Dead League ring),
## creeping in like the portraits. The True Coffin King has his own card,
## only once he's been beaten (and always heading into his bout).

## Long enough for the portrait, aura and embers to show off and the
## tagline to be read, even when the scene itself loads instantly.
const MIN_TIME := 2.0
const FADE_IN := 0.18
const FADE_OUT := 0.35

var _busy := false
var _screen: Control
var _portrait: TextureRect
var _auras: Array[TextureRect] = []
var _dots: Label
var _time := 0.0
var _last_pick := {}

## A line under each fighter's name. Tony's comes from his mouth (Insults).
const FIGHTER_LINES := {
	"berserker": ["Hit me first. See what happens.", "I don't block. Never needed to.", "Hooks and uppercuts. That's the whole plan."],
	"counter_master": ["Let them swing first.", "Every miss is an opening.", "Slip it, then make them pay."],
	"combo_master": ["Don't count the punches. I lose track too.", "Freezing time is cheating. I do it anyway.", "Jab, jab, cross, and the rest you won't see."],
	"free_runner": ["If I'm standing still, something's wrong.", "Bounce off a head, keep moving.", "Dash in, hit, gone."],
	"elementalist": ["Spells take too long. Fists don't.", "I'm old. I'm not slow.", "Fire's in the left hand. Usually."],
}


## Full-screen scenes: [texture, accent, header, name, tagline, line].
const SCENES := {
	"fighters": ["res://art/loading/fighters.png", Color(1.0, 0.45, 0.12), "FRIGHT NIGHT", "THE GRAVEYARD BOUTS",
		"Knock them out before they get back up.", "Hooks and uppercuts hit harder after a jab or cross."],
	"league": ["res://art/dead_league/dead_league_key_art.png", Color(0.95, 0.75, 0.25), "THE DEAD LEAGUE", "FIVE CONTENDERS",
		"Each win breaks a seal on your upgrades.", "Beat all five to reach the Coffin King."],
}
const TRUE_KING_PORTRAIT := "res://art/dead_league/portrait_true.png"


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS


## Fades the loading screen in, loads the scene, swaps to it, fades out.
func go(path: String) -> void:
	if _busy:
		return
	_busy = true
	# Back to camp from a fight: the Soul Shop restocks (SoulShop).
	var from := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	if path.ends_with("camp.tscn") and (from.ends_with("world.tscn") or from.ends_with("dungeon.tscn") or from.ends_with("dead_league_arena.tscn")):
		GameState.fights_done += 1
	get_tree().paused = false
	_build(_pick(path))
	_screen.modulate.a = 0.0
	var fade_in := _screen.create_tween()
	fade_in.tween_property(_screen, "modulate:a", 1.0, FADE_IN)
	await fade_in.finished
	await get_tree().process_frame
	var started := Time.get_ticks_msec()
	var packed: PackedScene
	if OS.has_feature("threads") and ResourceLoader.load_threaded_request(path) == OK:
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		packed = ResourceLoader.load_threaded_get(path)
	else:
		await get_tree().process_frame
		packed = load(path)
	# The fighter's hands, built now rather than as the scene starts (Fists).
	Fists.warm(get_tree(), GameState.player_class)
	var left := MIN_TIME - (Time.get_ticks_msec() - started) / 1000.0
	if left > 0.0:
		await get_tree().create_timer(left, true, false, true).timeout
	get_tree().change_scene_to_packed(packed)
	# Let the new scene build its first frame before revealing it.
	for i in 3:
		await get_tree().process_frame
	var fade_out := _screen.create_tween()
	fade_out.tween_property(_screen, "modulate:a", 0.0, FADE_OUT)
	await fade_out.finished
	_screen.queue_free()
	_screen = null
	_busy = false


## Restarts the current scene behind the loading screen (Dead League rematch).
func reload() -> void:
	go(get_tree().current_scene.scene_file_path)


func _process(delta: float) -> void:
	if _screen == null:
		return
	_time += delta
	# The aura breathes, two layers out of step; the portrait creeps closer.
	for i in _auras.size():
		var aura := _auras[i]
		var pulse := 0.5 + 0.5 * sin(_time * (1.6 + i * 0.7) + i * 1.9)
		aura.modulate.a = 0.45 + 0.4 * pulse
		aura.scale = Vector2.ONE * (1.0 + 0.06 * pulse + i * 0.08)
		aura.pivot_offset = aura.size / 2.0
	_portrait.pivot_offset = _portrait.size / 2.0
	_portrait.scale = Vector2.ONE * (1.0 + minf(_time, 4.0) * 0.012)
	_dots.text = "LOADING" + ".".repeat(int(_time * 3.0) % 4)


## Who shows on this load: {texture, accent, header, name, tagline, line}.
func _pick(path: String) -> Dictionary:
	if path.ends_with("dead_league_arena.tscn"):
		if GameState.true_king_bout:
			return _true_king_card()
		return _boss_card(clampi(GameState.dead_league_bout, 0, DeadLeagueRules.BOSS_COUNT - 1))
	var pool := _pool()
	if pool.size() > 1:
		pool.erase(_last_pick)
	_last_pick = pool.pick_random()
	if _last_pick.has("boss"):
		return _boss_card(_last_pick.boss)
	if _last_pick.has("scene"):
		return _scene_card(_last_pick.scene)
	if _last_pick.has("true_king"):
		return _true_king_card()
	return _fighter_card(_last_pick.fighter)


## Everyone who can show up: the contenders (the last one once he's been
## reached) and the fighters (secret ones once unlocked).
func _pool() -> Array:
	var pool := []
	for i in DeadLeagueRules.BOSS_COUNT:
		if i < DeadLeagueRules.BOSS_COUNT - 1 or GameState.dead_league_unlocked(i):
			pool.append({"boss": i})
	for id in GameState.class_ids():
		pool.append({"fighter": id})
	for id in SCENES:
		pool.append({"scene": id})
	# A secret: only once he's been beaten.
	if Achievements.has("true_king"):
		pool.append({"true_king": true})
	return pool


func _scene_card(id: String) -> Dictionary:
	var scene: Array = SCENES[id]
	return {"scene": scene[0], "accent": scene[1], "header": scene[2], "name": scene[3], "tagline": scene[4],
		"line": scene[5]}


func _true_king_card() -> Dictionary:
	return {"texture": TRUE_KING_PORTRAIT, "accent": DeadLeagueBoss.INSANO_COLOR, "header": "THE DEAD LEAGUE",
		"name": "THE TRUE COFFIN KING", "tagline": "Five rounds. He brings friends.",
		"line": "“%s”" % (load("res://dead_league_arena.gd").TRUE_TAUNTS as Array).pick_random()}


func _boss_card(index: int) -> Dictionary:
	var profile := DeadLeagueRules.boss(index)
	# The Headless can't talk: its lines are stage directions, shown bare.
	var lines: Array = DeadLeagueRules.TAUNTS[profile.id].filter(func(entry: String) -> bool: return entry.length() > 5)
	var said: String = lines.pick_random()
	return {"texture": "res://art/dead_league/portrait_%d.png" % index, "accent": profile.accent,
		"header": "THE DEAD LEAGUE", "name": profile.name, "tagline": profile.tagline,
		"line": said if said.begins_with("(") else "“%s”" % said}


func _fighter_card(id: String) -> Dictionary:
	var info: Dictionary = GameState.CLASSES[id]
	var said: String = Insults.insult() if id == "wise_guy" else FIGHTER_LINES.get(id, [info.tagline]).pick_random()
	return {"texture": "res://art/versus/fighter_%s.png" % id, "accent": info.color,
		"header": info.name.to_upper(), "name": info.fighter.to_upper(), "tagline": info.tagline,
		"line": "“%s”" % said}


func _build(card: Dictionary) -> void:
	if _screen:
		_screen.queue_free()
	_time = 0.0
	_auras.clear()
	var accent: Color = card.accent
	_screen = Control.new()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_screen)
	var back := ColorRect.new()
	back.color = Color(0.012, 0.01, 0.02)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(back)

	if card.has("scene"):
		_scene(card)
	else:
		_stage(card, accent)

	# Darkness from the left so the words read.
	_words(card, accent)


## A full-screen scene behind everything, creeping in.
func _scene(card: Dictionary) -> void:
	_portrait = TextureRect.new()
	_portrait.texture = load(card.scene)
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_portrait)


func _stage(card: Dictionary, accent: Color) -> void:
	# The portrait on the right, its aura glowing behind it.
	var stage := Control.new()
	stage.anchor_left = 0.4
	stage.anchor_right = 1.0
	stage.anchor_bottom = 1.0
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(stage)
	for i in 2:
		var aura := TextureRect.new()
		aura.texture = _glow(accent)
		aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		aura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		aura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(aura)
		_auras.append(aura)
	_portrait = TextureRect.new()
	_portrait.texture = load(card.texture)
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.offset_top = 30
	_portrait.offset_bottom = -30
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Portraits can be opaque art on a dark background: fade their edges
	# into the screen so the aura glows around them, not around a box.
	var feather := ShaderMaterial.new()
	feather.shader = _feather_shader()
	_portrait.material = feather
	stage.add_child(_portrait)
	stage.add_child(_embers(accent))


func _words(card: Dictionary, accent: Color) -> void:
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.012, 0.01, 0.02, 1.0))
	gradient.add_point(0.45, Color(0.012, 0.01, 0.02, 0.85))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.012, 0.01, 0.02, 0.0))
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.fill_to = Vector2(1, 0)
	shade.texture = shade_texture
	shade.anchor_right = 0.62
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(shade)

	# Name, tagline and a taunt, down the left.
	var words := VBoxContainer.new()
	words.anchor_left = 0.0
	words.anchor_top = 0.5
	words.anchor_right = 0.55
	words.anchor_bottom = 0.5
	words.offset_left = 72
	words.offset_top = -120
	words.offset_bottom = 120
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 10)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(words)
	var league := UiTheme.title_label(card.header, 20, Color(accent.lightened(0.35), 0.8))
	words.add_child(league)
	var name_label := UiTheme.title_label(card.name, 76, accent.lightened(0.15))
	words.add_child(name_label)
	var tagline := UiTheme.title_label(card.tagline, 28, UiTheme.TEXT)
	words.add_child(tagline)
	var taunt := Label.new()
	taunt.text = card.line
	taunt.add_theme_font_size_override("font_size", 19)
	taunt.add_theme_color_override("font_color", UiTheme.MUTED)
	taunt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	taunt.custom_minimum_size.x = 520
	words.add_child(taunt)

	# LOADING..., bottom left, with a thin bar sweeping under it.
	_dots = UiTheme.title_label("LOADING", 18, Color(UiTheme.TEXT, 0.6))
	_dots.anchor_top = 1.0
	_dots.anchor_bottom = 1.0
	_dots.offset_left = 72
	_dots.offset_top = -64
	_dots.offset_bottom = -40
	_screen.add_child(_dots)
	var bar := ColorRect.new()
	bar.color = accent
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 72
	bar.offset_right = 72
	bar.offset_top = -34
	bar.offset_bottom = -31
	_screen.add_child(bar)
	var sweep := bar.create_tween().set_loops()
	sweep.tween_property(bar, "offset_right", 72 + 220.0, 0.9).set_trans(Tween.TRANS_SINE)
	sweep.tween_property(bar, "offset_left", 72 + 220.0, 0.5).set_trans(Tween.TRANS_SINE)
	sweep.tween_callback(func() -> void:
		bar.offset_left = 72
		bar.offset_right = 72)

	# Stagger the words in.
	for i in words.get_child_count():
		var line: Control = words.get_child(i)
		line.modulate.a = 0.0
		var tween := line.create_tween()
		tween.tween_interval(0.08 + i * 0.09)
		tween.tween_property(line, "modulate:a", 1.0, 0.3)


## Embers rising off the contender in its color.
func _embers(accent: Color) -> CPUParticles2D:
	var embers := CPUParticles2D.new()
	embers.amount = 70
	embers.lifetime = 3.2
	embers.preprocess = 3.2
	embers.position = Vector2(380, 760)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(330, 40)
	embers.direction = Vector2(0, -1)
	embers.spread = 18.0
	embers.gravity = Vector2(0, -14)
	embers.initial_velocity_min = 40.0
	embers.initial_velocity_max = 110.0
	embers.scale_amount_min = 2.0
	embers.scale_amount_max = 5.0
	embers.angular_velocity_min = -90.0
	embers.angular_velocity_max = 90.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(accent.lightened(0.5), 0.0))
	ramp.add_point(0.15, Color(accent.lightened(0.4), 1.0))
	ramp.add_point(0.6, Color(accent, 0.8))
	ramp.set_color(ramp.get_point_count() - 1, Color(accent.darkened(0.3), 0.0))
	embers.color_ramp = ramp
	return embers


static var _feather: Shader


static func _feather_shader() -> Shader:
	if _feather == null:
		_feather = Shader.new()
		_feather.code = """
shader_type canvas_item;
// Soft oval fade toward the image's edges.
void fragment() {
	vec4 color = texture(TEXTURE, UV);
	vec2 d = (UV - vec2(0.5, 0.47)) / vec2(0.5, 0.53);
	float edge = 1.0 - smoothstep(0.62, 1.0, length(d));
	color.a *= edge;
	COLOR = color;
}
"""
	return _feather


func _glow(accent: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(accent, 0.55))
	gradient.add_point(0.45, Color(accent.darkened(0.2), 0.18))
	gradient.set_color(gradient.get_point_count() - 1, Color(accent, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture
