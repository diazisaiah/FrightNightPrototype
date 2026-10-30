class_name Insults
## Tony's mouth. Weenie Hut Junior Mode gets the childishly tame versions;
## Pro Gamer Mode gets the "explicit" ones, censored with grawlix (the HUD
## puts a black bleep bar over them, and a censor beep plays). Each pool is a
## shuffled bag, so nothing repeats until every line has been said.

const TAME := [
	"Get the frick outta here!",
	"You big dummy!",
	"Go eat a crayon, ya doofus!",
	"Your mother's a very nice lady and I respect her!",
	"Hey! I'm walkin' here! Well, punchin'!",
	"You smell like a wet sock, buddy.",
	"Nice face. Did ya get a discount on it?",
	"My nonna hits harder, and she's in her nineties!",
	"Who taught you to fight, a pigeon?",
	"You're a real silly goose, ya know that?",
	"Go home and take a nap, ya cranky baby!",
	"I've seen scarier things in a lunchbox!",
	"You're about as tough as a soggy pretzel!",
	"Hey, nerd! Yeah, you!",
	"Your breath could knock out a hot dog cart!",
	"Ya mook! That's a word! Look it up!",
	"Fuhgeddaboudit, ya big baby!",
	"Is that your head or did a pumpkin fall on ya?",
]
const EXPLICIT := [
	"Get the *^%# outta here!",
	"You #@$%ing mook!",
	"My nonna hits harder, and she's been *&^% dead for thirty years!",
	"Who the %$#@ taught you to fight, a pigeon?",
	"Hey! I'm %$#@in' punchin' here!",
	"Ya look like a #@$%ing meatball somebody stepped on!",
	"Your mother's a lovely woman and you're a &%$# disgrace to her!",
	"Come here, ya %$#@ing skeleton-lookin' %$#@!",
	"Oh, you wanna go? You wanna %$#@ing GO?",
	"I've had pastrami with more %$#@ing backbone!",
	"Fuhgedda-%$#@ing-boudit!",
	"You call that a punch? My %$#@ing cousin Vinny punches harder!",
	"What're you, %$#@ing stupid? Don't answer that!",
	"I'm gonna knock you into next %$#@ing Tuesday!",
	"Ey, %$#@face! Yeah, you!",
	"You're uglier than the %$#@ing subway at 3 a.m.!",
	"Get your %$#@ing bones over here!",
	"I didn't come back from the dead for this %$#@!",
	"Bada %$#@ing bing!",
	"Your breath smells like a %$#@ing dumpster fire!",
]
## Fuggedaboudit: waving off a hit.
const QUIPS_TAME := [
	"Fuggedaboudit!", "That tickled!", "Is that all ya got?", "Pfft. Next!", "I barely felt that, ya dork!",
	"Ooh, a love tap!", "My grandma pinches harder!",
]
const QUIPS_EXPLICIT := [
	"Fuggedaboudit!", "That's it? %$#@ outta here!", "I barely %$#@ing felt that!", "Pfft. Next %$#@ing guy!",
	"Was that a punch or a %$#@ing compliment?", "Oh, you %$#@ed up now!",
]
## Knocking out a duel (an enraged enemy).
const KO_TAME := ["FRICK YEAH!", "SEE YA, DUMMY!", "BADA BING!", "LIGHTS OUT, NERD!", "GOODNIGHT, DOOFUS!"]
const KO_EXPLICIT := ["#@%& YEAH!", "SEE YA, %$#@FACE!", "BADA %$#@ING BING!", "LIGHTS %$#@ING OUT!", "STAY DOWN, YA %$#@!"]

static var _bags := {}


## True in Pro Gamer Mode: the explicit lines (censored), with a bleep.
static func explicit() -> bool:
	return not Controls.junior()


static func insult() -> String:
	return _draw("insult", EXPLICIT if explicit() else TAME)


static func quip() -> String:
	return _draw("quip", QUIPS_EXPLICIT if explicit() else QUIPS_TAME)


static func knockout() -> String:
	return _draw("ko", KO_EXPLICIT if explicit() else KO_TAME)


## A line holds a censored word (only the explicit pools use these symbols).
static func censored(line: String) -> bool:
	for symbol in ["%", "#", "@", "*", "^", "&", "$"]:
		if line.contains(symbol):
			return true
	return false


## The next line from a shuffled bag; refilled (reshuffled) when it runs dry.
static func _draw(key: String, pool: Array) -> String:
	var bag_key := key + ("_x" if pool == EXPLICIT or pool == QUIPS_EXPLICIT or pool == KO_EXPLICIT else "_t")
	var bag: Array = _bags.get(bag_key, [])
	if bag.is_empty():
		bag = pool.duplicate()
		bag.shuffle()
	var line: String = bag.pop_back()
	_bags[bag_key] = bag
	return line
