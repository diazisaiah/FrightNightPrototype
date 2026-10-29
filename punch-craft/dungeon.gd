extends Node3D
## The Crypt: a roguelite run through generated floors of rooms beneath the
## graveyard. Each floor is a main path from the entrance to the boss room
## with chest rooms branching off it. Walking into a fight room seals its
## doors until everything inside is dead. Chests hold equipment (see Items)
## that lasts for the rest of the run. The boss room's stairs lead down to a
## harder floor with better loot. Knuckles breaking ends the run.

const WORLD := preload("res://world.gd")

## Room centers sit on a grid this far apart; corridors join neighbors.
const CELL := 28.0
## Room footprints (width along X, depth along Z). Fight rooms pick one; a
## long hall lies along the path through it.
const START_ROOM := Vector2(14, 14)
const CHEST_ROOM := Vector2(12, 12)
const BOSS_ROOM := Vector2(22, 22)
const FIGHT_SIZES := {"small": Vector2(12, 12), "medium": Vector2(16, 16), "large": Vector2(20, 20)}
const HALL_LENGTH := 24.0
const HALL_WIDTH := 12.0
## Interior layouts each fight room size can get. Solid stone blocks break
## line of sight and stop arrows and fireballs.
const LAYOUTS := {
	"small": ["open", "pillars"],
	"medium": ["open", "pillars", "cross", "ring", "corner"],
	"large": ["pillars", "cross", "ring", "corner"],
	"hall": ["open", "pillars"],
}
const PILLAR_SIZE := 1.3
## One fight room per floor holds an elite: a buffed enemy with a trait.
const ELITE_TRAITS := Enemy.ELITE_TRAITS
const ELITE_MIN_DEPTH := 2
const WALL_HEIGHT := 4.5
const WALL_THICKNESS := 0.6
const DOOR_WIDTH := 4.0
## Rooms on the path from the entrance to the boss (both included).
const MAIN_ROOMS := 6
const CHEST_ROOMS := 2
const DIRECTIONS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Enemies per fight room: base + one per room deeper + more per floor.
const ROOM_ENEMIES_BASE := 3
const ROOM_ENEMIES_PER_FLOOR := 1
const ROOM_ENEMIES_MAX := 11
const ROOM_ALIVE_BASE := 3
const ROOM_ALIVE_MAX := 5
const SPAWN_INTERVAL := 1.2
const SPAWN_MIN_DISTANCE := 5.0
## Chance a cleared fight room leaves a chest behind.
const ROOM_CHEST_CHANCE := 0.25
## Enemy types: from the first room to the last on floor 1 the "progress"
## used for picking them goes 0 -> FLOOR_PROGRESS_SPAN, and each floor deeper
## starts FLOOR_PROGRESS_STEP further along. Enemy strength and pay follow
## the Climb instead (Progression.enemy_scaling).
const FLOOR_PROGRESS_SPAN := 0.8
const FLOOR_PROGRESS_STEP := 0.15
const ROOM_CLEAR_COINS := 8
## Clearing a fight room patches up this share of max knuckle HP.
const ROOM_CLEAR_HEAL := 0.1
const FLOOR_CLEAR_COINS := 60
## Kills in the Crypt pay less than in the graveyard: it also pays in items.
const CRYPT_COIN_SCALE := 0.6
const CRYPT_XP_SCALE := 0.6
## Crypt-only enemies, on top of the graveyard's table.
const CRYPT_SCENES := {
	"shieldbearer": preload("res://shieldbearer.tscn"), "wraith": preload("res://wraith.tscn"),
	"mimic": preload("res://mimic.tscn"), "lich": preload("res://lich.tscn"),
	"colossus": preload("res://colossus.tscn"), "lich_king": preload("res://lich_king.tscn"),
}
const CRYPT_ENEMY_TYPES := {
	"shieldbearer": {"name": "Shieldbearer", "unlock": 0.2, "weight": 1.0, "max": [2, 3]},
	"wraith": {"name": "Wraith", "unlock": 0.35, "weight": 0.7, "max": [1, 2]},
	"lich": {"name": "Bone Lich", "unlock": 0.65, "weight": 0.35, "max": [1, 1]},
}
## Floor bosses: floors 1-5 in order, then the cycle repeats (floor 10 is
## the finale), stronger every floor.
const BOSS_ORDER := ["boss", "colossus", "lich_king", "boss", "lich_king"]
const BOSS_CYCLE := ["boss", "colossus", "lich_king"]
const BOSS_ESCORTS := {"boss": ["skeleton", "mage"], "colossus": ["shieldbearer", "shieldbearer"], "lich_king": []}
## Beating this floor's boss clears the Crypt (a win); deeper is endless.
## Ten floors, two per tier of the Climb (Progression); runs start at the
## first floor of the bracket picked at camp. Past floor 10 it's endless.
const FINAL_FLOOR := 10
const VICTORY_COINS := 300
const VICTORY_SOULS := 10
## Side rooms per floor, besides the main path.
const SIDE_ROOMS := ["chest", "chest", "merchant"]
const SHRINE_CHANCE := 0.6
const MERCHANT_ROOM := Vector2(14, 14)
const SHRINE_ROOM := Vector2(12, 12)
## The plumber quest: once you have Overexerted, a floor now and then has a
## room with nothing in it but a toilet. Poop in it TOILET_CLOG times and it
## clogs, and an angry plumber comes for you (Crown-arena tough, in the Fat
## Plumber Cap).
const TOILET_CHANCE := 0.01
const TOILET_ROOM := Vector2(10, 10)
const TOILET_CLOG := 3
const PORCELAIN := Color(0.93, 0.93, 0.9)
## Tests and captures: every floor gets the toilet room.
static var force_toilet := false
## Mimics: share of chests that bite (never boss, elite or cursed chests).
const MIMIC_CHANCE_CHEST_ROOM := 0.25
const MIMIC_CHANCE_DROPPED := 0.15
const MIMIC_WAKE_DISTANCE := 2.6
## Cursed chests: share of ordinary chests, from this floor.
const CURSED_CHANCE := 0.15
## Silver: a currency for this run only, spent at the merchant.
const SILVER_PER_KILL := 1
const SILVER_ELITE := 5
const SILVER_MIMIC := 5
const SILVER_BOSS := 15
const WARE_PRICES := {"uncommon": 12, "rare": 25, "epic": 45, "legendary": 90, "cursed": 40}
const MERCHANT_LEGENDARY_CHANCE := 0.04
const HEAL_PRICE := 15
const HEAL_FRACTION := 0.4
## Shrines take this share of max knuckle HP for a blessing.
const SHRINE_COST := 0.25
const SALVAGE_COINS := {"common": 8, "uncommon": 15, "rare": 30, "epic": 60, "legendary": 120, "cursed": 50, "blessed": 0}
const INTERACT_DISTANCE := 2.4
const FALL_LIMIT := -20.0

const STONE := Color(0.24, 0.23, 0.26)
const FLOOR_STONE := Color(0.15, 0.14, 0.15)
const CEILING_STONE := Color(0.08, 0.08, 0.09)
const IRON := Color(0.25, 0.25, 0.28)
const SEAL_GLOW := Color(0.8, 0.25, 0.15)

var _floor := 1
## This floor's look (Themes.CRYPT): by tier, two floors a tier.
var _theme: Dictionary = Themes.CRYPT[0]
## The floor's hazards (kept apart from _level so batching leaves them be).
var _hazards: Node3D
## The floor this run started on (the Crypt's difficulty ramps from it).
var _start_floor := 1
## Rooms on this floor: {cell, type ("start", "fight", "chest", "boss"),
## depth, size, center, doors: [Vector2i], state, ...}.
var _rooms: Array[Dictionary] = []
var _room_at := {}
var _current_room: Dictionary = {}
var _to_spawn := 0
var _spawn_timer := 0.0
var _alive := 0
var _alive_by_kind := {}
## Chests and stairs the player can use: {node, kind, used}.
var _interactables: Array[Dictionary] = []
var _target: Dictionary = {}
var _pending_item: Dictionary = {}
var _kills := 0
var _run_coins := 0
var _run_xp := 0
var _rooms_cleared := 0
var _floors_cleared_this_run := 0
var _run_souls := 0
var _items_found := 0
var _silver := 0
## What the open offer panel is for: "chest" or "shrine".
var _offer_thing: Dictionary = {}
var _run_over := false
var _level: Node3D
var _materials := {}
## The Crypt merchant on this floor (_build_merchant), or {}.
var _merchant := {}
var _torches: Array[OmniLight3D] = []
var _torch_time := 0.0
var _minimap: Minimap

@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD
@onready var _enemies: Node3D = $Enemies


func _ready() -> void:
	add_to_group("map_scene")  # A tap of the controller emote button opens the map.
	# You bring your kept gear in; what you find is bound to the Crypt until
	# it's gilded at an altar and carried out by the exit stairs.
	_start_floor = Progression.crypt_start_floor(clampi(GameState.crypt_tier, 1, Progression.current_tier()))
	_floor = _start_floor
	GameState.begin_crypt_run()
	Look.tune_environment($WorldEnvironment.environment, "crypt")
	Voxel.prewarm(self, WORLD.SCENES.values() + CRYPT_SCENES.values() + Veterans.SCENES.values())
	FxWarmup.run(self, _player)
	_player.knuckles_changed.connect(_hud.set_knuckles)
	_player.combo_changed.connect(_hud.set_combo)
	_hud.bind_ult(_player.ult)
	Sfx.play_ambience("wind", -22.0, 0.7)  # Muffled, underground.
	_player.attacked.connect(_hud.flash_damage.unbind(1))
	_player.dodged.connect(_hud.show_dodge)
	_player.grazed.connect(_hud.show_graze)
	_player.punch_landed.connect(_hud.hit_marker)
	_player.counter_ready_changed.connect(_hud.set_counter_ready)
	_player.class_status_changed.connect(_hud.set_class_status)
	_player.power_status_changed.connect(_hud.set_power_status)
	_player.class_event.connect(_hud.show_class_event)
	_player.knuckles_broken.connect(_on_knocked_out)
	GameState.leveled_up.connect(_on_leveled_up)
	_hud.end_run_requested.connect(_end_run.bind("ABANDONED"))
	_hud.set_leave_text("Abandon run  (lose finds that aren't gilded)")
	_hud.gild_chosen.connect(_on_gild_chosen)
	_hud.ware_chosen.connect(_on_ware_chosen)
	_hud.back_to_camp_requested.connect(_leave_crypt)
	_hud.continue_requested.connect(_descend)
	_hud.item_decided.connect(_on_item_decided)
	_hud.set_knuckles(_player.knuckles, _player.max_knuckles)
	_hud.set_combo(0, 1.0)
	_hud.set_equipment(GameState.equipped)
	_minimap = Minimap.new()
	_hud.add_minimap(_minimap)
	_build_floor()


func _process(delta: float) -> void:
	_flicker_torches(delta)
	if _run_over:
		return
	if not _current_room.is_empty() and _current_room.state == "fighting":
		_spawn_timer -= delta
		if _to_spawn > 0 and _spawn_timer <= 0.0 and _alive < _room_alive_limit():
			_spawn_timer = SPAWN_INTERVAL
			_to_spawn -= 1
			_spawn_enemy({"kind": _pick_kind(), "armored": randf() < _armor_chance()}, _spawn_point())
		_recount(delta)
	_update_interaction()
	_animate_merchant(delta)
	_update_map()


## Once a second, counts who's really still standing: if the count ever
## drifts, the room still opens when the last one falls.
var _recount_timer := 1.0


func _recount(delta: float) -> void:
	_recount_timer -= delta
	if _recount_timer > 0.0:
		return
	_recount_timer = 1.0
	var living := 0
	for node in _enemies.get_children():
		if node is Enemy and not (node as Enemy).is_dead():
			living += 1
	_alive = living
	if living == 0 and _to_spawn == 0 and _current_room.type != "boss":
		_clear_room(_current_room)


func _unhandled_input(event: InputEvent) -> void:
	# The map key (Controls: M, and Tab unless Tab is a roll, or your own).
	if event.is_action_pressed("map") and not event.is_echo():
		_minimap.set_expanded(not _minimap.expanded)


## Marks the room the player is standing in as visited and refreshes the map.
func _update_map() -> void:
	var at := _player.global_position
	for room in _rooms:
		if not room.visited:
			var half: Vector2 = room.size / 2.0
			if absf(at.x - room.center.x) < half.x and absf(at.z - room.center.z) < half.y:
				room.visited = true
	var icons: Array[Dictionary] = []
	for thing in _interactables:
		# Used things may be gone (a woken mimic's chest).
		if thing.used or not is_instance_valid(thing.node):
			continue
		var node: Node3D = thing.node
		var room: Dictionary = _room_containing(node.global_position)
		if not room.is_empty() and room.visited and thing.kind in Minimap.ICON_COLORS:
			icons.append({"kind": thing.kind, "at": node.global_position})
	_minimap.extra_icons = icons
	_minimap.update_player(at, _player.rotation.y)


