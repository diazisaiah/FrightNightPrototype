class_name PrincessRescue
extends SecretEnding
## After the True Coffin King: Princess Plum, chained in a standing coffin.
## Your fighter breaks the chains, the lid swings open, and she is not
## impressed (less so if you came in overalls). She walks herself home. On
## the same stage as SecretEnding; press anything to skip to the end.

const GOWN := Color(0.42, 0.12, 0.38)
const GOWN_TRIM := Color(0.88, 0.72, 0.3)
const LEAF := Color(0.3, 0.6, 0.25)
const WOOD := Color(0.2, 0.12, 0.07)

var _plum: Node3D
var _lid: Node3D
var _chains: Array[Node3D] = []


static func open(parent: Node) -> SecretEnding:
	var rescue := PrincessRescue.new()
	rescue.layer = 81
	rescue.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(rescue)
	return rescue


## Came as the plumber: Tony in the overalls.
static func plumber() -> bool:
	return GameState.player_class == "wise_guy" and GameState.skin("wise_guy") == "plumber_overalls"


func _build_cast() -> void:
	_tony = FighterBody.new(GameState.player_class, "auto")
	_tony.build_budget_ms = 12
	_tony.position = Vector3(-1.4, 0, 0)
	_viewport.add_child(_tony)
	# The coffin stands at the back of the ring, chained shut.
	var coffin := Node3D.new()
	coffin.position = Vector3(1.4, 0, 0.9)
	coffin.rotation.y = PI
	_viewport.add_child(coffin)
	_box(coffin, Vector3(0.95, 2.2, 0.12), Vector3(0, 1.1, 0.3), WOOD)
	for side in [-1.0, 1.0]:
		_box(coffin, Vector3(0.1, 2.2, 0.55), Vector3(0.47 * side, 1.1, 0.05), WOOD)
	_box(coffin, Vector3(0.95, 0.1, 0.55), Vector3(0, 2.2, 0.05), WOOD)
	_box(coffin, Vector3(0.95, 0.1, 0.55), Vector3(0, 0.05, 0.05), WOOD)
	_plum = _build_plum()
	_plum.position = Vector3(1.4, 0, 0.95)
	_viewport.add_child(_plum)
	# The lid hinges on one side.
	_lid = Node3D.new()
	_lid.position = Vector3(0.5, 0, -0.25)
	coffin.add_child(_lid)
	_box(_lid, Vector3(1.0, 2.2, 0.08), Vector3(-0.5, 1.1, 0), WOOD.lightened(0.08))
	# A gold nameplate with a plum on it (no crosses: plain, by the house rule).
	_box(_lid, Vector3(0.5, 0.22, 0.02), Vector3(-0.5, 1.55, -0.05), GOWN_TRIM)
	_box(_lid, Vector3(0.12, 0.12, 0.02), Vector3(-0.5, 1.55, -0.065), GOWN)
	_box(_lid, Vector3(0.06, 0.04, 0.02), Vector3(-0.46, 1.63, -0.065), LEAF)
	for tilt in [0.6, -0.6]:
		var chain := Node3D.new()
		chain.position = Vector3(0, 1.1, -0.32)
		chain.rotation.z = tilt
		coffin.add_child(chain)
		_box(chain, Vector3(0.08, 2.3, 0.05), Vector3.ZERO, GOWN_TRIM.darkened(0.2))
		_chains.append(chain)


