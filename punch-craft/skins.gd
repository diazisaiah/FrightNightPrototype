class_name Skins
## Alternate looks for the fighters (art/alternate_skins/): each is the
## fighter's own outfit in another palette, plus an effect or two, on the
## third-person body (PlayerBody) and the first-person hands (Fists). Bought in
## the Soul Shop, worn from Cosmetics → Skins. Every color a skin can change
## is a part of the fighter's palette (BASE); a skin overrides the parts it
## changes (LOOKS).

const PRICE := 20

const CATALOG := {
	"obsidian_furnace": {"fighter": "berserker", "name": "Obsidian Furnace", "desc": "Forged under the ring. Still hot."},
	"white_noise": {"fighter": "counter_master", "name": "White Noise", "desc": "Nothing to read. Everything to answer."},
	"hyperlight": {"fighter": "combo_master", "name": "Hyperlight", "desc": "Too fast to see. Too bright to miss."},
	"rooftop_ghost": {"fighter": "free_runner", "name": "Rooftop Ghost", "desc": "Seen on the skyline. Never caught."},
	"sunday_best": {"fighter": "wise_guy", "name": "Sunday Best", "desc": "The good tracksuit."},
	"verdant_sigil": {"fighter": "elementalist", "name": "Verdant Sigil", "desc": "Old green magic, gold at the hem."},
	"plumber_overalls": {"fighter": "wise_guy", "name": "Plumber Overalls", "desc": "Flannel, denim, work boots. Fixes pipes. Breaks faces."},
}
## Skins only a feat gives (never sold): the overalls for all five plumber caps.
const EARN_ONLY := ["plumber_overalls"]

