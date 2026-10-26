class_name Cards
## Level-up card draws (2026-10-25; replace the skill webs). Every fighter has
## a deck of 40: five commons (4 copies, ranks I-IV), five rares (2 copies,
## ranks I-II), five epics (one for each of the fighter's passives and
## ultimates) and five legendaries (one joins as each Dead League seal
## breaks). Each level-up draws three different cards; the fighter keeps one,
## and drawing a card again ranks it up. See CARD_DECKS.md.
##
## A card's effects are per rank: {effect: [at rank I, at rank II, ...]}; they
## add into GameState.get_effect while you play that fighter. Commons show
## "values" in their text (%s); rares have a line per rank.

const COPIES := {"common": 4, "rare": 2, "epic": 1, "legendary": 1}
## Legendaries come up this many times as often as one copy of anything else.
const LEGENDARY_WEIGHT := 2.0
## The seals, in climb order: legendary "seal" i joins after contender i.
const SEALS := ["bellman", "headless", "southpaw", "plague_doctor", "coffin_king"]
const RARITY_ORDER := ["common", "rare", "epic", "legendary"]
## Kept here instead of reaching into Items so Cards stays safe to load while
## the GameState autoload (which also loads Items) is still compiling.
const RARITY_COLORS := {
	"common": Color(0.8, 0.8, 0.8),
	"rare": Color(0.35, 0.65, 1.0),
	"epic": Color(0.8, 0.45, 1.0),
	"legendary": Color(1.0, 0.62, 0.12),
}
const TAG_COLORS := {
	"Power": Color(1.0, 0.45, 0.25), "Defense": Color(0.55, 0.75, 1.0), "Counter": Color(0.35, 0.85, 1.0),
	"Dodge": Color(0.6, 0.9, 0.7), "Combo": Color(0.7, 0.5, 1.0), "Movement": Color(0.35, 0.95, 0.5),
	"Ultimate": Color(1.0, 0.8, 0.3), "Rage": Color(1.0, 0.3, 0.2), "Spell": Color(0.95, 0.45, 0.75),
}

## Every deck's Southpaw legendary.
const SURGE := {"name": "Ultimate Surge", "rarity": "legendary", "icon": "battery", "tags": ["Ultimate"], "seal": "southpaw",
	"text": ["Every bout starts with your ultimate a quarter full, and using it gives a quarter back"], "effects": {"ult_surge": [1]}}

