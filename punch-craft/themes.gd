class_name Themes
## Every tier of the climb has its own look, sound and (from tier 4) hazard:
## the Arena division and the Crypt floors of that tier. Tier 1 is the
## original graveyard and stone crypt. Past tier 5 (the endless Crypt) the
## looks cycle.
##   ground / wall / floor: base colors; fog, ambient: the environment;
##   moon: the key light; fire: torch and brazier flames (and their light);
##   wisps: the floating motes; music: Sfx track; hazard: "", "toxic", "fire".

const ARENA := [
	{"id": "graveyard", "name": "The Graveyard", "music": "arena", "hazard": "",
		"ground": Color(0.14, 0.17, 0.12), "fog": Color(0.12, 0.13, 0.2), "fog_density": 0.032,
		"ambient": Color(0.34, 0.38, 0.55), "moon": Color(0.6, 0.7, 1.0), "fire": Look.FIRE,
		"wisps": Color(0.45, 1.0, 0.75), "mist": Color(0.55, 0.6, 0.75)},
	{"id": "ossuary", "name": "The Ossuary Pit", "music": "arena_bone", "hazard": "",
		"ground": Color(0.24, 0.22, 0.19), "fog": Color(0.08, 0.12, 0.22), "fog_density": 0.016,
		"ambient": Color(0.32, 0.4, 0.62), "moon": Color(0.55, 0.72, 1.0), "fire": Color(0.25, 0.65, 1.0),
		"wisps": Color(0.5, 0.8, 1.0), "mist": Color(0.5, 0.62, 0.85)},
	{"id": "pier", "name": "The Drowned Pier", "music": "arena_ghost", "hazard": "",
		"ground": Color(0.2, 0.15, 0.11), "fog": Color(0.08, 0.17, 0.16), "fog_density": 0.022,
		"ambient": Color(0.3, 0.48, 0.46), "moon": Color(0.55, 1.0, 0.85), "fire": Color(0.3, 1.0, 0.75),
		"wisps": Color(0.55, 1.0, 0.85), "mist": Color(0.5, 0.75, 0.72)},
	{"id": "carnival", "name": "The Plague Carnival", "music": "arena_plague", "hazard": "toxic",
		"ground": Color(0.16, 0.16, 0.1), "fog": Color(0.12, 0.15, 0.05), "fog_density": 0.02,
		"ambient": Color(0.4, 0.46, 0.3), "moon": Color(0.75, 1.0, 0.5), "fire": Color(0.55, 1.0, 0.2),
		"wisps": Color(0.65, 1.0, 0.3), "mist": Color(0.6, 0.72, 0.4)},
	{"id": "colosseum", "name": "The Coffin King's Colosseum", "music": "arena_crown", "hazard": "fire",
		"ground": Color(0.42, 0.32, 0.2), "fog": Color(0.2, 0.08, 0.05), "fog_density": 0.012,
		"ambient": Color(0.55, 0.38, 0.32), "moon": Color(1.0, 0.62, 0.42), "fire": Look.FIRE,
		"wisps": Color(1.0, 0.55, 0.2), "mist": Color(0.75, 0.5, 0.4)},
]

const CRYPT := [
	{"id": "crypt", "name": "The Crypt", "music": "crypt", "hazard": "",
		"wall": Color(0.24, 0.23, 0.26), "floor": Color(0.15, 0.14, 0.15), "banner": Color(0.4, 0.06, 0.06),
		"fire": Look.FIRE, "ambient": Color(0.4, 0.35, 0.45), "fog": Color(0.1, 0.08, 0.09)},
	{"id": "catacombs", "name": "The Catacombs", "music": "crypt_bone", "hazard": "",
		"wall": Color(0.36, 0.33, 0.28), "floor": Color(0.2, 0.18, 0.15), "banner": Color(0.1, 0.18, 0.36),
		"fire": Color(0.25, 0.65, 1.0), "ambient": Color(0.32, 0.38, 0.52), "fog": Color(0.05, 0.08, 0.13)},
	{"id": "flooded", "name": "The Flooded Vaults", "music": "crypt_ghost", "hazard": "",
		"wall": Color(0.18, 0.25, 0.25), "floor": Color(0.1, 0.14, 0.15), "banner": Color(0.08, 0.3, 0.28),
		"fire": Color(0.3, 1.0, 0.75), "ambient": Color(0.3, 0.46, 0.46), "fog": Color(0.04, 0.1, 0.1)},
	{"id": "rot", "name": "The Rot Gardens", "music": "crypt_plague", "hazard": "toxic",
		"wall": Color(0.2, 0.23, 0.15), "floor": Color(0.13, 0.14, 0.09), "banner": Color(0.3, 0.12, 0.38),
		"fire": Color(0.55, 1.0, 0.2), "ambient": Color(0.38, 0.45, 0.3), "fog": Color(0.07, 0.1, 0.03)},
	{"id": "tomb", "name": "The Royal Tomb", "music": "crypt_crown", "hazard": "fire",
		"wall": Color(0.11, 0.09, 0.1), "floor": Color(0.14, 0.08, 0.08), "banner": Color(0.6, 0.06, 0.08),
		"fire": Look.FIRE, "ambient": Color(0.52, 0.4, 0.34), "fog": Color(0.14, 0.06, 0.04)},
]


static func arena(division: int) -> Dictionary:
	return ARENA[(maxi(division, 1) - 1) % ARENA.size()]


## The look for a Crypt floor: by its tier (two floors a tier), cycling past 5.
static func crypt(floor_number: int) -> Dictionary:
	var tier := ceili(maxi(floor_number, 1) / float(Progression.FLOORS_PER_TIER))
	return CRYPT[(tier - 1) % CRYPT.size()]


## Points a scene's environment and key light at a theme.
static func apply_environment(env: Environment, theme: Dictionary, moon: DirectionalLight3D = null) -> void:
	env.ambient_light_color = theme.ambient
	env.fog_light_color = theme.fog
	if theme.has("fog_density"):
		env.fog_density = theme.fog_density
	if moon and theme.has("moon"):
		moon.light_color = theme.moon