## Each fighter's own colors, part by part. "cracks" with no alpha: none.
## "glow": the hands' color when the ultimate is ready (Fists.ACCENT if unset).
const BASE := {
	"berserker": {
		"vest": Color(0.1, 0.1, 0.12), "trim": Color(0.88, 0.86, 0.8), "blood": Color(0.5, 0.05, 0.05),
		"sash": Color(0.72, 0.07, 0.06), "trunks": Color(0.1, 0.1, 0.12), "trunk_spots": Color(0.5, 0.05, 0.05),
		"glove": Color(0.72, 0.08, 0.07), "glove_blood": Color(0.42, 0.03, 0.03), "cracks": Color(0.95, 0.4, 0.08, 0.0),
		"laces": Color(0.9, 0.88, 0.84), "tape": Color(0.92, 0.9, 0.85), "tape_dark": Color(0.8, 0.78, 0.73),
		"band": Color(0.9, 0.88, 0.84), "shoes": Color(0.09, 0.09, 0.1), "sole": Color(0.72, 0.08, 0.07), "accent": Color(0.75, 0.08, 0.07),
	},
	"counter_master": {
		"cloth": Color(0.08, 0.08, 0.1), "piping": Color(0.86, 0.86, 0.9), "belt": Color(0.86, 0.86, 0.9),
		"wrap": Color(0.16, 0.38, 0.88), "wrap_dark": Color(0.088, 0.209, 0.484), "wrap_light": Color(0.9, 0.9, 0.92),
		"glove": Color(0.08, 0.08, 0.1), "glove_cuff": Color(0.9, 0.9, 0.92), "ankle": Color(0.86, 0.86, 0.9),
		"shoes": Color(0.06, 0.06, 0.07), "sole": Color(0.85, 0.85, 0.88), "accent": Color(0.88, 0.88, 0.9),
	},
	"combo_master": {
		"top": Color(0.1, 0.09, 0.13), "trim": Color(0.55, 0.32, 0.95), "sash": Color(0.52, 0.16, 0.5),
		"pants": Color(0.09, 0.08, 0.12), "patch": Color(0.78, 0.77, 0.82), "patch_mid": Color(0.38, 0.36, 0.44),
		"band_a": Color(0.55, 0.32, 0.95), "band_b": Color(0.9, 0.88, 0.92), "band_c": Color(0.9, 0.88, 0.92),
		"glove": Color(0.1, 0.09, 0.13), "glove_cuff": Color(0.55, 0.32, 0.95), "hand_wrap": Color(0.5, 0.3, 0.88),
		"shoes": Color(0.07, 0.07, 0.09), "sole": Color(0.88, 0.88, 0.9), "accent": Color(0.55, 0.32, 0.95),
	},
	"free_runner": {
		"gi": Color(0.14, 0.12, 0.13), "trim": Color(0.86, 0.82, 0.74), "band": Color(0.72, 0.08, 0.08),
		"hem": Color(0.3, 0.26, 0.26), "tape": Color(0.86, 0.84, 0.78), "glove": Color(0.16, 0.45, 0.22),
		"glove_cuff": Color(0.1, 0.32, 0.15), "shoes": Color(0.9, 0.88, 0.84), "sole": Color(0.86, 0.84, 0.8),
		"accent": Color(0.75, 0.08, 0.08),
	},
	"wise_guy": {
		"jacket": Color(0.08, 0.08, 0.09), "stripe": Color(0.92, 0.92, 0.9), "zip": Color(0.874, 0.874, 0.855),
		"tee": Color(0.92, 0.92, 0.9), "rib_a": Color(0.13, 0.13, 0.14), "rib_b": Color(0.08, 0.08, 0.09),
		"beanie_a": Color(0.13, 0.13, 0.14), "beanie_b": Color(0.09, 0.09, 0.1), "brim": Color(0.12, 0.12, 0.13),
		"tape": Color(0.9, 0.88, 0.84), "shoes": Color(0.09, 0.09, 0.1), "sole": Color(0.9, 0.9, 0.88), "accent": Color(0.9, 0.9, 0.88),
		"shirt": Color(0.86, 0.1, 0.1, 0.0),
	},
	"elementalist": {
		"robe": Color(0.11, 0.1, 0.12), "trim": Color(0.88, 0.86, 0.8), "sash": Color(0.16, 0.15, 0.18),
		"sash_stripe": Color(0.86, 0.84, 0.8), "tape_a": Color(0.92, 0.9, 0.86), "tape_b": Color(0.84, 0.82, 0.78),
		"hand_tape": Color(0.9, 0.88, 0.84), "ink_left": Color(1.0, 0.5, 0.12), "ink_right": Color(0.6, 0.3, 1.0),
		"straps": Color(0.86, 0.84, 0.8), "shoes": Color(0.09, 0.08, 0.09), "sole": Color(0.06, 0.05, 0.06), "accent": Color(0.86, 0.84, 0.8),
	},
}