func _room_containing(at: Vector3) -> Dictionary:
	for room in _rooms:
		var half: Vector2 = room.size / 2.0
		if absf(at.x - room.center.x) <= half.x and absf(at.z - room.center.z) <= half.y:
			return room
	return {}


func _physics_process(_delta: float) -> void:
	if _player.global_position.y < FALL_LIMIT:
		_player.global_position = _rooms[0].center + Vector3(0, 1, 0)
		_player.velocity = Vector3.ZERO
	# Anything that ends up under the floor, outside the sealed room or inside
	# a solid block (pushed through a wall, a Lich's blink, a Wraith drifting
	# off) goes back into the fight, so a room can always be cleared. Wraiths
	# float through blocks on purpose.
	if _current_room.is_empty() or _current_room.state != "fighting":
		return
	for node in _enemies.get_children():
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var at := enemy.global_position
		if at.y < -5.0 or not _inside_room(_current_room, at, -0.5) or (_in_solid(_current_room, at) and not enemy is Wraith):
			enemy.global_position = _spawn_point()
			enemy.velocity = Vector3.ZERO


func _exit_tree() -> void:
	TimeFx.clear()


# --- Floors -------------------------------------------------------------------

func _build_floor() -> void:
	# One attacker at a time until the Plague tier's floors (7 on), like the Arena.
	Enemy.max_attackers = 1 if _floor < 7 else 2
	if _level:
		_level.queue_free()
	for enemy in _enemies.get_children():
		enemy.queue_free()
	_alive = 0
	_alive_by_kind.clear()
	_interactables.clear()
	_torches.clear()
	_merchant = {}
	_current_room = {}
	_player.on_floor_start()
	# Each tier of floors has its own look, music and hazards.
	var theme := Themes.crypt(_floor)
	if theme.id != _theme.id or _materials.is_empty():
		_materials.clear()
	_theme = theme
	Themes.apply_environment($WorldEnvironment.environment, _theme)
	Sfx.play_music(_theme.music)
	if _hazards:
		_hazards.queue_free()
	_hazards = Node3D.new()
	add_child(_hazards)
	_level = Node3D.new()
	add_child(_level)
	_generate_layout()
	_shape_rooms()
	for room in _rooms:
		_build_room(room)
	for room in _rooms:
		for direction in room.doors:
			# Each corridor once: from the room with the "smaller" side.
			if direction.x > 0 or direction.y > 0:
				_build_corridor(room, _room_at[room.cell + direction])
	_minimap.rooms = _rooms
	_minimap.room_at = _room_at
	var start: Dictionary = _rooms[0]
	_player.global_position = start.center + Vector3(0, 0.1, 0)
	_player.velocity = Vector3.ZERO
	var first_door: Vector2i = start.doors[0]
	_player.rotation = Vector3(0, atan2(-first_door.x, -first_door.y), 0)
	_hud.announce("The Crypt  -  Floor %d" % _floor)
	_update_info()
	# Static decor straight under the level (gates are their own nodes and move).
	Look.batch_meshes(_level)


## A random walk from the entrance to the boss room, plus chest rooms hanging
## off the middle of the path.
func _generate_layout() -> void:
	for attempt in 50:
		_rooms.clear()
		_room_at.clear()
		var cell := Vector2i.ZERO
		_add_room(cell, "start", 0)
		var ok := true
		for depth in range(1, MAIN_ROOMS):
			var options: Array[Vector2i] = []
			for direction in DIRECTIONS:
				# No neighbors other than the room we come from, so the path
				# never touches itself.
				var next: Vector2i = cell + direction
				if not _room_at.has(next) and _free_neighbors(next, cell):
					options.append(next)
			if options.is_empty():
				ok = false
				break
			var next_cell: Vector2i = options.pick_random()
			_add_room(next_cell, "boss" if depth == MAIN_ROOMS - 1 else "fight", depth)
			_connect(cell, next_cell)
			cell = next_cell
		if not ok:
			continue
		var wanted: Array = SIDE_ROOMS.duplicate()
		if randf() < SHRINE_CHANCE:
			wanted.append("shrine")
		if force_toilet or (Achievements.emote_unlocked("overexerted") and randf() < TOILET_CHANCE):
			wanted.append("toilet")
		var placed := 0
		var hosts := _rooms.slice(1, MAIN_ROOMS - 1)
		for type in wanted:
			hosts.shuffle()
			for host in hosts:
				var done := false
				for direction in DIRECTIONS:
					var spot: Vector2i = host.cell + direction
					if not _room_at.has(spot) and _free_neighbors(spot, host.cell):
						_add_room(spot, type, host.depth)
						_connect(host.cell, spot)
						placed += 1
						done = true
						break
				if done:
					break
		# The two chest rooms and the merchant are a must; the shrine is a bonus.
		if placed >= SIDE_ROOMS.size():
			return


func _free_neighbors(cell: Vector2i, allowed: Vector2i) -> bool:
	for direction in DIRECTIONS:
		var neighbor: Vector2i = cell + direction
		if neighbor != allowed and _room_at.has(neighbor):
			return false
	return true


func _add_room(cell: Vector2i, type: String, depth: int) -> void:
	var room := {
		"cell": cell, "type": type, "depth": depth, "size": START_ROOM, "layout": "open", "solids": [],
		"center": Vector3(cell.x * CELL, 0, cell.y * CELL), "doors": [] as Array[Vector2i],
		"state": "waiting" if type in ["fight", "boss"] else "cleared", "blockers": [],
		"elite": false, "visited": type == "start",
	}
	_rooms.append(room)
	_room_at[cell] = room


func _connect(a: Vector2i, b: Vector2i) -> void:
	_room_at[a].doors.append(b - a)
	_room_at[b].doors.append(a - b)


## Sizes, interior layouts and the elite room, once the doors are known.
func _shape_rooms() -> void:
	var elite_options: Array[Dictionary] = []
	for room in _rooms:
		match room.type:
			"start":
				room.size = START_ROOM
			"chest":
				room.size = CHEST_ROOM
			"merchant":
				room.size = MERCHANT_ROOM
			"shrine":
				room.size = SHRINE_ROOM
			"toilet":
				room.size = TOILET_ROOM
			"boss":
				room.size = BOSS_ROOM
				room.layout = "boss"
			"fight":
				var kinds: Array = FIGHT_SIZES.keys()
				# A room whose doors all line up can be a long hall along them.
				var along_x: bool = room.doors.all(func(d: Vector2i) -> bool: return d.x != 0)
				var along_z: bool = room.doors.all(func(d: Vector2i) -> bool: return d.y != 0)
				if along_x or along_z:
					kinds.append("hall")
				var kind: String = kinds.pick_random()
				if kind == "hall":
					room.size = Vector2(HALL_LENGTH, HALL_WIDTH) if along_x else Vector2(HALL_WIDTH, HALL_LENGTH)
				else:
					room.size = FIGHT_SIZES[kind]
				room.layout = LAYOUTS[kind].pick_random()
				if room.depth >= ELITE_MIN_DEPTH and kind != "small":
					elite_options.append(room)
		room.solids = _layout_solids(room)
	if not elite_options.is_empty():
		elite_options.pick_random().elite = true


## Solid blocks inside a room, as rectangles (x, z) around its center.
func _layout_solids(room: Dictionary) -> Array[Rect2]:
	var half: Vector2 = room.size / 2.0
	var solids: Array[Rect2] = []
	var pillar := Vector2.ONE * PILLAR_SIZE
	match room.layout:
		"pillars":
			if room.size.x != room.size.y:
				# Two rows down a hall.
				var long_x: bool = room.size.x > room.size.y
				for along in [-0.25, 0.0, 0.25]:
					for side in [-1.0, 1.0]:
						var spot := Vector2(along * room.size.x, side * half.y * 0.45) if long_x \
								else Vector2(side * half.x * 0.45, along * room.size.y)
						solids.append(Rect2(spot - pillar / 2.0, pillar))
			else:
				for x in [-1.0, 1.0]:
					for z in [-1.0, 1.0]:
						solids.append(Rect2(Vector2(x, z) * half * 0.5 - pillar / 2.0, pillar))
		"cross":
			# Corners filled in: a plus-shaped room with arms to every door.
			var corner := half - Vector2.ONE * (DOOR_WIDTH / 2.0 + 2.0)
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					var outer := Vector2(x * half.x, z * half.y)
					var inner := outer - Vector2(x * corner.x, z * corner.y)
					solids.append(Rect2(Vector2(minf(outer.x, inner.x), minf(outer.y, inner.y)), corner))
		"ring":
			var block: Vector2 = room.size * 0.3
			solids.append(Rect2(-block / 2.0, block))
		"corner":
			var block: Vector2 = half - Vector2.ONE * 2.5
			var x: float = [-1.0, 1.0].pick_random()
			var z: float = [-1.0, 1.0].pick_random()
			var outer := Vector2(x * half.x, z * half.y)
			var inner := outer - Vector2(x * block.x, z * block.y)
			solids.append(Rect2(Vector2(minf(outer.x, inner.x), minf(outer.y, inner.y)), block))
		"boss":
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					solids.append(Rect2(Vector2(x * (half.x - 4.5), z * (half.y - 4.5)) - Vector2.ONE * 0.5, Vector2.ONE))
	return solids


## True if a point is inside the room's walls, at least margin from them.
func _inside_room(room: Dictionary, point: Vector3, margin := 0.0) -> bool:
	var half: Vector2 = room.size / 2.0 - Vector2(margin, margin)
	return absf(point.x - room.center.x) <= half.x and absf(point.z - room.center.z) <= half.y


## True if a point (world space) is inside, or within margin of, a solid block.
func _in_solid(room: Dictionary, point: Vector3, margin := 0.0) -> bool:
	var local := Vector2(point.x - room.center.x, point.z - room.center.z)
	for rect in room.solids:
		if rect.grow(margin).has_point(local):
			return true
	return false


## A free spot near the middle of a room (the middle may be a solid block).
func _open_spot(room: Dictionary) -> Vector3:
	var center: Vector3 = room.center
	for ring in 6:
		for i in 8:
			var offset := Vector2.from_angle(TAU * i / 8.0) * ring * 1.5
			var spot := center + Vector3(offset.x, 0, offset.y)
			if not _in_solid(room, spot, 1.0):
				return spot
	return center


# --- Rooms --------------------------------------------------------------------

## How far along the run this room is, 0-1: picks enemy types and strength.
func _room_progress(room: Dictionary) -> float:
	var along := float(room.depth - 1) / maxf(1.0, MAIN_ROOMS - 3)
	return clampf(along * FLOOR_PROGRESS_SPAN + FLOOR_PROGRESS_STEP * (_floor - 1), 0.0, 1.0)


func _on_room_entered(body: Node3D, room: Dictionary) -> void:
	if body != _player or _run_over or room.state != "waiting":
		return
	_current_room = room
	if room.type == "boss":
		_start_boss_fight(room)
	else:
		_start_fight(room)


func _start_fight(room: Dictionary) -> void:
	room.state = "fighting"
	_player.on_room_start()
	_seal_doors(room)
	_to_spawn = mini(ROOM_ENEMIES_BASE + room.depth + ROOM_ENEMIES_PER_FLOOR * (_floor - 1), ROOM_ENEMIES_MAX)
	_spawn_timer = 0.6
	if room.elite:
		# The elite comes first, with a smaller escort.
		_to_spawn = maxi(1, _to_spawn - 3)
		_spawn_elite(room)
		_hud.announce("An elite blocks the way")
	else:
		_hud.announce_small("The doors seal behind you", SEAL_GLOW)


func _spawn_elite(room: Dictionary) -> void:
	var kinds: Array = []
	var progress := _room_progress(room)
	var types := _enemy_types()
	for kind in types:
		# Melee fighters make the best elites; healers and ranged hang back.
		if progress >= types[kind].unlock and not (kind in ["priest", "skeleton", "mage", "lich"]):
			kinds.append(kind)
	var kind: String = kinds.pick_random()
	_spawn_enemy({"kind": kind, "armored": false, "elite": ELITE_TRAITS.pick_random()}, _spawn_point())