const DECKS := {
	"berserker": {
		"payback": {"name": "Payback", "rarity": "common", "icon": "rage", "tags": ["Power"],
			"text": "Your first punch after taking a hit deals +%s%%", "values": [12, 24, 36, 48], "effects": {"payback": [0.12, 0.24, 0.36, 0.48]}},
		"heavy_hitter": {"name": "Heavy Hitter", "rarity": "common", "icon": "fist", "tags": ["Power"],
			"text": "+%s%% damage", "values": [4, 8, 12, 16], "effects": {"damage_percent": [0.04, 0.08, 0.12, 0.16]}},
		"thick_hide": {"name": "Thick Hide", "rarity": "common", "icon": "shield", "tags": ["Defense"],
			"text": "Hits deal %s%% less to you", "values": [2, 4, 6, 8], "effects": {"hit_guard": [0.02, 0.04, 0.06, 0.08]}},
		"short_fuse": {"name": "Short Fuse", "rarity": "common", "icon": "match", "tags": ["Ultimate"],
			"text": "Taking a hit fills your ultimate by %s", "values": [3, 6, 9, 12], "effects": {"hit_ult": [3.0, 6.0, 9.0, 12.0]}},
		"mob_magnet": {"name": "Mob Magnet", "rarity": "common", "icon": "magnet", "tags": ["Power"],
			"text": "+%s%% damage for every monster within 3m (up to 4)", "values": [2, 4, 6, 8], "effects": {"mob_bonus": [0.02, 0.04, 0.06, 0.08]}},
		"hold_the_line": {"name": "Hold the Line", "rarity": "rare", "icon": "anchor", "tags": ["Defense"],
			"text": ["Hits make you flinch half as long", "Hits can't make you flinch"], "effects": {"no_flinch": [0.5, 1.0]}},
		"lights_out": {"name": "Lights Out", "rarity": "rare", "icon": "skull", "tags": ["Power"],
			"text": ["Staggered monsters take +20% from you", "Staggered monsters take +40% from you"], "effects": {"staggered_bonus": [0.2, 0.4]}},
		"haymaker_swing": {"name": "Haymaker Swing", "rarity": "rare", "icon": "swoosh", "tags": ["Power"],
			"text": ["Hooks also hit every monster in a wide arc in front of you, for half", "Hooks also hit every monster in a wider arc in front of you, for full damage"], "effects": {"cleave": [1, 2]}},
		"shoulder_charge": {"name": "Shoulder Charge", "rarity": "rare", "icon": "chevrons", "tags": ["Movement"],
			"text": ["Dashing into a monster knocks it back and hits it for your base damage", "Dashing into a monster knocks it far back and hits it for 2x your base damage"], "effects": {"shoulder": [1, 2]}},
		"second_breath": {"name": "Second Breath", "rarity": "rare", "icon": "wind", "tags": ["Rage"],
			"text": ["Below 30% knuckle HP, punches cost nothing", "Below 40% knuckle HP, punches cost nothing"], "effects": {"second_breath": [0.3, 0.4]}},
		"blood_feud": {"name": "Blood Feud", "rarity": "epic", "icon": "skull", "tags": ["Rage"], "upgrades": "grudge",
			"text": ["Grudge: every hit from the marked monster adds +1x to your Grudge punch on it, and the Grudge punch staggers everything within 3m"], "effects": {"blood_feud": [1]}},
		"strike": {"name": "Strike!", "rarity": "epic", "icon": "hammer", "tags": ["Power"], "upgrades": "wrecking_ball",
			"text": ["Wrecking Ball: bowled monsters are knocked down for 2s, and a strike of 3 or more fills a quarter of your ultimate"], "effects": {"strike": [1]}},
		"red_mist": {"name": "Red Mist", "rarity": "epic", "icon": "rage", "tags": ["Rage"], "upgrades": "berserker",
			"text": ["Berserker: the lower your knuckles, the faster you punch too (up to +40%)"], "effects": {"red_mist": [1]}},
		"inferno_ii": {"name": "Inferno II", "rarity": "epic", "icon": "flame", "tags": ["Ultimate"], "upgrades": "inferno",
			"text": ["Inferno Uppercut: after it lands, you leap at a second monster"], "effects": {"inferno_ii": [1]}},
		"brimstone_wall": {"name": "Brimstone Wall", "rarity": "epic", "icon": "shield", "tags": ["Ultimate"], "upgrades": "bulwark",
			"text": ["Brimstone Shield: holds twice as many hits, and every hit it soaks hits the attacker back for your base damage"], "effects": {"brimstone_wall": [1]}},
		"thrill_of_the_fight": {"name": "Thrill of the Fight", "rarity": "legendary", "icon": "crown", "tags": ["Defense"], "seal": "bellman",
			"text": ["Every monster within 4m makes hits deal 5% less to you (up to 25%)"], "effects": {"crowd_guard": [0.05]}},
		"juggernaut": {"name": "Juggernaut", "rarity": "legendary", "icon": "mountain", "tags": ["Defense"], "seal": "headless",
			"text": ["Above half knuckle HP, hits deal 25% less and can't make you flinch"], "effects": {"juggernaut": [1]}},
		"ultimate_surge": SURGE,
		"avalanche": {"name": "Avalanche", "rarity": "legendary", "icon": "quake", "tags": ["Power"], "seal": "plague_doctor",
			"text": ["Every 4th punch you land shoves every monster in front of you back and staggers them"], "effects": {"avalanche": [1]}},
		"berserk": {"name": "Berserk", "rarity": "legendary", "icon": "horns", "tags": ["Rage"], "seal": "coffin_king",
			"text": ["Once a bout, dropping below half knuckle HP makes you hit twice as hard and take half damage for 8s"], "effects": {"berserk": [1]}},
	},
	"counter_master": {
		"closing_statement": {"name": "Closing Statement", "rarity": "common", "icon": "counter_arrow", "tags": ["Counter"],
			"text": "Counters against the last attack of a monster's combo deal +%s%%", "values": [20, 40, 60, 80], "effects": {"closing": [0.2, 0.4, 0.6, 0.8]}},
		"exploit": {"name": "Exploit", "rarity": "common", "icon": "eye", "tags": ["Counter"],
			"text": "A monster stays open %ss longer after you dodge its whole combo", "values": [0.2, 0.4, 0.6, 0.8], "effects": {"exploit": [0.2, 0.4, 0.6, 0.8]}},
		"iron_chin": {"name": "Iron Chin", "rarity": "common", "icon": "heart_plus", "tags": ["Defense"],
			"text": "+%s%% max knuckle HP", "values": [6, 12, 18, 24], "effects": {"knuckles_percent": [0.06, 0.12, 0.18, 0.24]}},
		"stinging_jab": {"name": "Stinging Jab", "rarity": "common", "icon": "bolt", "tags": ["Dodge"],
			"text": "Jabbing a monster within 1s of dodging it delays its next attack by %ss", "values": [0.1, 0.2, 0.3, 0.4], "effects": {"sting_delay": [0.1, 0.2, 0.3, 0.4]}},
		"answered": {"name": "Answered", "rarity": "common", "icon": "battery", "tags": ["Ultimate"],
			"text": "Counters fill your ultimate %s%% more", "values": [8, 16, 24, 32], "effects": {"counter_ult": [0.08, 0.16, 0.24, 0.32]}},
		"two_answers": {"name": "Two Answers", "rarity": "rare", "icon": "double_fist", "tags": ["Counter"],
			"text": ["A counter that knocks out its target readies another counter with your other hand, no dodge needed", "A counter that knocks out its target readies another counter with your other hand, up to twice in a row"], "effects": {"two_answers": [1, 2]}},
		"turnabout": {"name": "Turnabout", "rarity": "rare", "icon": "spiral", "tags": ["Counter"],
			"text": ["Counters stun the target for 0.6s", "Counters stun the target for 1.2s and stagger every monster within 2m of it"], "effects": {"turnabout": [1, 2]}},
		"read_twice": {"name": "Read Twice", "rarity": "rare", "icon": "hourglass", "tags": ["Counter"],
			"text": ["A clean dodge cuts Perfect Counter's cooldown by 1s", "A clean dodge cuts Perfect Counter's cooldown by 2s"], "effects": {"read_twice": [1.0, 2.0]}},
		"return_to_sender": {"name": "Return to Sender", "rarity": "rare", "icon": "counter_arrow", "tags": ["Dodge"],
			"text": ["Dodging an arrow, fireball or bolt sends it back at the thrower for 2x your base damage", "Dodging an arrow, fireball or bolt sends it back at the thrower for 4x your base damage"], "effects": {"return_sender": [2.0, 4.0]}},
		"crowd_reader": {"name": "Crowd Reader", "rarity": "rare", "icon": "eye", "tags": ["Dodge"],
			"text": ["Dodging an attack also dodges any other attack landing within 0.3s", "Dodging an attack also dodges any other attack landing within 0.6s"], "effects": {"crowd_reader": [0.3, 0.6]}},
		"checkmate": {"name": "Checkmate", "rarity": "epic", "icon": "crown", "tags": ["Counter"], "upgrades": "perfect_counter",
			"text": ["Perfect Counter: on a monster under 40% HP it knocks it out (a boss loses 15% of its max HP)"], "effects": {"checkmate": [1]}},
		"ghost_walk": {"name": "Ghost Walk", "rarity": "epic", "icon": "ghost", "tags": ["Dodge"], "upgrades": "phantom_step",
			"text": ["Phantom Step: recharges twice as fast, and whoever threw it is stunned for 1s"], "effects": {"ghost_walk": [1]}},
		"stored_answers": {"name": "Stored Answers", "rarity": "epic", "icon": "target", "tags": ["Dodge"], "upgrades": "dodge_chain",
			"text": ["Dodge Chain: each punch spends one dodge instead of all of them, and chains go up to 10"], "effects": {"stored_answers": [1]}},
		"riposte_ii": {"name": "Riposte II", "rarity": "epic", "icon": "star", "tags": ["Ultimate"], "upgrades": "riposte",
			"text": ["Riposte Stance: lasts 50% longer, and every counter in it is a Perfect Counter"], "effects": {"riposte_ii": [1]}},
		"untouchable_flow": {"name": "Untouchable", "rarity": "epic", "icon": "swoosh", "tags": ["Ultimate"], "upgrades": "flow_state",
			"text": ["Flow State: every punch that lands while it lasts adds 0.2s"], "effects": {"untouchable_flow": [1]}},
		"free_flow": {"name": "Free Flow", "rarity": "legendary", "icon": "flow", "tags": ["Counter"], "seal": "bellman",
			"text": ["A counter readies one more counter with your other hand"], "effects": {"free_flow": [1]}},
		"precision_strike": {"name": "Precision Strike", "rarity": "legendary", "icon": "crosshair", "tags": ["Counter"], "seal": "headless",
			"text": ["Perfect Counters work with any punch"], "effects": {"perfect_any_punch": [1]}},
		"ultimate_surge": SURGE,
		"mirror_match": {"name": "Mirror Match", "rarity": "legendary", "icon": "slip", "tags": ["Dodge"], "seal": "plague_doctor",
			"text": ["After a counter, the next attack aimed at you within 1s is slipped for you"], "effects": {"mirror_match": [1]}},
		"the_last_word": {"name": "The Last Word", "rarity": "legendary", "icon": "stopwatch", "tags": ["Counter"], "seal": "coffin_king",
			"text": ["Every 10th counter in a bout slows time for 3s, and every counter in it is a Perfect Counter"], "effects": {"last_word": [1]}},
	},
	"combo_master": {
		"second_gear": {"name": "Second Gear", "rarity": "common", "icon": "fast_fist", "tags": ["Combo"],
			"text": "From the 5th hit of a combo, +%s%% punch speed", "values": [4, 8, 12, 16], "effects": {"second_gear": [0.04, 0.08, 0.12, 0.16]}},
		"bounce_back": {"name": "Bounce Back", "rarity": "common", "icon": "chain", "tags": ["Combo"],
			"text": "Getting hit leaves %s%% of your combo instead of none", "values": [40, 55, 70, 85], "effects": {"bounce_back": [0.4, 0.55, 0.7, 0.85]}},
		"through_and_through": {"name": "Through and Through", "rarity": "common", "icon": "chevrons", "tags": ["Power"],
			"text": "Punches also hit the monster right behind your target for %s%%", "values": [10, 20, 30, 40], "effects": {"pierce_hit": [0.1, 0.2, 0.3, 0.4]}},
		"endurance": {"name": "Endurance", "rarity": "common", "icon": "heart_plus", "tags": ["Defense"],
			"text": "+%s%% max knuckle HP", "values": [5, 10, 15, 20], "effects": {"knuckles_percent": [0.05, 0.1, 0.15, 0.2]}},
		"speed_bag": {"name": "Speed Bag", "rarity": "common", "icon": "heavy_bag", "tags": ["Combo"],
			"text": "The first 5 hits of each combo come %s%% faster", "values": [6, 12, 18, 24], "effects": {"speed_bag": [0.06, 0.12, 0.18, 0.24]}},
		"thousand_fists": {"name": "Thousand Fists", "rarity": "rare", "icon": "double_fist", "tags": ["Combo"],
			"text": ["From the 20th hit of a combo, every punch throws an extra hit for half", "From the 15th hit of a combo, every punch throws an extra hit for half"], "effects": {"thousand_fists": [20, 15]}},
		"ricochet": {"name": "Ricochet", "rarity": "rare", "icon": "spiral", "tags": ["Combo"],
			"text": ["When a monster you're comboing goes down, the combo timer refills and your next punch dashes you to the nearest monster within 5m", "When a monster you're comboing goes down, the combo timer refills and your next punch dashes you to the nearest monster within 10m"], "effects": {"ricochet": [1, 2]}},
		"rhythm_guard": {"name": "Rhythm Guard", "rarity": "rare", "icon": "note", "tags": ["Dodge"],
			"text": ["Every 8th hit in a combo slips the next attack aimed at you", "Every 6th hit in a combo slips the next attack aimed at you"], "effects": {"rhythm_guard": [8, 6]}},
		"afterimage": {"name": "Afterimage", "rarity": "rare", "icon": "ghost", "tags": ["Dodge"],
			"text": ["A dodge leaves a violet afterimage that punches the attacker for your base damage", "A dodge leaves a violet afterimage that punches the attacker twice for your base damage"], "effects": {"afterimage": [1, 2]}},
		"stun_lock": {"name": "Stun Lock", "rarity": "rare", "icon": "chain", "tags": ["Combo"],
			"text": ["A staggered monster stays staggered while you keep hitting it, up to 1s", "A staggered monster stays staggered while you keep hitting it, up to 2s"], "effects": {"stun_lock": [1.0, 2.0]}},
		"aftershock": {"name": "Aftershock", "rarity": "epic", "icon": "quake", "tags": ["Combo"], "upgrades": "rapid_combos",
			"text": ["Rapid Combos: the stun also hits everything it stuns for your base damage, and holds the combo timer 2s"], "effects": {"aftershock": [1]}},
		"double_echo": {"name": "Double Echo", "rarity": "epic", "icon": "bolt", "tags": ["Combo"], "upgrades": "echo_fists",
			"text": ["Echo Fists: echoes echo once more, for half"], "effects": {"double_echo": [1]}},
		"spear_hands": {"name": "Spear Hands", "rarity": "epic", "icon": "fist", "tags": ["Power"], "upgrades": "long_reach",
			"text": ["Long Reach: punches at the edge of your reach hit 30% harder and push the monster back out of its range"], "effects": {"spear_hands": [1]}},
		"temporal_break_ii": {"name": "Temporal Break II", "rarity": "epic", "icon": "clock", "tags": ["Ultimate"], "upgrades": "temporal_break",
			"text": ["Temporal Break: every prompt you hit grows your combo by 3, and the break lasts 30% longer"], "effects": {"temporal_break_ii": [1]}},
		"unbroken_ii": {"name": "Unbroken II", "rarity": "epic", "icon": "infinity", "tags": ["Ultimate"], "upgrades": "unbroken",
			"text": ["Unbroken: lasts 50% longer, and your combo timer runs twice as long for 5s after it ends"], "effects": {"unbroken_ii": [1]}},
		"flurry": {"name": "Flurry", "rarity": "legendary", "icon": "burst", "tags": ["Combo"], "seal": "bellman",
			"text": ["Every 25th hit in a combo unleashes 8 lightning-fast hits on the target"], "effects": {"flurry": [1]}},
		"perpetual_motion": {"name": "Perpetual Motion", "rarity": "legendary", "icon": "infinity", "tags": ["Combo"], "seal": "headless",
			"text": ["Your combo timer pauses while you dodge and for 1s after"], "effects": {"perpetual_motion": [1]}},
		"ultimate_surge": SURGE,
		"blur": {"name": "Blur", "rarity": "legendary", "icon": "wind", "tags": ["Dodge"], "seal": "plague_doctor",
			"text": ["From the 30th hit of a combo you move 20% faster, and 1 in 5 attacks aimed at you goes straight through you"], "effects": {"blur": [1]}},
		"fifty": {"name": "Fifty Before They Blink", "rarity": "legendary", "icon": "stopwatch", "tags": ["Combo"], "seal": "coffin_king",
			"text": ["Reaching a 50-hit combo slows time for 3s (once a combo)"], "effects": {"fifty": [1]}},
	},
	"free_runner": {
		"rubber_legs": {"name": "Rubber Legs", "rarity": "common", "icon": "wing_boot", "tags": ["Movement"],
			"text": "Dashes cover %s%% more ground", "values": [8, 16, 24, 32], "effects": {"dash_reach": [0.08, 0.16, 0.24, 0.32]}},
		"cheap_shot": {"name": "Cheap Shot", "rarity": "common", "icon": "target", "tags": ["Power"],
			"text": "Punches from behind or the side deal +%s%%", "values": [10, 20, 30, 40], "effects": {"cheap_shot": [0.1, 0.2, 0.3, 0.4]}},
		"hang_time": {"name": "Hang Time", "rarity": "common", "icon": "feather", "tags": ["Movement"],
			"text": "Jump punches deal +%s%%", "values": [15, 30, 45, 60], "effects": {"hang_time": [0.15, 0.3, 0.45, 0.6]}},
		"stride": {"name": "Stride", "rarity": "common", "icon": "boot", "tags": ["Movement"],
			"text": "+%s%% move and sprint speed", "values": [5, 10, 15, 20], "effects": {"move_speed": [0.05, 0.1, 0.15, 0.2]}},
		"opportunist": {"name": "Opportunist", "rarity": "common", "icon": "eye", "tags": ["Power"],
			"text": "+%s%% damage to monsters winding up an attack", "values": [10, 20, 30, 40], "effects": {"opportunist": [0.1, 0.2, 0.3, 0.4]}},
		"dive_kick": {"name": "Dive Kick", "rarity": "rare", "icon": "dive", "tags": ["Movement"],
			"text": ["Jump punches stagger", "Jump punches stagger and knock the monster back"], "effects": {"dive_kick": [1, 2]}},
		"vault": {"name": "Vault", "rarity": "rare", "icon": "stairs", "tags": ["Movement"],
			"text": ["Dashing into a monster vaults you over it, to its back", "Dashing into a monster vaults you over it, and your next punch on it deals double"], "effects": {"vault": [1, 2]}},
		"blindside": {"name": "Blindside", "rarity": "rare", "icon": "ghost", "tags": ["Power"],
			"text": ["Your first punch on a monster that isn't facing you deals double", "Your first punch on a monster that isn't facing you deals triple"], "effects": {"blindside": [2.0, 3.0]}},
		"ghost_step": {"name": "Ghost Step", "rarity": "rare", "icon": "slip", "tags": ["Dodge"],
			"text": ["Dashing through an attack dodges it", "Dashing through an attack dodges it and gives the dash straight back"], "effects": {"ghost_step": [1, 2]}},
		"slick": {"name": "Slick", "rarity": "rare", "icon": "drop", "tags": ["Dodge"],
			"text": ["Getting hit while sprinting only grazes you (half damage)", "Getting hit while sprinting only grazes you (half damage), and every 3s one is a full dodge"], "effects": {"slick": [1, 2]}},
		"spear_line": {"name": "Spear Line", "rarity": "epic", "icon": "chevrons", "tags": ["Power"], "upgrades": "dash_punches",
			"text": ["Dash Punches: Spear Jab reaches twice as far and staggers; Haymaker's blast throws monsters into the ones behind them"], "effects": {"spear_line": [1]}},
		"bounce_house": {"name": "Bounce House", "rarity": "epic", "icon": "boot", "tags": ["Movement"], "upgrades": "head_stomp",
			"text": ["Head Stomp: each bounce in a chain deals 50% more than the last, and a chain of 3 gives your dash back"], "effects": {"bounce_house": [1]}},
		"full_tilt": {"name": "Full Tilt", "rarity": "epic", "icon": "road", "tags": ["Movement"], "upgrades": "momentum",
			"text": ["Momentum: goes up to x3, and a punch spends only half of it"], "effects": {"full_tilt": [1]}},
		"directors_cut": {"name": "Director's Cut", "rarity": "epic", "icon": "star", "tags": ["Ultimate"], "upgrades": "highlight_reel",
			"text": ["Highlight Reel: hits 3 more monsters, and every hit stuns them for 1s"], "effects": {"directors_cut": [1]}},
		"express": {"name": "Express", "rarity": "epic", "icon": "wave", "tags": ["Ultimate"], "upgrades": "hype_train",
			"text": ["Hype Train: lasts 1s longer for every monster you bowl over (up to +6s)"], "effects": {"express": [1]}},
		"high_ground": {"name": "High Ground", "rarity": "legendary", "icon": "mountain", "tags": ["Power"], "seal": "bellman",
			"text": ["Punches thrown in the air or from above the monster deal +50%"], "effects": {"high_ground": [0.5]}},
		"parkour": {"name": "Parkour", "rarity": "legendary", "icon": "stairs", "tags": ["Movement"], "seal": "headless",
			"text": ["You bounce off any monster's head you land on, stunning it for 0.5s, and a jump punch that lands gives your dash back"], "effects": {"parkour": [1]}},
		"ultimate_surge": SURGE,
		"never_where": {"name": "Never Where They Swing", "rarity": "legendary", "icon": "wind", "tags": ["Dodge"], "seal": "plague_doctor",
			"text": ["While sprinting, every 3rd attack aimed at you misses"], "effects": {"never_where": [1]}},
		"free_running": {"name": "Free Running", "rarity": "legendary", "icon": "footprints", "tags": ["Movement"], "seal": "coffin_king",
			"text": ["Every 5s of nonstop moving makes your next punch triple damage and a stagger"], "effects": {"free_running": [1]}},
	},
	"wise_guy": {
		"trash_talk": {"name": "Trash Talk", "rarity": "common", "icon": "rage", "tags": ["Rage"],
			"text": "Enraged monsters stay mad %ss longer", "values": [1, 2, 3, 4], "effects": {"insult_time": [1.0, 2.0, 3.0, 4.0]}},
		"below_the_belt": {"name": "Below the Belt", "rarity": "common", "icon": "gut", "tags": ["Power"],
			"text": "Body shots on enraged monsters deal +%s%%", "values": [12, 24, 36, 48], "effects": {"below_belt": [0.12, 0.24, 0.36, 0.48]}},
		"nice_to_meet_ya": {"name": "Nice to Meet Ya", "rarity": "common", "icon": "fist", "tags": ["Power"],
			"text": "Your first punch on each monster deals +%s%%", "values": [15, 30, 45, 60], "effects": {"first_punch": [0.15, 0.3, 0.45, 0.6]}},
		"shrug_it_off": {"name": "Shrug It Off", "rarity": "common", "icon": "horns", "tags": ["Rage"],
			"text": "A monster that hits you is enraged for %ss", "values": [1, 2, 3, 4], "effects": {"shrug_rage": [1.0, 2.0, 3.0, 4.0]}},
		"tough_guy": {"name": "Tough Guy", "rarity": "common", "icon": "heart_plus", "tags": ["Defense"],
			"text": "+%s%% max knuckle HP", "values": [5, 10, 15, 20], "effects": {"knuckles_percent": [0.05, 0.1, 0.15, 0.2]}},
		"say_it": {"name": "Say It To My Face", "rarity": "rare", "icon": "rage", "tags": ["Rage"],
			"text": ["Every 4th punch you land enrages the target for 4s", "Every 3rd punch you land enrages the target for 4s"], "effects": {"say_it": [4, 3]}},
		"bada_bing": {"name": "Bada Bing", "rarity": "rare", "icon": "burst", "tags": ["Rage"],
			"text": ["Knocking out an enraged monster enrages the nearest one", "Knocking out an enraged monster enrages the nearest two"], "effects": {"bada_bing": [1, 2]}},
		"made_man": {"name": "Made Man", "rarity": "rare", "icon": "shield", "tags": ["Defense"],
			"text": ["Fuggedaboudit stuns the monster whose hit you waved off for 1s", "Fuggedaboudit stuns the monster whose hit you waved off for 2s"], "effects": {"made_man": [1.0, 2.0]}},
		"vinnies_cousin": {"name": "Vinnie's Cousin", "rarity": "rare", "icon": "chain", "tags": ["Power"],
			"text": ["Vinnie holds monsters 1s longer, and you deal +25% to a monster he's holding", "Vinnie holds monsters 1s longer, and you deal +50% to a monster he's holding"], "effects": {"vinnie_bonus": [0.25, 0.5]}},
		"wake_up_call": {"name": "Wake-Up Call", "rarity": "rare", "icon": "hammer", "tags": ["Rage"],
			"text": ["Set-up hooks and uppercuts on enraged monsters stun them for 0.6s", "Set-up hooks and uppercuts on enraged monsters stun them for 0.6s and knock them back"], "effects": {"wake_up_call": [1, 2]}},
		"fuggedaboudit_ii": {"name": "Fuggedaboudit II", "rarity": "epic", "icon": "shield", "tags": ["Defense"], "upgrades": "fuggedaboudit",
			"text": ["Fuggedaboudit: waves off two hits in a row, and recharges 3s faster"], "effects": {"fuggedaboudit_ii": [1]}},
		"whole_crew": {"name": "The Whole Crew", "rarity": "epic", "icon": "crossed_gloves", "tags": ["Power"], "upgrades": "the_muscle",
			"text": ["The Muscle: Vinnie grabs two monsters and cracks their heads together (2x your base damage each)"], "effects": {"whole_crew": [1]}},
		"skim": {"name": "Skim Off the Top", "rarity": "epic", "icon": "coin", "tags": ["Rage"], "upgrades": "the_take",
			"text": ["The Take: enraged monsters pay triple, and knocking one out enrages the nearest monster"], "effects": {"skim": [1]}},
		"big_mouth_ii": {"name": "Big Mouth II", "rarity": "epic", "icon": "rage", "tags": ["Ultimate"], "upgrades": "big_mouth",
			"text": ["Big Mouth: insults every monster in front of you, not just one"], "effects": {"big_mouth_ii": [1]}},
		"family_reunion": {"name": "Family Reunion", "rarity": "epic", "icon": "crown", "tags": ["Ultimate"], "upgrades": "the_family",
			"text": ["The Family: a fourth goon shows up, and they stay 5s longer"], "effects": {"family_reunion": [1]}},
		"last_word": {"name": "Last Word", "rarity": "legendary", "icon": "skull", "tags": ["Rage"], "seal": "bellman",
			"text": ["Knocking out an enraged monster scares every monster within 4m off for 2s"], "effects": {"last_word_tony": [1]}},
		"untouchable_tony": {"name": "Untouchable", "rarity": "legendary", "icon": "shield", "tags": ["Defense"], "seal": "headless",
			"text": ["While any monster is enraged, the rest deal 25% less to you"], "effects": {"untouchable_tony": [1]}},
		"ultimate_surge": SURGE,
		"respect": {"name": "Respect", "rarity": "legendary", "icon": "crown", "tags": ["Rage"], "seal": "plague_doctor",
			"text": ["Bosses and contenders are enraged by your first punch on them"], "effects": {"respect": [1]}},
		"capo": {"name": "Capo", "rarity": "legendary", "icon": "crossed_gloves", "tags": ["Rage"], "seal": "coffin_king",
			"text": ["An enraged monster you hit slugs the nearest other monster for 3x your base damage and leaves you alone for 2s (once each)"], "effects": {"capo": [1]}},
	},
	"elementalist": {
		"conduit": {"name": "Conduit", "rarity": "common", "icon": "sigil", "tags": ["Spell"],
			"text": "Your selected powers are %s%% stronger", "values": [5, 10, 15, 20], "effects": {"conduit": [0.05, 0.1, 0.15, 0.2]}},
		"spellfist": {"name": "Spellfist", "rarity": "common", "icon": "hourglass", "tags": ["Ultimate"],
			"text": "Elemental Fists lasts %ss longer", "values": [1, 2, 3, 4], "effects": {"spell_time": [1.0, 2.0, 3.0, 4.0]}},
		"old_iron": {"name": "Old Iron", "rarity": "common", "icon": "anvil", "tags": ["Power"],
			"text": "+%s%% damage", "values": [4, 8, 12, 16], "effects": {"damage_percent": [0.04, 0.08, 0.12, 0.16]}},
		"afterglow": {"name": "Afterglow", "rarity": "common", "icon": "spark", "tags": ["Spell"],
			"text": "Punches within 1s of a power going off deal +%s%%", "values": [10, 20, 30, 40], "effects": {"afterglow": [0.1, 0.2, 0.3, 0.4]}},
		"runic_wraps": {"name": "Runic Wraps", "rarity": "common", "icon": "tape", "tags": ["Spell"],
			"text": "Every %sth punch you land sets off one of your selected powers", "values": [15, 13, 11, 9], "effects": {"runic_wraps": [15, 13, 11, 9]}},
		"resonance": {"name": "Resonance", "rarity": "rare", "icon": "ripple", "tags": ["Spell"],
			"text": ["Two different powers hitting the same monster within 2s stagger it", "Two different powers hitting the same monster within 2s stagger it, and it takes +20% from you for 3s"], "effects": {"resonance": [1, 2]}},
		"overflow": {"name": "Overflow", "rarity": "rare", "icon": "wave", "tags": ["Spell"],
			"text": ["Power damage beyond what knocks a monster out spills to the nearest one, at half", "Power damage beyond what knocks a monster out spills to the nearest one"], "effects": {"overflow": [0.5, 1.0]}},
		"ward": {"name": "Ward", "rarity": "rare", "icon": "shield", "tags": ["Defense"],
			"text": ["Every time a power goes off you gain a ward that soaks 3% of your max knuckle HP (stacks to 3)", "Every time a power goes off you gain a ward that soaks 5% of your max knuckle HP (stacks to 3)"], "effects": {"ward": [0.03, 0.05]}},
		"focus": {"name": "Focus", "rarity": "rare", "icon": "target", "tags": ["Spell"],
			"text": ["With only one power selected, any punch has a 10% chance to set it off", "With only one power selected, any punch has a 20% chance to set it off"], "effects": {"focus": [0.1, 0.2]}},
		"twin_cast": {"name": "Twin Cast", "rarity": "rare", "icon": "double_fist", "tags": ["Spell"],
			"text": ["Powers have a 15% chance to go off twice", "Powers have a 30% chance to go off twice"], "effects": {"twin_cast": [0.15, 0.3]}},
		"sigil_weave": {"name": "Sigil Weave", "rarity": "epic", "icon": "sigil", "tags": ["Spell"], "upgrades": "dual_sigil",
			"text": ["Dual Sigil: when both your powers hit the same monster within 2s, it bursts for 2x your base damage"], "effects": {"sigil_weave": [1]}},
		"deep_attunement": {"name": "Deep Attunement", "rarity": "epic", "icon": "target", "tags": ["Spell"], "upgrades": "attunement",
			"text": ["Attunement: the attuned power is 25% stronger, and every time it goes off you're 10% faster for 2s"], "effects": {"deep_attunement": [1]}},
		"spectrum": {"name": "Spectrum", "rarity": "epic", "icon": "star", "tags": ["Spell"], "upgrades": "prism",
			"text": ["Prism: each different power you set off in a row adds +10% damage, up to +40%"], "effects": {"spectrum": [1]}},
		"elemental_fists_ii": {"name": "Elemental Fists II", "rarity": "epic", "icon": "bolt", "tags": ["Ultimate"], "upgrades": "elemental_fists",
			"text": ["Elemental Fists: each element's chance is 20%, and every spell hits a second monster"], "effects": {"elemental_fists_ii": [1]}},
		"flame_burst_ii": {"name": "Flame Burst II", "rarity": "epic", "icon": "burst", "tags": ["Ultimate"], "upgrades": "flame_burst",
			"text": ["Flame Burst: the ring of fire goes off twice"], "effects": {"flame_burst_ii": [1]}},
		"archmage": {"name": "Archmage", "rarity": "legendary", "icon": "crown", "tags": ["Spell"], "seal": "bellman",
			"text": ["Your powers are 30% stronger while your ultimate is over half full"], "effects": {"archmage": [0.3]}},
		"living_conduit": {"name": "Living Conduit", "rarity": "legendary", "icon": "sigil", "tags": ["Spell"], "seal": "headless",
			"text": ["Select one more power, whatever your passive"], "effects": {"living_conduit": [1]}},
		"ultimate_surge": SURGE,
		"elemental_body": {"name": "Elemental Body", "rarity": "legendary", "icon": "nova", "tags": ["Spell"], "seal": "plague_doctor",
			"text": ["Getting hit sets off one of your selected powers on the attacker (once a second)"], "effects": {"elemental_body": [1]}},
		"grand_unification": {"name": "Grand Unification", "rarity": "legendary", "icon": "storm", "tags": ["Spell"], "seal": "coffin_king",
			"text": ["Every 20th time a power goes off, every power you own goes off too"], "effects": {"grand_unification": [1]}},
	},
}