## What each skin changes (after its reference art in art/alternate_skins/).
const LOOKS := {
	"obsidian_furnace": {
		"trim": Color(1.0, 0.55, 0.12), "sash": Color(1.0, 0.5, 0.1), "trunk_spots": Color(1.0, 0.45, 0.08),
		"glove": Color(0.14, 0.13, 0.14), "glove_blood": Color(0.08, 0.08, 0.09), "cracks": Color(1.0, 0.5, 0.1),
		"laces": Color(0.55, 0.55, 0.58), "tape": Color(0.62, 0.62, 0.65), "tape_dark": Color(0.46, 0.46, 0.5),
		"band": Color(0.62, 0.62, 0.65), "sole": Color(1.0, 0.5, 0.1), "accent": Color(1.0, 0.55, 0.12),
	},
	"white_noise": {
		"cloth": Color(0.9, 0.9, 0.92), "piping": Color(0.1, 0.1, 0.12), "belt": Color(0.1, 0.1, 0.12),
		"wrap": Color(0.1, 0.1, 0.12), "wrap_dark": Color(0.2, 0.82, 0.95), "wrap_light": Color(0.92, 0.92, 0.94),
		"glove": Color(0.92, 0.92, 0.94), "glove_cuff": Color(0.1, 0.1, 0.12), "ankle": Color(0.2, 0.82, 0.95),
		"shoes": Color(0.9, 0.9, 0.92), "sole": Color(0.92, 0.92, 0.94), "accent": Color(0.2, 0.82, 0.95),
		"glow": Color(0.4, 0.9, 1.0),
	},
	"hyperlight": {
		"trim": Color(0.2, 0.85, 1.0), "sash": Color(0.95, 0.18, 0.62), "patch": Color(0.25, 0.85, 1.0),
		"patch_mid": Color(0.1, 0.4, 0.55), "band_a": Color(0.95, 0.18, 0.62), "band_b": Color(0.25, 0.85, 1.0),
		"band_c": Color(0.92, 0.92, 0.94), "glove_cuff": Color(0.95, 0.18, 0.62), "hand_wrap": Color(0.95, 0.18, 0.62),
		"accent": Color(0.25, 0.85, 1.0), "glow": Color(0.3, 0.9, 1.0),
	},
	"rooftop_ghost": {
		"gi": Color(0.15, 0.18, 0.32), "band": Color(1.0, 0.45, 0.1), "hem": Color(0.32, 0.34, 0.45),
		"glove": Color(0.08, 0.55, 0.6), "glove_cuff": Color(0.05, 0.36, 0.42), "shoes": Color(0.16, 0.2, 0.34),
		"accent": Color(0.1, 0.65, 0.7), "glow": Color(1.0, 0.55, 0.15),
	},
	"sunday_best": {
		"jacket": Color(0.42, 0.06, 0.1), "stripe": Color(0.93, 0.87, 0.75), "zip": Color(1.0, 0.78, 0.25),
		"rib_a": Color(0.5, 0.08, 0.12), "rib_b": Color(0.36, 0.05, 0.08), "beanie_a": Color(0.13, 0.33, 0.2),
		"beanie_b": Color(0.08, 0.25, 0.15), "brim": Color(0.1, 0.29, 0.17), "tape": Color(0.93, 0.88, 0.78),
		"shoes": Color(0.45, 0.07, 0.1), "sole": Color(0.93, 0.88, 0.78), "accent": Color(0.93, 0.87, 0.75),
	},
	# A "shirt" (with alpha): PlayerBody and Fists dress Tony in overalls over it.
	"plumber_overalls": {
		"jacket": Color(0.2, 0.3, 0.55), "stripe": Color(0.2, 0.3, 0.55), "zip": Color(0.62, 0.5, 0.3),
		"shirt": Color(0.72, 0.12, 0.1), "tee": Color(0.72, 0.12, 0.1), "rib_a": Color(0.72, 0.12, 0.1), "rib_b": Color(0.5, 0.08, 0.07),
		"beanie_a": Color(0.72, 0.12, 0.1), "beanie_b": Color(0.5, 0.08, 0.07), "brim": Color(0.45, 0.07, 0.06),
		"tape": Color(0.9, 0.88, 0.84), "shoes": Color(0.2, 0.13, 0.08), "sole": Color(0.1, 0.08, 0.06), "accent": Color(0.72, 0.12, 0.1),
		"glow": Color(1.0, 0.3, 0.2),
	},
	"verdant_sigil": {
		"robe": Color(0.07, 0.2, 0.12), "trim": Color(0.86, 0.66, 0.32), "sash": Color(0.3, 0.2, 0.12),
		"sash_stripe": Color(0.86, 0.66, 0.32), "ink_left": Color(0.35, 1.0, 0.5), "ink_right": Color(0.35, 1.0, 0.5),
		"straps": Color(0.86, 0.66, 0.32), "accent": Color(0.86, 0.66, 0.32), "glow": Color(0.4, 1.0, 0.55),
	},
}


## The skins a fighter has (in catalog order).
static func of(fighter: String) -> Array:
	return CATALOG.keys().filter(func(id: String) -> bool: return CATALOG[id].fighter == fighter)


## A fighter's palette in a skin ("" for their own look).
static func palette(fighter: String, skin := "") -> Dictionary:
	var colors: Dictionary = BASE.get(fighter, {}).duplicate()
	if CATALOG.has(skin) and CATALOG[skin].fighter == fighter:
		colors.merge(LOOKS.get(skin, {}), true)
	return colors


static func name_of(id: String) -> String:
	return CATALOG[id].name if CATALOG.has(id) else "Default"