func _start_boss_fight(room: Dictionary) -> void:
	room.state = "fighting"
	_player.on_room_start()
	_seal_doors(room)
	_to_spawn = 0
	Sfx.play("wave", -2.0)
	var names := {"boss": "The Grave Champion rises", "colossus": "The Bone Colossus wakes", "lich_king": "The Lich King awaits"}
	_hud.announce(names[_boss_kind()] + ("   -   FINAL FLOOR" if _floor == FINAL_FLOOR else ""))
	var to_player: Vector3 = _player.global_position - room.center
	to_player.y = 0.0
	var far: Vector3 = room.center - to_player.normalized() * (minf(room.size.x, room.size.y) / 2.0 - 4.0)
	var boss := _boss_kind()
	_spawn_enemy({"kind": boss, "armored": boss != "lich_king"}, Vector3(far.x, 0.1, far.z))
	var across: Vector3 = to_player.normalized().cross(Vector3.UP)
	var escorts: Array = BOSS_ESCORTS[boss]
	for i in escorts.size():
		var spot: Vector3 = far + across * (4.0 if i % 2 == 0 else -4.0)
		_spawn_enemy({"kind": escorts[i], "armored": false}, Vector3(spot.x, 0.1, spot.z))


func _room_alive_limit() -> int:
	return mini(ROOM_ALIVE_BASE + _floor - 1, ROOM_ALIVE_MAX)


func _armor_chance() -> float:
	return clampf((_room_progress(_current_room) - 0.1) * 0.8, 0.0, 0.6)


## A weighted pick of the enemy types unlocked at this room's progress (the
## same table the graveyard uses), respecting how many of each can be alive.
func _pick_kind() -> String:
	var progress := _room_progress(_current_room)
	var choices := {}
	var total := 0.0
	var types := _enemy_types()
	for kind in types:
		var info: Dictionary = types[kind]
		var limit: int = info.max[1] if progress >= WORLD.LATE_NIGHT else info.max[0]
		if progress >= info.unlock and _alive_by_kind.get(kind, 0) < limit:
			choices[kind] = info.weight
			total += info.weight
	var roll := randf() * total
	for kind in choices:
		roll -= choices[kind]
		if roll <= 0.0:
			return kind
	return "zombie"


## The graveyard's enemy table plus the Crypt's own.
func _enemy_types() -> Dictionary:
	var types: Dictionary = WORLD.ENEMY_TYPES.duplicate()
	types.merge(CRYPT_ENEMY_TYPES)
	return types


func _scene(kind: String) -> PackedScene:
	return CRYPT_SCENES[kind] if CRYPT_SCENES.has(kind) else WORLD.SCENES[kind]


## The climb tier this floor belongs to (two floors a tier; deeper keeps counting).
func _tier() -> int:
	return ceili(_floor / float(Progression.FLOORS_PER_TIER))


## Which boss guards this floor.
func _boss_kind() -> String:
	if _floor <= BOSS_ORDER.size():
		return BOSS_ORDER[_floor - 1]
	return BOSS_CYCLE[(_floor - 1) % BOSS_CYCLE.size()]


## Enemies scale to the Climb's par build at this point of the floor
## (Progression.crypt_position).
func _scaling(room: Dictionary) -> Dictionary:
	var progress := _room_progress(room)
	var scaling := _endless(Progression.enemy_scaling(_position(progress), Progression.crypt_difficulty(_floor, _start_floor, progress)), progress)
	scaling.speed = 1.0 + 0.2 * progress
	return scaling


## Past floor 10 the monsters keep growing (Progression.crypt_endless_growth);
## pay stays at floor 10's.
func _endless(scaling: Dictionary, progress := 1.0) -> Dictionary:
	var growth := Progression.crypt_endless_growth(_floor, progress)
	scaling.hp *= growth
	scaling.damage *= growth
	return scaling


## Position on the Climb for this floor (0-1 through it).
func _position(progress := 1.0) -> float:
	return Progression.crypt_position(_floor, progress)


## A free spot inside the current room, away from the player and the blocks.
func _spawn_point() -> Vector3:
	var room := _current_room
	var half: Vector2 = room.size / 2.0 - Vector2(2.0, 2.0)
	for attempt in 40:
		var spot: Vector3 = room.center + Vector3(randf_range(-half.x, half.x), 0.1, randf_range(-half.y, half.y))
		var far_enough := Vector2(spot.x - _player.global_position.x, spot.z - _player.global_position.z).length() >= SPAWN_MIN_DISTANCE
		if far_enough and not _in_solid(room, spot, 1.2):
			return spot
	return _open_spot(room) + Vector3(0, 0.1, 0)


func _spawn_enemy(entry: Dictionary, at: Vector3) -> Enemy:
	var kind: String = entry.kind
	# Deeper floors send veterans (tougher versions with a big move).
	var veteran := Veterans.pick(kind, _tier()) if not kind in BOSS_CYCLE and kind != "mimic" and not entry.has("scaling") else null
	var enemy: Enemy = (veteran if veteran else _scene(kind)).instantiate()
	if veteran:
		enemy.set_meta("veteran", true)
	var night_only := _endless(Progression.enemy_scaling(_position(), Progression.crypt_difficulty(_floor, _start_floor)))
	var is_boss_kind: bool = kind in BOSS_CYCLE
	enemy.setup(_player, entry.armored, entry.scaling if entry.has("scaling") else night_only if is_boss_kind else _scaling(_current_room))
	enemy.set_meta("kind", kind)
	enemy.position = at
	enemy.arena_center = _current_room.center
	enemy.arena_limit = minf(_current_room.size.x, _current_room.size.y) / 2.0 - 2.5
	_enemies.add_child(enemy)
	if entry.has("elite"):
		enemy.make_elite(entry.elite)
		enemy.set_meta("elite", true)
	enemy.died.connect(_on_enemy_died)
	if enemy is Boss:
		enemy.summon_requested.connect(_on_boss_summon.bind(enemy))
	elif enemy is Lich:
		enemy.summon_requested.connect(_on_lich_summon.bind(enemy))
	if enemy.is_boss:
		enemy.health_changed.connect(_hud.set_boss_health)
		_hud.show_boss(enemy.display_name, enemy.hp, enemy.max_hp)
	_alive += 1
	_alive_by_kind[kind] = _alive_by_kind.get(kind, 0) + 1
	# Rises from the floor in a burst of grave dust.
	HitFx.burst(_enemies, at + Vector3(0, 0.3, 0), Vector3.UP, Color(0.45, 0.35, 0.6), 18, 3.0, true, 0.06)
	return enemy


## A Lich raises the dead around itself (capped so rooms don't flood).
func _on_lich_summon(kinds: Array, lich: Lich) -> void:
	if _alive >= ROOM_ALIVE_MAX + 2:
		return
	_hud.announce_small("The Lich raises the dead!", Fireball.BOLT_COLOR)
	for i in kinds.size():
		var offset := Vector2.from_angle(TAU * i / kinds.size()) * 2.5
		var spot := lich.global_position + Vector3(offset.x, 0.1, offset.y)
		if _in_solid(_current_room, spot, 0.8) or not _inside_room(_current_room, spot, 1.5):
			spot = _spawn_point()
		_spawn_enemy({"kind": kinds[i], "armored": false}, spot)


func _on_boss_summon(count: int, boss: Boss) -> void:
	_hud.announce_small("The dead answer his call!", Color(0.8, 0.3, 1.0))
	var half: Vector2 = _current_room.size / 2.0 - Vector2(1.5, 1.5)
	for i in count:
		var offset := Vector2.from_angle(TAU * i / count) * WORLD.SUMMON_RADIUS
		var spot := boss.global_position + Vector3(offset.x, 0.1, offset.y)
		spot.x = clampf(spot.x, _current_room.center.x - half.x, _current_room.center.x + half.x)
		spot.z = clampf(spot.z, _current_room.center.z - half.y, _current_room.center.z + half.y)
		if _in_solid(_current_room, spot, 0.8):
			spot = _spawn_point()
		_spawn_enemy({"kind": "zombie", "armored": false}, spot)


func _on_enemy_died(enemy: Enemy) -> void:
	_alive -= 1
	var kind: String = enemy.get_meta("kind", "")
	_alive_by_kind[kind] = maxi(0, _alive_by_kind.get(kind, 0) - 1)
	_kills += 1
	Bounties.on_ko(enemy)
	var coins := roundi(GameState.roll_coins(enemy.coin_reward) * CRYPT_COIN_SCALE)
	_run_coins += coins
	HitFx.coins(enemy.get_parent(), enemy.global_position + Vector3(0, 1.2, 0), coins)
	GameState.add_resource("coins", coins)
	var xp := roundi(enemy.xp_reward * CRYPT_XP_SCALE * (1.0 + GameState.get_effect("xp_bonus")))
	_run_xp += xp
	var silver := SILVER_BOSS if enemy.is_boss else SILVER_MIMIC if kind == "mimic" else SILVER_PER_KILL
	if enemy.display_name.split(" ").size() > 1 and enemy.max_hp >= 60.0 and enemy.has_meta("elite"):
		silver = SILVER_ELITE
	_silver += silver
	GameState.add_xp(xp)
	_player.heal(GameState.heal_amount("heal_on_kill", _player.max_knuckles))
	_update_info()
	if kind == "mimic":
		# Beaten, it coughs up the real thing.
		_place_chest(Vector3(enemy.global_position.x, 0, enemy.global_position.z), "elite")
	if _run_over or _current_room.is_empty() or _current_room.state != "fighting":
		return
	if enemy.is_boss:
		_hud.hide_boss()
		_win_floor()
	elif _alive == 0 and _to_spawn == 0:
		_clear_room(_current_room)


func _clear_room(room: Dictionary) -> void:
	room.state = "cleared"
	_rooms_cleared += 1
	_open_doors(room)
	var bonus := roundi(ROOM_CLEAR_COINS * 4.0 * Progression.pay(_position()) * GameState.get_wave_bonus_multiplier())
	_run_coins += bonus
	GameState.add_resource("coins", bonus)
	_player.heal(GameState.heal_amount("wave_heal", _player.max_knuckles) + _player.max_knuckles * ROOM_CLEAR_HEAL)
	Sfx.play("clear", -4.0)
	_hud.announce("Room cleared   +%d {coins}" % bonus)
	if room.elite:
		_place_chest(_open_spot(room), "elite")
		if GameState.has_effect("lantern"):
			_place_chest(_open_spot(room) + Vector3(1.6, 0, 0), "elite")
		_hud.announce_small("The elite drops a chest", Color(1, 0.85, 0.4))
	elif room.type == "fight" and randf() < ROOM_CHEST_CHANCE:
		_place_chest(_open_spot(room), "")
		_hud.announce_small("A chest rises from the floor", Color(1, 0.85, 0.4))
	_update_info()


## The boss is down: the rest of the room crumbles, the doors open, a chest
## with a rare (or better) item and the stairs down appear.
func _win_floor() -> void:
	var room := _current_room
	room.state = "cleared"
	_rooms_cleared += 1
	for node in _enemies.get_children():
		var enemy := node as Enemy
		if enemy and not enemy.is_dead():
			enemy._die(Vector3.ZERO)
	_open_doors(room)
	var bonus := roundi(FLOOR_CLEAR_COINS * Progression.pay(_position()) * 2.0 * (1.0 + GameState.get_effect("dawn_bonus")))
	_run_coins += bonus
	GameState.add_resource("coins", bonus)
	var first_time := GameState.clear_crypt_floor(_floor)  # Also saves.
	var souls := Progression.boss_souls(_position(), first_time)
	_run_souls += souls
	GameState.add_souls(souls)
	_hud.add_feed("+%d {souls}" % souls, Color(0.55, 0.95, 0.9))
	_floors_cleared_this_run += 1
	Sfx.play("clear")
	_hud.announce("Floor %d cleared!   +%d {coins}" % [_floor, bonus])
	if _floor == FINAL_FLOOR:
		_win_crypt()
	_place_chest(room.center + Vector3(-2.5, 0, 0), "boss")
	if GameState.has_effect("lantern"):
		_place_chest(room.center + Vector3(-2.5, 0, 2.0), "boss")
	_place_stairs(room.center + Vector3(2.5, 0, 0))
	# A gilding altar rises where the boss fell, to keep what it dropped.
	_build_altar(room.center + Vector3(0, 0, -3.0))
	_hud.announce_small("A gilding altar rises", Color(1, 0.85, 0.4))
	_update_info()