static func deck(fighter: String) -> Dictionary:
	return DECKS.get(fighter, {})


static func info(fighter: String, id: String) -> Dictionary:
	return deck(fighter).get(id, {})


static func copies(card: Dictionary) -> int:
	return int(COPIES.get(card.get("rarity", "common"), 1))


static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


static func roman(rank: int) -> String:
	return ["", "I", "II", "III", "IV"][clampi(rank, 0, 4)]


## A card's text at a rank (1-based).
static func text(card: Dictionary, rank: int) -> String:
	rank = clampi(rank, 1, copies(card))
	if card.text is Array:
		var lines: Array = card.text
		return lines[mini(rank, lines.size()) - 1]
	var value = card.get("values", [0])[rank - 1]
	return String(card.text) % _num(value)


## The card's next rank, shown when it's offered (a common ranking up says
## what it does now too: "+16% damage" / "Now: +12% damage").
static func offer_text(card: Dictionary, rank_now: int) -> String:
	var next := text(card, rank_now + 1)
	if rank_now <= 0 or card.text is Array:
		return next
	return "%s\nNow: %s" % [next, text(card, rank_now)]


static func _num(value) -> String:
	if value is int or is_equal_approx(float(value), roundf(float(value))):
		return "%d" % roundi(float(value))
	return ("%.2f" % float(value)).rstrip("0")