## Princess Plum: a plum gown flaring to the floor with a gold hem, gloves,
## dark hair up in a bun, a gold circlet with a plum leaf.
func _build_plum() -> Node3D:
	var plum := Node3D.new()
	var skin := Color(0.86, 0.66, 0.52)
	var hair := Color(0.14, 0.08, 0.06)
	for i in 5:
		var width := 0.82 - i * 0.11
		_box(plum, Vector3(width, 0.2, width * 0.8), Vector3(0, 0.1 + i * 0.2, 0), GOWN if i > 0 else GOWN.darkened(0.15))
	_box(plum, Vector3(0.84, 0.05, 0.68), Vector3(0, 0.03, 0), GOWN_TRIM)
	_box(plum, Vector3(0.36, 0.34, 0.24), Vector3(0, 1.15, 0), GOWN)
	_box(plum, Vector3(0.38, 0.05, 0.26), Vector3(0, 1.3, 0), GOWN_TRIM)
	for side in [-1.0, 1.0]:
		_box(plum, Vector3(0.09, 0.3, 0.09), Vector3(0.23 * side, 1.12, 0), GOWN)
		_box(plum, Vector3(0.08, 0.26, 0.08), Vector3(0.25 * side, 0.85, -0.04), Color(0.95, 0.93, 0.9))
	_box(plum, Vector3(0.1, 0.08, 0.1), Vector3(0, 1.37, 0), skin)
	_box(plum, Vector3(0.28, 0.3, 0.26), Vector3(0, 1.56, 0), skin)
	for side in [-1.0, 1.0]:
		_box(plum, Vector3(0.04, 0.05, 0.02), Vector3(0.06 * side, 1.58, -0.135), Color(0.12, 0.08, 0.1))
	_box(plum, Vector3(0.08, 0.02, 0.02), Vector3(0, 1.48, -0.135), Color(0.6, 0.2, 0.3))
	_box(plum, Vector3(0.3, 0.12, 0.28), Vector3(0, 1.72, 0.02), hair)
	_box(plum, Vector3(0.3, 0.26, 0.06), Vector3(0, 1.58, 0.13), hair)
	_box(plum, Vector3(0.16, 0.16, 0.16), Vector3(0, 1.82, 0.12), hair)
	_box(plum, Vector3(0.32, 0.04, 0.3), Vector3(0, 1.69, 0.0), GOWN_TRIM)
	_box(plum, Vector3(0.08, 0.1, 0.03), Vector3(0, 1.74, -0.15), GOWN)
	_box(plum, Vector3(0.06, 0.04, 0.02), Vector3(0.04, 1.8, -0.16), LEAF)
	return plum


func _process(_delta: float) -> void:
	pass


func _play() -> void:
	await _wait(0.8)
	if _skipped:
		return
	# Over to the coffin, and the chains come off with one shot.
	var to := _plum.position - Vector3(1.3, 0, 0.6)
	_tony.rotation.y = atan2(-(to.x - _tony.position.x), -(to.z - _tony.position.z))
	var walk := _tony.create_tween()
	walk.tween_property(_tony, "position", to, 0.8)
	await _wait(0.9)
	_tony.rotation.y = atan2(-(_plum.position.x - _tony.position.x), -(_plum.position.z - _tony.position.z))
	_tony.play("_uppercut")
	await _wait(0.45)
	Sfx.play("heavy")
	for chain in _chains:
		HitFx.burst(_viewport, chain.global_position, Vector3.UP, GOWN_TRIM, 14, 4.0, true, 0.05)
		chain.queue_free()
	_chains.clear()
	await _wait(0.4)
	Sfx.play("draw", 0.0, 0.8)
	_lid.create_tween().tween_property(_lid, "rotation:y", -1.9, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(0.8)
	_tony.stop()
	_plum.create_tween().tween_property(_plum, "position", _plum.position + Vector3(-0.3, 0, -0.7), 0.6)
	await _wait(0.8)
	if _skipped:
		return
	var plum_color := Color(0.95, 0.8, 1.0)
	var hero_color := Color(1.0, 0.85, 0.3)
	var lines := [[_plum, "Took you long enough."], [_tony, "Traffic."]]
	if plumber():
		lines += [[_plum, "...Are those overalls?"], [_tony, "Long story. There was a toilet."], [_plum, "I'll walk myself home."]]
	else:
		lines += [[_plum, "Wait. Where's the plumber?"], [_tony, "Busy."], [_plum, "...I'll walk myself home."]]
	for line in lines:
		var plum_speaks: bool = line[0] == _plum
		_say(line[0], line[1], plum_color if plum_speaks else hero_color, 1.9, 2.15 if plum_speaks else 2.45)
		await _wait(2.3)
		if _skipped:
			return
	# Off she goes, head high.
	_plum.rotation.y = -PI * 0.5
	var leave := _plum.create_tween()
	leave.tween_property(_plum, "position", _plum.position + Vector3(5.5, 0, 0), 2.4)
	await _wait(1.0)
	_tony.play("bros_shuffle")
	await _wait(2.0)
	if not _skipped:
		_show_end()


func _earn() -> void:
	Achievements.earn("true_king")


func _end_lines() -> Array:
	return [["PRINCESS PLUM IS FREE", 56, UiTheme.GOLD], ["Thank you, %s!" % GameState.fighter_name(), 26, UiTheme.TEXT]]