## Floor 5's boss is down: the Crypt is cleared. The first time pays extra.
func _win_crypt() -> void:
	var first := GameState.crypt_wins == 0
	GameState.crypt_wins += 1
	if first:
		var coins := roundi(VICTORY_COINS * Progression.pay(_position()))
		GameState.add_resource("coins", coins)
		GameState.add_souls(VICTORY_SOULS)
		_run_coins += coins
		_run_souls += VICTORY_SOULS
		_hud.add_feed("THE CRYPT IS CLEARED!   +%d {coins}  +%d {souls}" % [coins, VICTORY_SOULS], Color(1, 0.85, 0.4))
	GameState.save_game()
	_hud.announce("THE CRYPT IS CLEARED")


func _descend() -> void:
	_floor += 1
	_hud.resume_after_summary()
	_player.start_fresh()
	_build_floor()


func _update_info() -> void:
	_hud.set_info(("FLOOR %d" % _floor) if _floor <= FINAL_FLOOR else ("FLOOR %d  ·  ENDLESS" % _floor))
	_hud.set_silver(_silver)
	_hud.show_souls()


# --- Chests, items and stairs -----------------------------------------------

## quality "" = a normal chest (which may turn out cursed, or be a mimic);
## "boss" / "elite" roll better; "cursed" holds a cursed item.
func _place_chest(at: Vector3, quality: String, mimic_chance := MIMIC_CHANCE_DROPPED) -> void:
	if quality == "" and randf() < CURSED_CHANCE:
		quality = "cursed"
	var mimic := quality == "" and randf() < mimic_chance
	var chest := Node3D.new()
	chest.position = at
	_level.add_child(chest)
	var wood := _material("wood", Color(0.35, 0.22, 0.12))
	var trim := _material("gold", Color(0.85, 0.65, 0.2), 0.7)
	chest.add_child(_mesh(Enemy._box(Vector3(1.1, 0.6, 0.7)), wood, Vector3(0, 0.3, 0)))
	chest.add_child(_mesh(Enemy._box(Vector3(1.14, 0.08, 0.74)), trim, Vector3(0, 0.55, 0)))
	var lid := Node3D.new()
	lid.position = Vector3(0, 0.6, 0.35)
	chest.add_child(lid)
	lid.add_child(_mesh(Enemy._box(Vector3(1.1, 0.25, 0.7)), wood, Vector3(0, 0.12, -0.35)))
	lid.add_child(_mesh(Enemy._box(Vector3(0.16, 0.16, 0.06)), trim, Vector3(0, 0.05, -0.72)))
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.7, 0.15, 0.9) if quality == "cursed" else Color(1.0, 0.8, 0.4)
	glow.light_energy = 1.6 if quality == "cursed" else 1.2
	glow.omni_range = 3.0
	glow.position.y = 1.0
	chest.add_child(glow)
	if quality == "cursed":
		# Bound in glowing chains.
		var chain := _material("chain", Color(0.55, 0.2, 0.7))
		chain.emission_enabled = true
		chain.emission = Color(0.6, 0.2, 0.9)
		chain.emission_energy_multiplier = 2.0
		for x in [-0.3, 0.3]:
			chest.add_child(_mesh(Enemy._box(Vector3(0.06, 0.95, 0.78)), chain, Vector3(x, 0.45, 0)))
	_add_solid(chest, Vector3(1.1, 0.9, 0.7), Vector3(0, 0.45, 0))
	_interactables.append({"node": chest, "kind": "chest", "quality": quality, "lid": lid, "glow": glow,
			"used": false, "mimic": mimic, "twitch": randf_range(1.0, 3.0)})


func _place_stairs(at: Vector3) -> void:
	var stairs := Node3D.new()
	stairs.position = at
	_level.add_child(stairs)
	var stone := _material("stone", _theme.wall)
	var void_material := _material("void", Color(0.01, 0.0, 0.02))
	stairs.add_child(_mesh(Enemy._box(Vector3(2.2, 0.06, 2.2)), void_material, Vector3(0, 0.03, 0)))
	for i in 3:
		stairs.add_child(_mesh(Enemy._box(Vector3(2.0, 0.2, 0.4)), stone, Vector3(0, 0.04 - 0.05 * i, -0.7 + 0.45 * i)))
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.3, 1.0)
	light.light_energy = 2.0
	light.omni_range = 4.0
	light.position.y = 0.4
	stairs.add_child(light)
	_interactables.append({"node": stairs, "kind": "stairs", "used": false})


## "<use key>  ..." in front of a prompt (F, or B / Circle on a controller).
func _use(what: String) -> String:
	return "%s   %s" % [Controls.key_name("interact"), what]


## Shows "F  ..." for the nearest usable thing, and uses it on F. Mimics wake
## when the player gets close; their lids twitch now and then before that.
func _update_interaction() -> void:
	for thing in _interactables:
		if thing.used or not thing.get("mimic", false):
			continue
		var node: Node3D = thing.node
		thing.twitch -= get_process_delta_time()
		if thing.twitch <= 0.0:
			thing.twitch = randf_range(1.5, 4.0)
			var lid: Node3D = thing.lid
			var tween := lid.create_tween()
			tween.tween_property(lid, "rotation:x", -0.18, 0.06)
			tween.tween_property(lid, "rotation:x", 0.0, 0.1)
		if node.global_position.distance_to(_player.global_position) < MIMIC_WAKE_DISTANCE:
			_wake_mimic(thing)
			return
	_target = {}
	var best := INTERACT_DISTANCE
	for thing in _interactables:
		if thing.used:
			continue
		var node: Node3D = thing.node
		var distance := Vector2(node.global_position.x - _player.global_position.x, node.global_position.z - _player.global_position.z).length()
		if distance < best:
			best = distance
			_target = thing
	if _target.is_empty() or not _player.active:
		_hud.set_prompt("")
		return
	_hud.set_prompt(_prompt_for(_target))
	if Input.is_action_just_pressed("interact"):
		match _target.kind:
			"chest":
				_open_chest(_target)
			"merchant":
				_merchant_grunt()
				_open_merchant()
			"shrine":
				_offer_blessing(_target)
			"altar":
				_open_gilding()
			_:
				_use_stairs()


func _prompt_for(thing: Dictionary) -> String:
	match thing.kind:
		"chest":
			return _use("Open cursed chest") if thing.quality == "cursed" else _use("Open chest")
		"merchant":
			return _use("Trade with the merchant")
		"shrine":
			return _use("Pray at the shrine")
		"altar":
			var bound := _bound_finds().size()
			return _use("Gild your finds  (%d to keep)" % bound) if bound > 0 else "Gilding altar  -  nothing to gild"
	return _use("Descend, or leave the Crypt")


## A chest that was a Mimic all along: the room seals and it stands up.
func _wake_mimic(thing: Dictionary) -> void:
	thing.used = true
	var node: Node3D = thing.node
	var at := Vector3(node.global_position.x, 0.1, node.global_position.z)
	node.queue_free()
	var room := _room_containing(at)
	if room.is_empty():
		return
	_current_room = room
	room.state = "fighting"
	_to_spawn = 0
	_seal_doors(room)
	_player.on_room_start()
	_hud.announce("It's a MIMIC!")
	Sfx.play_at("growl", at, 4.0, 1.4)
	_spawn_enemy({"kind": "mimic", "armored": false}, at)


func _open_chest(chest: Dictionary) -> void:
	chest.used = true
	_hud.set_prompt("")
	var lid: Node3D = chest.lid
	var tween := lid.create_tween()
	tween.tween_property(lid, "rotation:x", -1.9, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var glow: OmniLight3D = chest.glow
	glow.light_energy = 3.0
	Sfx.play("coin")
	# Boss chests are rare or better, elite chests uncommon or better, and
	# either can hold a legendary from floor 2. Cursed chests hold cursed items.
	var item := Items.roll_cursed(_floor) if chest.quality == "cursed" else Items.roll_for_chest(_floor, chest.quality)
	_items_found += 1
	_pending_item = item
	_offer_thing = chest
	var accept := "Take it  (cursed)" if chest.quality == "cursed" else ""
	_hud.show_item_offer(item, GameState.equipped.get(item.slot, {}), _salvage_value(item), accept)


func _salvage_value(item: Dictionary) -> int:
	return roundi(SALVAGE_COINS[item.rarity] * Progression.pay(_position()))


func _on_item_decided(equip: bool) -> void:
	var item := _pending_item
	var thing := _offer_thing
	_pending_item = {}
	_offer_thing = {}
	if item.is_empty():
		return
	match thing.get("kind", "chest"):
		"shrine":
			if equip:
				thing.used = true
				var cost := _player.max_knuckles * SHRINE_COST
				_player._lose_knuckles(minf(cost, _player.knuckles - 1.0))
				GameState.add_blessing(item)
				_player.refresh_max_knuckles()
				_hud.set_equipment(GameState.equipped)
				_hud.add_feed("Blessed: %s" % item.name, Color(0.7, 0.9, 1.0))
				Sfx.play("heal", 0.0, 1.2)
				var light: OmniLight3D = thing.light
				light.light_energy = 0.3
			return
	# A chest's item: equip it, or salvage it for coins.
	if equip:
		_equip(item)
	else:
		var coins := _salvage_value(item)
		_run_coins += coins
		GameState.add_resource("coins", coins)
		_hud.add_feed("Salvaged %s   +%d {coins}" % [item.name, coins], Color(1, 0.85, 0.4))


func _equip(item: Dictionary) -> void:
	if not item.has("uid"):
		item.found = true  # Bound to the Crypt until it's gilded.
	GameState.equip(item)
	_player.refresh_max_knuckles()
	_hud.set_equipment(GameState.equipped)
	_hud.add_feed("Equipped %s" % item.name, Items.rarity_color(item))


## The stairs: go deeper, or leave with your gilded finds.
func _use_stairs() -> void:
	var keep := _bound_finds().filter(func(item: Dictionary) -> bool: return item.get("gilded", false)).size()
	var lose := _bound_finds().size() - keep
	var note := ""
	if keep + lose > 0:
		note = "LEAVE NOW:  KEEP %d GILDED" % keep + ("   ·   LOSE %d" % lose if lose > 0 else "")
	_hud.show_results({
		"title": "THE CRYPT IS CLEARED" if _floor == FINAL_FLOOR else "FLOOR %d CLEARED" % _floor,
		"rewards": {"coins": _run_coins, "xp": _run_xp, "souls": _run_souls},
		"note": note,
	}, "Go deeper" if _floor >= FINAL_FLOOR else "Descend to Floor %d" % (_floor + 1), false, "Leave the Crypt")


# --- Gilding: keeping what you find ------------------------------------------

## Worn finds from this run that aren't kept yet.
func _bound_finds() -> Array:
	var finds: Array = []
	for slot in GameState.equipped:
		var item: Dictionary = GameState.equipped[slot]
		if item.get("found", false):
			finds.append(item)
	return finds


## A gilding altar in each floor's first room and in the boss room once the
## boss falls: pay Souls and silver to gild a find (it turns gold). Gilded
## finds are yours: they leave the Crypt with you by the stairs, and survive
## a knockout too.
func _build_altar(at: Vector3) -> void:
	var altar := StaticBody3D.new()
	altar.position = at
	_level.add_child(altar)
	_block(altar, Vector3(1.0, 0.9, 0.7), Vector3(0, 0.45, 0), _material("stone", _theme.wall))
	var gold := _material("altar_gold", Color(1.0, 0.75, 0.25), 0.8)
	_add_solid_mesh(altar, Vector3(0.8, 0.08, 0.5), Vector3(0, 0.94, 0), gold)
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color(1.0, 0.8, 0.35)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.75, 0.3)
	flame.emission_energy_multiplier = 4.0
	altar.add_child(_mesh(Enemy._box(Vector3(0.18, 0.3, 0.18)), flame, Vector3(0, 1.15, 0)))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.35)
	light.light_energy = 1.8
	light.omni_range = 5.0
	light.position.y = 1.5
	altar.add_child(light)
	_interactables.append({"node": altar, "kind": "altar", "used": false})