## A card's effects at a rank: {effect: value}.
static func effects_at(card: Dictionary, rank: int) -> Dictionary:
	var result := {}
	if rank <= 0:
		return result
	for effect in card.get("effects", {}):
		var values: Array = card.effects[effect]
		result[effect] = values[mini(rank, values.size()) - 1]
	return result


## Whether a legendary has joined the deck (its seal is broken). The clears
## are passed in so this data module does not depend back on the GameState
## autoload that loads it (important for command-line balance tools).
static func available(card: Dictionary, clears := {}) -> bool:
	if card.get("rarity", "") != "legendary":
		return true
	return bool(clears.get(card.get("seal", ""), false))


## Three different cards drawn from what's left of a fighter's deck (copies
## not yet kept; legendaries once their seal is broken, at double weight).
## owned: {id: rank}. Fewer than three if the deck is nearly spent.
static func draw(fighter: String, owned: Dictionary, count := 3, clears := {}) -> Array:
	var pool := []
	var weights := []
	for id in deck(fighter):
		var card: Dictionary = deck(fighter)[id]
		var left := copies(card) - int(owned.get(id, 0))
		if left <= 0 or not available(card, clears):
			continue
		pool.append(id)
		weights.append(left * (LEGENDARY_WEIGHT if card.rarity == "legendary" else 1.0))
	var picks := []
	while picks.size() < count and not pool.is_empty():
		var total := 0.0
		for weight in weights:
			total += weight
		var roll := randf() * total
		var index := 0
		for i in weights.size():
			roll -= weights[i]
			if roll <= 0.0:
				index = i
				break
		picks.append(pool[index])
		pool.remove_at(index)
		weights.remove_at(index)
	return picks