func _add_solid_mesh(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	parent.add_child(_mesh(Enemy._box(size), material, pos))


func _open_gilding() -> void:
	var finds := _bound_finds()
	if finds.is_empty():
		return
	var entries := []
	for item in finds:
		var souls: int = Progression.GILD_SOULS.get(item.rarity, 2)
		var silver: int = Progression.GILD_SILVER.get(item.rarity, 20)
		entries.append({"item": item, "souls": souls, "silver": silver,
				"gilded": item.get("gilded", false), "affordable": GameState.souls >= souls and _silver >= silver})
	_hud.show_gild_menu(entries, _silver)


func _on_gild_chosen(item: Dictionary) -> void:
	var silver: int = Progression.GILD_SILVER.get(item.rarity, 20)
	if _silver < silver or not GameState.gild(item):
		Sfx.play("deny", -8.0)
		return
	_silver -= silver
	Sfx.play("unlock", -6.0, 1.3)
	_hud.add_feed("GILDED  %s" % item.name, Color(1.0, 0.8, 0.3))
	_hud.set_equipment(GameState.equipped)
	_update_info()
	_open_gilding()


# --- Merchant and shrine ------------------------------------------------------

## An undead merchant hunched behind a table with three wares and a healing
## flask. He watches you, taps the table and grunts; trading with him (or at
## his table) opens his shop.
func _build_merchant(room: Dictionary) -> void:
	var robe := _material("merchant_robe", Color(0.2, 0.15, 0.1))
	var hood := _material("merchant_hood", Color(0.12, 0.09, 0.07))
	var bone := _material("merchant_bone", Color(0.78, 0.74, 0.62))
	var wood := _material("merchant_wood", Color(0.3, 0.2, 0.12))
	var eyes := Enemy._glow_material(Color(0.5, 1.0, 0.4))
	var root := Node3D.new()
	root.position = room.center + Vector3(0, 0, -3.3)
	_level.add_child(root)
	# A hunched body in a ragged robe.
	root.add_child(_mesh(Enemy._box(Vector3(0.8, 1.15, 0.55)), robe, Vector3(0, 0.58, 0)))
	var torso := Node3D.new()
	torso.position = Vector3(0, 1.1, 0)
	torso.rotation.x = 0.3
	root.add_child(torso)
	torso.add_child(_mesh(Enemy._box(Vector3(0.78, 0.5, 0.52)), robe, Vector3(0, 0.25, 0)))
	torso.add_child(_mesh(Enemy._box(Vector3(0.5, 0.18, 0.4)), hood, Vector3(0, 0.46, -0.1)))
	# A skull in a deep hood: glowing eyes and a jaw that works when he grunts.
	var head := Node3D.new()
	head.position = Vector3(0, 0.62, 0.12)
	torso.add_child(head)
	head.add_child(_mesh(Enemy._box(Vector3(0.3, 0.28, 0.3)), bone, Vector3(0, 0.02, 0)))
	head.add_child(_mesh(Enemy._box(Vector3(0.42, 0.4, 0.34)), hood, Vector3(0, 0.07, -0.07)))
	for side in [-1.0, 1.0]:
		head.add_child(_mesh(Enemy._box(Vector3(0.07, 0.05, 0.02)), eyes, Vector3(0.07 * side, 0.05, 0.155)))
	head.add_child(_mesh(Enemy._box(Vector3(0.05, 0.05, 0.02)), _material("merchant_nose", Color(0.15, 0.12, 0.1)), Vector3(0, -0.03, 0.155)))
	var jaw := Node3D.new()
	jaw.position = Vector3(0, -0.12, 0.02)
	head.add_child(jaw)
	jaw.add_child(_mesh(Enemy._box(Vector3(0.24, 0.07, 0.24)), bone, Vector3(0, -0.03, 0.02)))
	# Long bony arms reaching down to the table.
	var hands: Array = []
	for side in [-1.0, 1.0]:
		var arm := _mesh(Enemy._box(Vector3(0.13, 0.13, 0.7)), robe, Vector3(0.36 * side, 1.25, 0.35))
		arm.rotation.x = 0.55
		root.add_child(arm)
		var hand := Node3D.new()
		hand.position = Vector3(0.36 * side, 0.98, 0.72)
		root.add_child(hand)
		hand.add_child(_mesh(Enemy._box(Vector3(0.16, 0.06, 0.18)), bone, Vector3.ZERO))
		for finger in 3:
			hand.add_child(_mesh(Enemy._box(Vector3(0.03, 0.03, 0.09)), bone, Vector3(-0.05 + finger * 0.05, -0.02, 0.12)))
		hands.append(hand)
	# A lantern on a crooked pole.
	root.add_child(_mesh(Enemy._box(Vector3(0.06, 2.1, 0.06)), wood, Vector3(-0.85, 1.05, 0.1)))
	root.add_child(_mesh(Enemy._box(Vector3(0.4, 0.05, 0.05)), wood, Vector3(-0.68, 2.08, 0.1)))
	var lantern := _material("lantern", Color(1.0, 0.75, 0.3))
	lantern.emission_enabled = true
	lantern.emission = Color(1.0, 0.7, 0.3)
	lantern.emission_energy_multiplier = 3.0
	root.add_child(_mesh(Enemy._box(Vector3(0.14, 0.2, 0.14)), lantern, Vector3(-0.5, 1.88, 0.1)))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 1.8
	light.omni_range = 6.0
	light.position = Vector3(-0.5, 1.8, 0.6)
	root.add_child(light)
	_add_solid(root, Vector3(0.8, 1.9, 0.6), Vector3(0, 0.95, 0))
	# His table, with the wares and a flask on it.
	var table := StaticBody3D.new()
	table.position = root.position + Vector3(0, 0, 0.95)
	_level.add_child(table)
	_block(table, Vector3(3.0, 0.12, 0.9), Vector3(0, 0.86, 0), wood)
	for x in [-1.35, 1.35]:
		for z in [-0.35, 0.35]:
			table.add_child(_mesh(Enemy._box(Vector3(0.1, 0.8, 0.1)), wood, Vector3(x, 0.4, z)))
	_add_solid(table, Vector3(3.0, 0.9, 0.9), Vector3(0, 0.45, 0))
	var wares: Array = []
	for i in 3:
		var item := _merchant_item()
		var token := _ware_token(item, Vector3(-1.1 + i * 0.75, 1.05, 0.05))
		table.add_child(token)
		wares.append({"item": item, "price": int(WARE_PRICES.get(item.rarity, 20)), "sold": false, "token": token})
	var flask := Node3D.new()
	flask.position = Vector3(1.15, 1.04, 0.05)
	table.add_child(flask)
	var potion := StandardMaterial3D.new()
	potion.albedo_color = Color(0.9, 0.15, 0.15)
	potion.emission_enabled = true
	potion.emission = Color(0.9, 0.15, 0.15)
	potion.emission_energy_multiplier = 2.0
	flask.add_child(_mesh(Enemy._box(Vector3(0.16, 0.2, 0.16)), potion, Vector3(0, 0, 0)))
	flask.add_child(_mesh(Enemy._box(Vector3(0.07, 0.08, 0.07)), potion, Vector3(0, 0.14, 0)))
	flask.add_child(_mesh(Enemy._box(Vector3(0.08, 0.04, 0.08)), wood, Vector3(0, 0.2, 0)))
	_merchant = {"root": root, "head": head, "jaw": jaw, "hands": hands, "wares": wares, "flask": flask,
			"heal_used": false, "grunt_in": 0.0, "near": false, "jaw_time": 0.0, "time": 0.0}
	_interactables.append({"node": table, "kind": "merchant", "used": false})


## A ware on the table: a small glowing piece in its rarity's color.
func _ware_token(item: Dictionary, at: Vector3) -> Node3D:
	var color := Items.rarity_color(item)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 2.2
	var token := Node3D.new()
	token.position = at
	var size: Vector3 = {"gloves": Vector3(0.18, 0.14, 0.2), "wraps": Vector3(0.22, 0.08, 0.16),
			"boots": Vector3(0.14, 0.16, 0.24), "charm": Vector3(0.12, 0.12, 0.04)}.get(item.slot, Vector3.ONE * 0.16)
	token.add_child(_mesh(Enemy._box(size), glow, Vector3.ZERO))
	return token


## Breathing, watching you, tapping the table, and grunting now and then.
func _animate_merchant(delta: float) -> void:
	if _merchant.is_empty():
		return
	var root: Node3D = _merchant.root
	_merchant.time += delta
	var time: float = _merchant.time
	var to_player := root.to_local(_player.global_position)
	var near := to_player.length() < 8.0
	var head: Node3D = _merchant.head
	var look := clampf(atan2(to_player.x, to_player.z), -0.8, 0.8) if near else sin(time * 0.4) * 0.4
	head.rotation.y = lerp_angle(head.rotation.y, look, minf(1.0, 4.0 * delta))
	head.rotation.x = sin(time * 1.3) * 0.05
	root.scale.y = 1.0 + sin(time * 1.6) * 0.012
	for i in _merchant.hands.size():
		var hand: Node3D = _merchant.hands[i]
		hand.position.y = 0.98 + maxf(0.0, sin(time * 5.0 + i * 1.4)) * 0.035 * (1.0 if i == 0 else 0.4)
	for ware in _merchant.wares:
		if not ware.sold:
			(ware.token as Node3D).rotation.y += delta * 0.8
	# A grunt when you walk up, then every so often while you're near.
	if near and not _merchant.near:
		_merchant_grunt()
	elif near:
		_merchant.grunt_in -= delta
		if _merchant.grunt_in <= 0.0:
			_merchant_grunt()
	_merchant.near = near
	_merchant.jaw_time = maxf(0.0, _merchant.jaw_time - delta)
	var jaw: Node3D = _merchant.jaw
	jaw.rotation.x = absf(sin(_merchant.jaw_time * 26.0)) * 0.4 if _merchant.jaw_time > 0.0 else 0.0


func _merchant_grunt(pitch := 1.0) -> void:
	var head: Node3D = _merchant.head
	Sfx.play_at("grunt", head.global_position, -2.0, pitch * randf_range(0.85, 1.1))
	_merchant.jaw_time = 0.35
	_merchant.grunt_in = randf_range(5.0, 9.0)


func _open_merchant() -> void:
	var wares: Array = _merchant.wares.map(func(ware: Dictionary) -> Dictionary: return {"item": ware.item, "price": ware.price, "sold": ware.sold})
	_hud.show_merchant(wares, {"price": HEAL_PRICE, "percent": roundi(HEAL_FRACTION * 100), "used": _merchant.heal_used}, _silver)


func _on_ware_chosen(index: int) -> void:
	if index < 0:
		if _merchant.heal_used or _silver < HEAL_PRICE:
			return
		_silver -= HEAL_PRICE
		_merchant.heal_used = true
		(_merchant.flask as Node3D).queue_free()
		_player.heal(_player.max_knuckles * HEAL_FRACTION)
		Sfx.play("heal", 0.0, 1.1)
	else:
		var ware: Dictionary = _merchant.wares[index]
		if ware.sold or _silver < int(ware.price):
			return
		_silver -= int(ware.price)
		ware.sold = true
		(ware.token as Node3D).queue_free()
		Sfx.play("coin")
		_equip(ware.item)
	_merchant_grunt(1.25)
	_update_info()
	_open_merchant()


func _merchant_item() -> Dictionary:
	if _floor >= Items.LEGENDARY_MIN_FLOOR and randf() < MERCHANT_LEGENDARY_CHANCE:
		return Items.roll_legendary(_floor)
	var item := Items.roll(_floor)
	while item.rarity == "common":
		item = Items.roll(_floor)
	return item


## An altar with a pale flame: trade a quarter of your max knuckle HP (taken
## from your current HP) for a blessing that lasts the run.
func _build_shrine(room: Dictionary) -> void:
	var altar := StaticBody3D.new()
	altar.position = room.center
	_level.add_child(altar)
	_block(altar, Vector3(1.4, 1.0, 0.9), Vector3(0, 0.5, 0), _material("stone", _theme.wall))
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color(0.6, 0.85, 1.0)
	flame.emission_enabled = true
	flame.emission = Color(0.6, 0.85, 1.0)
	flame.emission_energy_multiplier = 4.0
	altar.add_child(_mesh(Enemy._box(Vector3(0.25, 0.4, 0.25)), flame, Vector3(0, 1.25, 0)))
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.85, 1.0)
	light.light_energy = 2.5
	light.omni_range = 7.0
	light.position.y = 1.8
	altar.add_child(light)
	_interactables.append({"node": altar, "kind": "shrine", "used": false, "light": light, "blessing": Items.roll_blessing(_floor)})


## A toilet in the middle of an empty room, under one bare bulb. Poops
## dropped near it go in (PoopFx); TOILET_CLOG of them and it clogs.
func _build_toilet(room: Dictionary) -> void:
	var toilet := StaticBody3D.new()
	toilet.position = room.center
	toilet.rotation.y = randi_range(0, 3) * PI / 2.0
	_level.add_child(toilet)
	toilet.add_to_group("toilet")
	var porcelain := _material("porcelain", PORCELAIN, 0.1)
	var seat := _material("toilet_seat", Color(0.85, 0.85, 0.82))
	_block(toilet, Vector3(0.42, 0.36, 0.5), Vector3(0, 0.18, 0), porcelain)
	toilet.add_child(_mesh(Enemy._box(Vector3(0.6, 0.12, 0.72)), porcelain, Vector3(0, 0.42, -0.04)))
	toilet.add_child(_mesh(Enemy._box(Vector3(0.62, 0.04, 0.74)), seat, Vector3(0, 0.5, -0.04)))
	# The tank, its lid and the handle.
	_block(toilet, Vector3(0.66, 0.6, 0.26), Vector3(0, 0.75, 0.38), porcelain)
	toilet.add_child(_mesh(Enemy._box(Vector3(0.7, 0.06, 0.3)), porcelain, Vector3(0, 1.08, 0.38)))
	toilet.add_child(_mesh(Enemy._box(Vector3(0.14, 0.03, 0.04)), _material("chrome", Color(0.8, 0.8, 0.85), 0.9), Vector3(-0.22, 0.92, 0.24)))
	# The water: rises and browns as it clogs.
	var water := _mesh(Enemy._box(Vector3(0.44, 0.02, 0.5)), Enemy._material(Color(0.5, 0.7, 0.85), 0.0), Vector3(0, 0.46, -0.06))
	toilet.add_child(water)
	var bulb := OmniLight3D.new()
	bulb.light_color = Color(1.0, 0.92, 0.75)
	bulb.light_energy = 2.2
	bulb.omni_range = 8.0
	bulb.position = room.center + Vector3(0, 3.4, 0)
	_level.add_child(bulb)
	_level.add_child(_mesh(Enemy._box(Vector3(0.14, 0.18, 0.14)), Enemy._glow_material(Color(1.0, 0.92, 0.7)), bulb.position))
	toilet.set_meta("bowl", Vector3(0, 0.46, -0.06))
	toilet.set_meta("on_poop", _on_toilet_poop.bind(toilet, water, room))


## A poop went in. TOILET_CLOG of them and it overflows, and the plumber
## comes to sort you out.
func _on_toilet_poop(toilet: Node3D, water: MeshInstance3D, room: Dictionary) -> void:
	if _run_over or room.state != "cleared":
		return
	var clog := int(toilet.get_meta("clog", 0)) + 1
	toilet.set_meta("clog", clog)
	Sfx.play_at("heavy", toilet.global_position, -8.0, 0.6)
	var murk := Color(0.5, 0.7, 0.85).lerp(Color(0.4, 0.3, 0.15), float(clog) / TOILET_CLOG)
	((water.mesh as BoxMesh).material as StandardMaterial3D).albedo_color = murk
	water.create_tween().tween_property(water, "position:y", 0.46 + 0.02 * clog, 0.4)
	if clog < TOILET_CLOG:
		_hud.announce_small("The toilet gurgles..." if clog == 1 else "The toilet groans!", Color(0.7, 0.6, 0.4))
		return
	toilet.set_meta("clog", 0)
	var at := toilet.global_position
	HitFx.burst(_level, at + Vector3(0, 0.6, 0), Vector3.UP, Color(0.4, 0.3, 0.15), 30, 4.0, false, 0.06)
	Sfx.play_at("growl", at, 2.0, 0.8)
	var drain := water.create_tween()
	drain.tween_interval(1.5)
	drain.tween_property(water, "position:y", 0.46, 1.5)
	drain.tween_callback(func() -> void: ((water.mesh as BoxMesh).material as StandardMaterial3D).albedo_color = Color(0.5, 0.7, 0.85))
	_current_room = room
	room.state = "fighting"
	_to_spawn = 0
	_seal_doors(room)
	_player.on_room_start()
	_hud.announce("YOU CLOGGED IT!")
	var scaling := Progression.enemy_scaling(maxf(_position(), Progression.arena_position(5, 1)),
			maxf(Progression.crypt_difficulty(_floor, _start_floor), Progression.arena_difficulty(5, 1)))
	scaling.hat = "fat_plumber_cap"
	scaling.gear = {}
	var away := Vector3(at.x - _player.global_position.x, 0, at.z - _player.global_position.z).normalized()
	var spot := at + away * 2.5
	if _in_solid(room, spot, 1.0) or not _inside_room(room, spot, 1.5):
		spot = _open_spot(room)
	var plumber := _spawn_enemy({"kind": "zombie", "armored": false, "scaling": scaling}, Vector3(spot.x, 0.1, spot.z))
	plumber.make_champion(["Brutal", "Hulking"])
	plumber.display_name = "Angry Plumber"
	plumber._update_label()
	_hud.announce_small("The plumber is NOT happy.", Color(0.9, 0.2, 0.15))


func _offer_blessing(shrine: Dictionary) -> void:
	var blessing: Dictionary = shrine.blessing
	_pending_item = blessing
	_offer_thing = shrine
	var cost := roundi(_player.max_knuckles * SHRINE_COST)
	_hud.show_item_offer(blessing, {}, 0, "Accept  (-%d knuckle HP)" % cost, "Leave it")


# --- Doors --------------------------------------------------------------------