## How many cards a fighter's deck still holds for them (copies not kept and
## available now).
static func left_in_deck(fighter: String, owned: Dictionary, clears := {}) -> int:
	var left := 0
	for id in deck(fighter):
		var card: Dictionary = deck(fighter)[id]
		if available(card, clears):
			left += copies(card) - int(owned.get(id, 0))
	return left


## Total copies in a deck (40).
static func deck_size(fighter: String) -> int:
	var total := 0
	for id in deck(fighter):
		total += copies(deck(fighter)[id])
	return total


# --- Balance --------------------------------------------------------------------------

## The average hand after this many picks with this many seals broken: the
## copies spread over the deck by how often each comes up (largest remainder,
## capped at each card's copies). {id: rank}. Par and the balance checks use it.
static func typical_hand(fighter: String, picks: int, seals: int) -> Dictionary:
	var weights := {}
	var total := 0.0
	for id in deck(fighter):
		var card: Dictionary = deck(fighter)[id]
		if card.rarity == "legendary" and SEALS.find(card.get("seal", "")) >= seals:
			continue
		weights[id] = copies(card) * (LEGENDARY_WEIGHT if card.rarity == "legendary" else 1.0)
		total += weights[id]
	var hand := {}
	var left := picks
	# Hand out whole copies, then the remainders, never past a card's copies.
	while left > 0 and total > 0.0:
		var share := float(left) / total
		var rests := []
		var given := 0
		for id in weights:
			var room := copies(deck(fighter)[id]) - int(hand.get(id, 0))
			if room <= 0:
				continue
			var exact: float = weights[id] * share
			var whole := mini(floori(exact), room)
			if whole > 0:
				hand[id] = int(hand.get(id, 0)) + whole
				given += whole
			if whole < room:
				rests.append([exact - floorf(exact), id])
		left -= given
		rests.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		for rest in rests:
			if left <= 0:
				break
			if given == 0 or rest[0] > 0.0:
				hand[rest[1]] = int(hand.get(rest[1], 0)) + 1
				left -= 1
		total = 0.0
		for id in weights:
			if int(hand.get(id, 0)) < copies(deck(fighter)[id]):
				total += weights[id]
	return hand


## Every effect of a hand, summed: {effect: total}.
static func hand_effects(fighter: String, hand: Dictionary) -> Dictionary:
	var fx := {}
	for id in hand:
		var card := info(fighter, id)
		var at := effects_at(card, int(hand[id]))
		for effect in at:
			fx[effect] = float(fx.get(effect, 0.0)) + float(at[effect])
	return fx