func _seal_doors(room: Dictionary) -> void:
	Sfx.play("quake", -6.0)
	var iron := _material("iron", IRON, 0.7)
	var glow := _material("seal", SEAL_GLOW)
	glow.emission_enabled = true
	glow.emission = SEAL_GLOW
	glow.emission_energy_multiplier = 2.0
	for direction in room.doors:
		var gate := StaticBody3D.new()
		var edge := _edge_point(room, direction)
		gate.position = edge
		_level.add_child(gate)
		var across := Vector3(absf(direction.y), 0, absf(direction.x))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = across * DOOR_WIDTH + Vector3(absf(direction.x), 0, absf(direction.y)) * 0.5 + Vector3(0, WALL_HEIGHT, 0)
		shape.shape = box
		shape.position.y = WALL_HEIGHT / 2.0
		gate.add_child(shape)
		# Iron bars, glowing where they meet the floor.
		for i in 7:
			var offset := across * (-DOOR_WIDTH / 2.0 + 0.3 + i * (DOOR_WIDTH - 0.6) / 6.0)
			gate.add_child(_mesh(Enemy._box(Vector3(0.1, WALL_HEIGHT, 0.1)), iron, offset + Vector3(0, WALL_HEIGHT / 2.0, 0)))
		gate.add_child(_mesh(Enemy._box(across * DOOR_WIDTH + Vector3(0.15, 0.12, 0.15)), glow, Vector3(0, 0.06, 0)))
		# Slams down from the ceiling.
		gate.position.y = WALL_HEIGHT
		gate.create_tween().tween_property(gate, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		room.blockers.append(gate)


func _open_doors(room: Dictionary) -> void:
	for gate in room.blockers:
		var tween: Tween = gate.create_tween()
		tween.tween_property(gate, "position:y", WALL_HEIGHT, 0.6).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(gate.queue_free)
	room.blockers.clear()


func _edge_point(room: Dictionary, direction: Vector2i) -> Vector3:
	var extent: float = room.size.x / 2.0 if direction.x != 0 else room.size.y / 2.0
	return room.center + Vector3(direction.x, 0, direction.y) * extent


# --- Building ---------------------------------------------------------------

func _build_room(room: Dictionary) -> void:
	var size: Vector2 = room.size
	var half := size / 2.0
	var center: Vector3 = room.center
	var body := StaticBody3D.new()
	body.position = center
	_level.add_child(body)
	var floor_material := _floor_material()
	var wall_material := _wall_material()
	_block(body, Vector3(size.x, 0.5, size.y), Vector3(0, -0.25, 0), floor_material)
	_block(body, Vector3(size.x, 0.5, size.y), Vector3(0, WALL_HEIGHT + 0.25, 0), _material("ceiling", CEILING_STONE))
	for direction in DIRECTIONS:
		var outward := Vector3(direction.x, 0, direction.y)
		var along := Vector3(absf(direction.y), 0, absf(direction.x))
		var out_extent: float = half.x if direction.x != 0 else half.y
		var wall_length: float = size.y if direction.x != 0 else size.x
		var wall_center := outward * (out_extent + WALL_THICKNESS / 2.0) + Vector3(0, WALL_HEIGHT / 2.0, 0)
		var thickness := Vector3(absf(direction.x), 0, absf(direction.y)) * WALL_THICKNESS
		if direction in room.doors:
			var piece := (wall_length - DOOR_WIDTH) / 2.0
			for side in [-1.0, 1.0]:
				var offset: Vector3 = along * side * (DOOR_WIDTH / 2.0 + piece / 2.0)
				_block(body, along * piece + thickness + Vector3(0, WALL_HEIGHT, 0), wall_center + offset, wall_material)
		else:
			_block(body, along * (wall_length + WALL_THICKNESS * 2.0) + thickness + Vector3(0, WALL_HEIGHT, 0), wall_center, wall_material)
	# Solid blocks and pillars from the room's layout.
	for rect in room.solids:
		var block_center := Vector3(rect.get_center().x, WALL_HEIGHT / 2.0, rect.get_center().y)
		_block(body, Vector3(rect.size.x, WALL_HEIGHT, rect.size.y), block_center, wall_material)
	# Torches in the corners (more in the boss room); a corner filled by a
	# block gets its torch on the block's inner corner instead.
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	for corner in corners:
		var spot: Vector2 = corner * (half - Vector2(1.2, 1.2))
		for rect in room.solids:
			if rect.grow(0.6).has_point(spot):
				var inner: Vector2 = rect.get_center() - corner * rect.size / 2.0
				spot = inner - corner * 0.8
		_torch(center + Vector3(spot.x, 0, spot.y))
	if room.type == "boss":
		for direction in DIRECTIONS:
			if not (direction in room.doors):
				var extent: float = half.x if direction.x != 0 else half.y
				_torch(center + Vector3(direction.x, 0, direction.y) * (extent - 1.2))
	if room.elite:
		# A sickly glow marks the elite's room.
		var mark := OmniLight3D.new()
		mark.light_color = Color(0.9, 0.5, 0.15)
		mark.light_energy = 1.2
		mark.omni_range = 7.0
		mark.position = _open_spot(room) + Vector3(0, 3.5, 0)
		_level.add_child(mark)
	if room.type == "start":
		_build_altar(center + Vector3(-3.0, 0, -3.0))
	if room.type == "chest":
		_place_chest(center, "", MIMIC_CHANCE_CHEST_ROOM)
	elif room.type == "merchant":
		_build_merchant(room)
	elif room.type == "shrine":
		_build_shrine(room)
	if room.type == "toilet":
		_build_toilet(room)
	else:
		_decorate(room)
		_theme_decor(room)
	if _theme.hazard != "" and room.type in ["fight", "boss"]:
		_place_hazards(room)
	if room.state == "waiting":
		var trigger := Area3D.new()
		trigger.collision_mask = 2  # Player.
		trigger.position = center + Vector3(0, 1.0, 0)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		# Smaller than the room so the player is fully inside when doors seal.
		box.size = Vector3(size.x - 4.0, 2.0, size.y - 4.0)
		shape.shape = box
		trigger.add_child(shape)
		trigger.body_entered.connect(_on_room_entered.bind(room))
		_level.add_child(trigger)


func _build_corridor(a: Dictionary, b: Dictionary) -> void:
	var start := _edge_point(a, b.cell - a.cell)
	var finish := _edge_point(b, a.cell - b.cell)
	var middle := (start + finish) / 2.0
	var length := start.distance_to(finish)
	var direction := (finish - start).normalized()
	var across := Vector3(absf(direction.z), 0, absf(direction.x))
	var along := Vector3(absf(direction.x), 0, absf(direction.z))
	var body := StaticBody3D.new()
	body.position = middle
	_level.add_child(body)
	var width := DOOR_WIDTH
	_block(body, along * length + across * width + Vector3(0, 0.5, 0), Vector3(0, -0.25, 0), _floor_material())
	_block(body, along * length + across * width + Vector3(0, 0.5, 0), Vector3(0, WALL_HEIGHT + 0.25, 0), _material("ceiling", CEILING_STONE))
	for side in [-1.0, 1.0]:
		_block(body, along * length + across * WALL_THICKNESS + Vector3(0, WALL_HEIGHT, 0),
				across * side * (width / 2.0 + WALL_THICKNESS / 2.0) + Vector3(0, WALL_HEIGHT / 2.0, 0), _wall_material())
	# Beams overhead every couple of meters.
	for i in range(1, int(length / 2.5)):
		var at := along * (-length / 2.0 + i * 2.5) + Vector3(0, WALL_HEIGHT - 0.25, 0)
		body.add_child(_mesh(Enemy._box(across * width + along * 0.3 + Vector3(0, 0.3, 0)), _material("beam", Color(0.16, 0.1, 0.06)), at))
	_torch(middle + across * (width / 2.0 - 0.4), true)


## Bones, skulls, coffins, candles, chains, banners, cobwebs, rubble, wall
## pillars and ceiling beams, and dust in the air, so rooms feel lived in
## (or died in). No collision.
func _decorate(room: Dictionary) -> void:
	var half: Vector2 = room.size / 2.0
	var center: Vector3 = room.center
	var bone := _material("bone", Color(0.75, 0.72, 0.62))
	var wood := _material("coffin", Color(0.22, 0.14, 0.09))
	var beam := _material("beam", Color(0.16, 0.1, 0.06))
	var iron := _material("iron", Color(0.08, 0.08, 0.09), 0.6)
	if not _materials.has("ledge"):
		_materials["ledge"] = Look.patterned_material(Color(_theme.wall).lightened(0.05), Look.bricks())
	var ledge: StandardMaterial3D = _materials["ledge"]
	var wax := _material("wax", Color(0.86, 0.82, 0.7))
	var cloth := _material("banner", _theme.banner)
	var flame := Enemy._glow_material(Color(_theme.fire).lightened(0.3))
	# Ledge along the foot of every wall, and half-pillars set into the walls.
	for direction in DIRECTIONS:
		var outward := Vector3(direction.x, 0, direction.y)
		var along := Vector3(absf(direction.y), 0, absf(direction.x))
		var out_extent: float = half.x if direction.x != 0 else half.y
		var length: float = room.size.y if direction.x != 0 else room.size.x
		var face := outward * (out_extent - 0.08)
		var has_door: bool = direction in room.doors
		for side in [-1.0, 1.0]:
			var piece := (length - DOOR_WIDTH) / 2.0 if has_door else length / 2.0
			var offset: Vector3 = along * side * ((DOOR_WIDTH / 2.0 + piece / 2.0) if has_door else length / 4.0)
			_add_mesh(Enemy._box(along * piece + Vector3(0.16, 0.22, 0.16) - along * 0.16), ledge, center + face + offset + Vector3(0, 0.11, 0))
		var steps := int(length / 4.0)
		for i in range(1, steps):
			var t := -length / 2.0 + i * length / steps
			if has_door and absf(t) < DOOR_WIDTH / 2.0 + 0.5:
				continue
			var at := center + face + along * t
			_add_mesh(Enemy._box(along * 0.5 + outward.abs() * 0.3 + Vector3(0, WALL_HEIGHT, 0)), ledge, at + Vector3(0, WALL_HEIGHT / 2.0, 0))
			_add_mesh(Enemy._box(along * 0.7 + outward.abs() * 0.4 + Vector3(0, 0.3, 0)), ledge, at + Vector3(0, 0.15, 0))
			# A banner between some of the pillars.
			if randf() < 0.25 and i < steps - 1:
				var banner_at := center + face - outward * 0.05 + along * (t + length / steps / 2.0) + Vector3(0, WALL_HEIGHT - 1.5, 0)
				_add_mesh(Enemy._box(along * 0.9 + outward.abs() * 0.04 + Vector3(0, 2.0, 0)), cloth, banner_at)
				_add_mesh(Enemy._box(along * 1.1 + outward.abs() * 0.08 + Vector3(0, 0.08, 0)), beam, banner_at + Vector3(0, 1.04, 0))
	# Beams across the ceiling.
	var across_x: bool = room.size.x <= room.size.y
	var span: float = room.size.x if across_x else room.size.y
	var run: float = room.size.y if across_x else room.size.x
	for i in range(1, int(run / 3.0)):
		var t := -run / 2.0 + i * 3.0
		var at := center + (Vector3(0, WALL_HEIGHT - 0.25, t) if across_x else Vector3(t, WALL_HEIGHT - 0.25, 0))
		_add_mesh(Enemy._box(Vector3(span, 0.3, 0.3) if across_x else Vector3(0.3, 0.3, span)), beam, at)
	# Cobwebs in the top corners.
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		if randf() < 0.7:
			_cobweb(center + Vector3(corner.x * (half.x - 0.05), WALL_HEIGHT - 0.05, corner.y * (half.y - 0.05)), corner)
	# Bone piles with skulls.
	for i in randi_range(2, 4):
		var spot := _decor_spot(room)
		if spot == Vector3.INF:
			continue
		for b in randi_range(4, 8):
			var bit := _mesh(Enemy._box(Vector3(randf_range(0.25, 0.5), 0.05, 0.06)), bone, spot + Vector3(randf_range(-0.35, 0.35), 0.03 + b * 0.012, randf_range(-0.35, 0.35)))
			bit.rotation = Vector3(0, randf() * TAU, randf_range(-0.2, 0.2))
			_level.add_child(bit)
		for k in randi_range(1, 2):
			_skull(spot + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3)), bone)
	# Candle clusters.
	for i in randi_range(1, 3):
		var spot := _decor_spot(room)
		if spot == Vector3.INF:
			continue
		for c in randi_range(3, 6):
			var h := randf_range(0.12, 0.35)
			var at := spot + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
			_add_mesh(Enemy._box(Vector3(0.06, h, 0.06)), wax, at + Vector3(0, h / 2.0, 0))
			_add_mesh(Enemy._box(Vector3(0.025, 0.05, 0.025)), flame, at + Vector3(0, h + 0.03, 0))
		var glow := OmniLight3D.new()
		glow.light_color = Color(_theme.fire).lightened(0.35)
		glow.light_energy = 0.9
		glow.omni_range = 3.0
		glow.position = spot + Vector3(0, 0.5, 0)
		_level.add_child(glow)
	# Chains hanging from the beams.
	for i in randi_range(1, 3):
		var spot := _decor_spot(room)
		if spot == Vector3.INF:
			continue
		var links := randi_range(8, 16)
		for l in links:
			var link := _mesh(Enemy._box(Vector3(0.05, 0.12, 0.02)), iron, Vector3(spot.x, WALL_HEIGHT - 0.4 - l * 0.11, spot.z))
			link.rotation.y = PI / 2.0 if l % 2 == 0 else 0.0
			_level.add_child(link)
	# Rubble and a coffin against a wall.
	for i in randi_range(3, 6):
		var spot := _decor_spot(room)
		if spot == Vector3.INF:
			continue
		var s := randf_range(0.12, 0.3)
		var rock := _mesh(Enemy._box(Vector3(s, s * 0.6, s)), ledge, spot + Vector3(0, s * 0.3, 0))
		rock.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, 0)
		_level.add_child(rock)
	if room.type in ["fight", "start"] and randf() < 0.6:
		var wall_spot: Vector3 = center + Vector3(-half.x + 0.8, 0, randf_range(-half.y + 3.0, half.y - 3.0))
		if not _in_solid(room, wall_spot, 1.2):
			_add_mesh(Enemy._box(Vector3(0.7, 0.4, 2.0)), wood, wall_spot + Vector3(0, 0.2, 0))
			_add_mesh(Enemy._box(Vector3(0.78, 0.08, 2.08)), beam, wall_spot + Vector3(0, 0.44, 0))
			_add_mesh(Enemy._box(Vector3(0.08, 0.02, 0.5)), iron, wall_spot + Vector3(0, 0.49, -0.3))
			_add_mesh(Enemy._box(Vector3(0.3, 0.02, 0.08)), iron, wall_spot + Vector3(0, 0.49, -0.4))
	# Dust drifting in the torchlight.
	var dust := CPUParticles3D.new()
	dust.amount = 40
	dust.lifetime = 8.0
	dust.preprocess = 8.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(half.x - 1.0, WALL_HEIGHT / 2.0 - 0.3, half.y - 1.0)
	dust.position = center + Vector3(0, WALL_HEIGHT / 2.0, 0)
	dust.gravity = Vector3(0, -0.02, 0)
	dust.direction = Vector3(1, 0.2, 0)
	dust.spread = 180.0
	dust.initial_velocity_min = 0.02
	dust.initial_velocity_max = 0.08
	var mote := BoxMesh.new()
	mote.size = Vector3.ONE * 0.018
	var mote_material := StandardMaterial3D.new()
	mote_material.albedo_color = Color(1.0, 0.9, 0.75, 0.5)
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_material.emission_enabled = true
	mote_material.emission = Color(1.0, 0.85, 0.6)
	mote_material.emission_energy_multiplier = 0.6
	mote.material = mote_material
	dust.mesh = mote
	_level.add_child(dust)


## A random open spot on the room's floor, away from the middle and the
## blocks; INF when none was found.
# --- Tier looks (Themes.CRYPT) --------------------------------------------------------

## The deeper tiers' own dressing on top of the stone crypt's.
func _theme_decor(room: Dictionary) -> void:
	match _theme.id:
		"catacombs":
			_catacomb_niches(room)
		"flooded":
			_flood(room)
		"rot":
			_rot(room)
		"tomb":
			_royal_tomb(room)


## Catacombs: rows of skulls in niches along every wall.
func _catacomb_niches(room: Dictionary) -> void:
	var half: Vector2 = room.size / 2.0
	var bone := _material("bone", Color(0.8, 0.76, 0.66))
	var dark := _material("socket", Color(0.05, 0.04, 0.04))
	for direction in DIRECTIONS:
		var outward := Vector3(direction.x, 0, direction.y)
		var along := Vector3(absf(direction.y), 0, absf(direction.x))
		var out_extent: float = half.x if direction.x != 0 else half.y
		var length: float = room.size.y if direction.x != 0 else room.size.x
		var face: Vector3 = room.center + outward * (out_extent - 0.12)
		var rot := atan2(outward.x, outward.z)
		var count := int(length / 1.1)
		for i in count:
			var t := -length / 2.0 + (i + 0.5) * length / count
			if direction in room.doors and absf(t) < DOOR_WIDTH / 2.0 + 0.6:
				continue
			for row in 2:
				var at := face + along * t + Vector3(0, 1.1 + row * 1.0, 0)
				if _in_solid(room, at, 0.3):
					continue
				_add_mesh(Enemy._box(Vector3(0.7, 0.55, 0.7) if direction.x != 0 else Vector3(0.7, 0.55, 0.7)), dark, at - outward * 0.05)
				if randf() < 0.85:
					var skull := Node3D.new()
					_level.add_child(skull)
					ArenaScenery._skull(skull, at - outward * 0.32, 0.36, bone, dark, rot + randf_range(-0.3, 0.3))


## Flooded vaults: still black water over the floor, coffins half sunk in it,
## drips from the ceiling.
func _flood(room: Dictionary) -> void:
	var size: Vector2 = room.size
	if not _materials.has("water"):
		var water := StandardMaterial3D.new()
		water.albedo_color = Color(0.05, 0.18, 0.18, 0.72)
		water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water.metallic = 0.5
		water.roughness = 0.05
		_materials["water"] = water
	var sheet := _mesh(Enemy._box(Vector3(size.x, 0.02, size.y)), _materials["water"], room.center + Vector3(0, 0.12, 0))
	add_child.call_deferred(sheet)  # Off _level: batching would merge it.
	_level.tree_exiting.connect(sheet.queue_free)
	var wood := _material("coffin", Color(0.22, 0.14, 0.09))
	for i in randi_range(1, 3):
		var spot := _decor_spot(room)
		if spot == Vector3.INF:
			continue
		var coffin := _mesh(Enemy._box(Vector3(0.7, 0.4, 2.0)), wood, spot + Vector3(0, 0.08, 0))
		coffin.rotation = Vector3(randf_range(-0.25, 0.25), randf() * TAU, randf_range(-0.15, 0.15))
		_level.add_child(coffin)
	var drips := CPUParticles3D.new()
	drips.amount = 10 if Settings.use_web_profile() else 24
	drips.lifetime = 1.0
	drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drips.emission_box_extents = Vector3(size.x / 2.0 - 1.0, 0.05, size.y / 2.0 - 1.0)
	drips.position = room.center + Vector3(0, WALL_HEIGHT - 0.1, 0)
	drips.gravity = Vector3(0, -9.0, 0)
	var drop := BoxMesh.new()
	drop.size = Vector3(0.02, 0.08, 0.02)
	drop.material = Enemy._glow_material(Color(0.5, 1.0, 0.9))
	drips.mesh = drop
	_level.add_child(drips)


## Rot gardens: glowing mushrooms in clusters, fungus on the walls, spores.
func _rot(room: Dictionary) -> void:
	var stem := _material("stem", Color(0.82, 0.8, 0.68))
	var caps := [Enemy._glow_material(Color(0.45, 1.0, 0.25)), Enemy._glow_material(Color(0.75, 0.35, 1.0))]
	for c in caps:
		c.emission_energy_multiplier = 1.6
	for i in randi_range(3, 6):
		var spot := _decor_spot(room)
		if spot == Vector3.INF:
			continue
		var cap: Material = caps[i % 2]
		for m in randi_range(3, 6):
			var h := randf_range(0.2, 0.7)
			var at := spot + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
			_add_mesh(Enemy._box(Vector3(0.08, h, 0.08)), stem, at + Vector3(0, h / 2.0, 0))
			var w := randf_range(0.2, 0.45)
			_add_mesh(Enemy._box(Vector3(w, 0.1, w)), cap, at + Vector3(0, h + 0.04, 0))
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.55, 1.0, 0.4) if i % 2 == 0 else Color(0.8, 0.45, 1.0)
		glow.light_energy = 0.8
		glow.omni_range = 3.5
		glow.position = spot + Vector3(0, 0.6, 0)
		_level.add_child(glow)
	var spores := CPUParticles3D.new()
	spores.amount = 14 if Settings.use_web_profile() else 30
	spores.lifetime = 6.0
	spores.preprocess = 6.0
	spores.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	spores.emission_box_extents = Vector3(room.size.x / 2.0 - 1.0, 1.2, room.size.y / 2.0 - 1.0)
	spores.position = room.center + Vector3(0, 1.4, 0)
	spores.gravity = Vector3(0, 0.05, 0)
	spores.spread = 180.0
	spores.initial_velocity_max = 0.15
	var spore := BoxMesh.new()
	spore.size = Vector3.ONE * 0.04
	spore.material = Enemy._glow_material(Color(0.6, 1.0, 0.3))
	spores.mesh = spore
	_level.add_child(spores)


## The royal tomb: a red carpet down the room, gold-trimmed sarcophagi,
## heaps of treasure and a candle chandelier.
func _royal_tomb(room: Dictionary) -> void:
	var size: Vector2 = room.size
	var carpet := _material("carpet", Color(0.55, 0.05, 0.07))
	var gold := _material("gold", Color(0.95, 0.72, 0.25), 0.8)
	var marble := _material("marble", Color(0.08, 0.07, 0.08))
	var long_x := size.x >= size.y
	_add_mesh(Enemy._box(Vector3(size.x - 2.0, 0.02, 1.6) if long_x else Vector3(1.6, 0.02, size.y - 2.0)), carpet, room.center + Vector3(0, 0.01, 0))
	_add_mesh(Enemy._box(Vector3(size.x - 2.0, 0.025, 0.08) if long_x else Vector3(0.08, 0.025, size.y - 2.0)), gold, room.center + (Vector3(0, 0.01, 0.8) if long_x else Vector3(0.8, 0.01, 0)))
	_add_mesh(Enemy._box(Vector3(size.x - 2.0, 0.025, 0.08) if long_x else Vector3(0.08, 0.025, size.y - 2.0)), gold, room.center + (Vector3(0, 0.01, -0.8) if long_x else Vector3(-0.8, 0.01, 0)))
	for i in randi_range(1, 2):
		var spot := _decor_spot(room)
		if spot == Vector3.INF:
			continue
		var tomb := Node3D.new()
		tomb.position = spot
		tomb.rotation.y = 0.0 if long_x else PI / 2.0
		_level.add_child(tomb)
		tomb.add_child(_mesh(Enemy._box(Vector3(2.2, 0.8, 1.0)), marble, Vector3(0, 0.4, 0)))
		tomb.add_child(_mesh(Enemy._box(Vector3(2.3, 0.12, 1.1)), gold, Vector3(0, 0.86, 0)))
		tomb.add_child(_mesh(Enemy._box(Vector3(1.6, 0.18, 0.6)), gold, Vector3(0, 1.0, 0)))
		tomb.add_child(_mesh(Enemy._box(Vector3(0.3, 0.2, 0.3)), gold, Vector3(0.9, 1.1, 0)))
	for i in randi_range(2, 4):
		var spot := _decor_spot(room)
		if spot == Vector3.INF:
			continue
		for c in randi_range(6, 12):
			var at := spot + Vector3(randf_range(-0.45, 0.45), 0, randf_range(-0.45, 0.45))
			var coin := _mesh(Enemy._box(Vector3(0.12, 0.03, 0.12)), gold, at + Vector3(0, 0.02 + randf() * 0.25, 0))
			coin.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
			_level.add_child(coin)
	# The chandelier: a gold ring of candles hung from the ceiling.
	var hang: Vector3 = room.center + Vector3(0, WALL_HEIGHT - 1.4, 0)
	_add_mesh(Enemy._box(Vector3(0.05, 1.2, 0.05)), gold, hang + Vector3(0, 0.7, 0))
	var flame := Enemy._glow_material(Color(1.0, 0.75, 0.35))
	for k in 8:
		var a := k * TAU / 8.0
		var at := hang + Vector3(cos(a), 0, sin(a)) * 0.8
		_add_mesh(Enemy._box(Vector3(0.3, 0.06, 0.06)), gold, at)
		_add_mesh(Enemy._box(Vector3(0.05, 0.15, 0.05)), _material("wax", Color(0.86, 0.82, 0.7)), at + Vector3(0, 0.1, 0))
		_add_mesh(Enemy._box(Vector3(0.03, 0.05, 0.03)), flame, at + Vector3(0, 0.2, 0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 1.6
	light.omni_range = 9.0
	light.position = hang
	_level.add_child(light)


## Toxic puddles (Rot Gardens) or fire vents (Royal Tomb) in fight rooms.
func _place_hazards(room: Dictionary) -> void:
	var hit: float = 6.0 * Progression.enemy_scaling(_position(), Progression.crypt_difficulty(_floor, _start_floor)).damage
	var toxic: bool = _theme.hazard == "toxic"
	for i in (3 if room.type == "boss" else 2):
		var spot := _decor_spot(room)
		if spot == Vector3.INF:
			continue
		_hazards.add_child(Hazard.make(_theme.hazard, spot, randf_range(1.2, 1.7) if toxic else 1.3, hit * (0.16 if toxic else 1.3), _player))


func _decor_spot(room: Dictionary) -> Vector3:
	var half: Vector2 = room.size / 2.0
	for attempt in 6:
		var spot: Vector3 = room.center + Vector3(randf_range(-half.x + 1.2, half.x - 1.2), 0, randf_range(-half.y + 1.2, half.y - 1.2))
		if spot.distance_to(room.center) > 3.0 and not _in_solid(room, spot, 0.6):
			return spot
	return Vector3.INF


func _skull(at: Vector3, bone: Material) -> void:
	var skull := Node3D.new()
	skull.position = at
	skull.rotation.y = randf() * TAU
	_level.add_child(skull)
	var hollow := _material("socket", Color(0.05, 0.04, 0.04))
	skull.add_child(_mesh(Enemy._box(Vector3(0.2, 0.18, 0.22)), bone, Vector3(0, 0.1, 0)))
	skull.add_child(_mesh(Enemy._box(Vector3(0.14, 0.06, 0.08)), bone, Vector3(0, 0.03, 0.09)))
	for x in [-0.05, 0.05]:
		skull.add_child(_mesh(Enemy._box(Vector3(0.05, 0.05, 0.02)), hollow, Vector3(x, 0.12, 0.11)))


func _cobweb(at: Vector3, corner: Vector2) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 1.2)
	var material := StandardMaterial3D.new()
	material.albedo_texture = Look.web()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.8, 0.8, 0.85, 0.6)
	quad.material = material
	var web := MeshInstance3D.new()
	web.mesh = quad
	_level.add_child(web)
	# Diagonal across the corner, tilted down from the ceiling.
	web.global_position = at + Vector3(-corner.x * 0.4, -0.4, -corner.y * 0.4)
	web.rotation = Vector3(0, atan2(corner.x, corner.y) + PI / 2.0, 0)
	web.rotate_object_local(Vector3.RIGHT, -0.6)
	web.scale = Vector3(-corner.x if absf(corner.x) > 0 else 1.0, 1, 1)


func _add_mesh(mesh: PrimitiveMesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var instance := _mesh(mesh, material, pos)
	_level.add_child(instance)
	return instance


func _torch(at: Vector3, on_wall := false) -> void:
	if not on_wall:
		_level.add_child(_mesh(Enemy._cylinder(0.05, 1.7), _material("wood", Color(0.35, 0.22, 0.12)), at + Vector3(0, 0.85, 0)))
	Look.flame(_level, at + Vector3(0, 1.78 if not on_wall else 2.6, 0), 1.0, true, _theme.fire)
	var light := Look.fire_light(Color(1.0, 0.6, 0.28) if _theme.fire == Look.FIRE else Color(_theme.fire).lightened(0.25), 2.4, 13.0)
	light.position = at + Vector3(0, 2.0 if not on_wall else 2.8, 0)
	_level.add_child(light)
	_torches.append(light)


func _flicker_torches(delta: float) -> void:
	_torch_time += delta
	for i in _torches.size():
		if is_instance_valid(_torches[i]):
			_torches[i].light_energy = 2.2 + sin(_torch_time * 11.0 + i * 1.7) * 0.25 + sin(_torch_time * 23.0 + i) * 0.15


## Brick walls and flagstone floors (shared, made once).
func _wall_material() -> StandardMaterial3D:
	if not _materials.has("bricks"):
		_materials["bricks"] = Look.patterned_material(Color(_theme.wall).lightened(0.15), Look.bricks())
	return _materials["bricks"]


func _floor_material() -> StandardMaterial3D:
	if not _materials.has("tiles"):
		_materials["tiles"] = Look.patterned_material(Color(_theme.floor).lightened(0.2), Look.tiles())
	return _materials["tiles"]


## A box with collision on a static body.
func _block(body: StaticBody3D, size: Vector3, pos: Vector3, material: Material) -> void:
	body.add_child(_mesh(Enemy._box(size), material, pos))
	_add_solid(body, size, pos)


func _add_solid(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body: Node3D = parent
	if not (parent is StaticBody3D):
		body = StaticBody3D.new()
		parent.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	body.add_child(shape)


func _mesh(mesh: PrimitiveMesh, material: Material, pos: Vector3) -> MeshInstance3D:
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	return instance


func _material(key: String, color: Color, metallic := 0.0) -> StandardMaterial3D:
	if not _materials.has(key):
		_materials[key] = Enemy._material(color, metallic)
	return _materials[key]


# --- Run end ----------------------------------------------------------------

func _on_leveled_up(new_level: int) -> void:
	_hud.announce_small("LEVEL UP!  +1 CARD", Color(0.5, 0.9, 1))


## Knuckles broke: fall to the floor, then the results.
func _on_knocked_out() -> void:
	if _run_over:
		return
	_hud.set_prompt("")
	_hud.knockout_fade()
	_player.knock_out()
	await get_tree().create_timer(Player.KNOCKOUT_TIME).timeout
	if is_inside_tree():
		_end_run("KNOCKED OUT", false)


func _end_run(title: String, slow := true) -> void:
	if _run_over:
		return
	_run_over = true
	_player.active = false
	_hud.set_prompt("")
	TimeFx.clear()
	if slow:
		TimeFx.slowmo(0.3, 0.8)
	var lost := _bound_finds().filter(func(item: Dictionary) -> bool: return not item.get("gilded", false)).size()
	var kept := GameState.end_crypt_run(false)
	_hud.set_equipment(GameState.equipped)
	var notes: Array[String] = []
	if not kept.is_empty():
		notes.append("KEPT %d GILDED" % kept.size())
		var names: Array = kept.map(func(item: Dictionary) -> String: return item.name)
		GameState.upgrade_notice = "Knocked out, but your gilded finds came home:\n" + "\n".join(names) + "\n\nThey're in your Armory."
	if lost > 0:
		notes.append("%d FIND%s CRUMBLED TO DUST" % [lost, "" if lost == 1 else "S"])
	_hud.show_results({
		"title": "KNOCKED OUT" if title == "KNOCKED OUT" else "RUN ABANDONED",
		"title_color": UiTheme.BAD,
		"subtitle": "FLOOR %d" % _floor,
		"rewards": {"coins": _run_coins, "xp": _run_xp, "souls": _run_souls},
		"note": "   ·   ".join(notes),
		"note_color": UiTheme.BAD if kept.is_empty() else UiTheme.GOLD,
	}, "", false, "Back to camp")


## The camp button: after a knockout it's just the way home; on the stairs'
## screen it means leaving the Crypt with your gilded finds.
func _leave_crypt() -> void:
	if not _run_over:
		_run_over = true
		var kept := GameState.end_crypt_run(true)
		if not kept.is_empty():
			var names: Array = kept.map(func(item: Dictionary) -> String: return item.name)
			GameState.upgrade_notice = "You left the Crypt with:\n" + "\n".join(names) + "\n\nThey're in your Armory."
	_go_to_camp()


func _go_to_camp() -> void:
	get_tree().paused = false
	Loading.go("res://camp.tscn")
