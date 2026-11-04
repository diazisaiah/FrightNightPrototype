class_name SoulShop
## The Soul Shop (camp): spend Souls on emotes, fighters and gear. The stock
## keeps until you refresh it: free once FREE_REFRESH_TIME has passed since
## the last free one (the button shows "!"), or any time for Souls (one more
## each time until the next free one). (2026-11-04: it used to restock after
## every fight.) Achievements still unlock their emotes for free; buying one
## skips ahead.

const EMOTE_SLOTS := 2
const GEAR_SLOTS := 3
const EMOTE_PRICE := 8
## Hand idles (IdleAnims.SHOP).
const IDLE_SLOTS := 1
const IDLE_PRICE := 6
## Skins (Skins.PRICE) for the fighters you have.
const SKIN_SLOTS := 1
## Gear is a backup, not a way around the Crypt: mostly plain finds, with
## good gear rare (prices: Gear.SHOP_SOULS).
const GEAR_RARITY := {"common": 0.5, "uncommon": 0.32, "rare": 0.13, "epic": 0.04, "legendary": 0.01}
## Fighters for sale ({class_id: price}). Tony stays a secret (the Yonker
## hats); new fighters go here as they're added.
const FIGHTERS := {"elementalist": 80}
## Seals a fighter needs before he's offered (the Catalyst needs two powers).
const FIGHTER_SEALS := {"elementalist": 2}
const REROLL_BASE := 2
## Real time between free refreshes, in seconds.
const FREE_REFRESH_TIME := 20 * 60


## The current offers (a first stock starts the free refresh's timer).
static func stock() -> Array:
	if GameState.shop_stock.is_empty():
		restock()
		_start_timer()
	elif _stale():
		restock()
	return GameState.shop_stock


## Seconds until the free refresh (0 when it's ready).
static func free_refresh_left() -> int:
	return maxi(0, GameState.shop_free_at - int(Time.get_unix_time_from_system()))


static func free_refresh_ready() -> bool:
	return free_refresh_left() == 0


static func _start_timer() -> void:
	GameState.shop_free_at = int(Time.get_unix_time_from_system()) + FREE_REFRESH_TIME
	GameState.save_game()


## "19:42" (or "1:05:00").
static func time_text(seconds: int) -> String:
	if seconds >= 3600:
		return "%d:%02d:%02d" % [seconds / 3600, seconds / 60 % 60, seconds % 60]
	return "%d:%02d" % [seconds / 60, seconds % 60]


## Unsold gear from older rules (another price, or deeper than the Crypt
## you've beaten), restocked so it doesn't linger.
static func _stale() -> bool:
	# Stock from before hand idles were sold.
	var unowned_idles := IdleAnims.SHOP.any(func(id: String) -> bool: return not GameState.idles_bought.has(id))
	if unowned_idles and not GameState.shop_stock.any(func(offer: Dictionary) -> bool: return offer.kind == "idle"):
		return true
	# Stock from before skins were sold.
	if not _skins_for_sale().is_empty() and not GameState.shop_stock.any(func(offer: Dictionary) -> bool: return offer.kind == "skin"):
		return true
	for offer in GameState.shop_stock:
		if offer.kind != "gear" or offer.sold:
			continue
		if not Gear.is_gear(offer.item) or int(offer.price) != Gear.shop_price(offer.item.rarity) \
				or int(offer.item.get("floor", 1)) > maxi(1, GameState.crypt_floors_cleared):
			return true
	return false


static func restock() -> void:
	var offers: Array = []
	var emotes: Array = Emotes.ORDER.filter(func(id: String) -> bool: return not Achievements.emote_unlocked(id) and not id in Achievements.EARN_ONLY)
	emotes.shuffle()
	for id in emotes.slice(0, EMOTE_SLOTS):
		offers.append({"kind": "emote", "id": id, "price": EMOTE_PRICE, "sold": false})
	var idles: Array = IdleAnims.SHOP.filter(func(id: String) -> bool: return not GameState.idles_bought.has(id))
	idles.shuffle()
	for id in idles.slice(0, IDLE_SLOTS):
		offers.append({"kind": "idle", "id": id, "price": IDLE_PRICE, "sold": false})
	var skins := _skins_for_sale()
	skins.shuffle()
	for id in skins.slice(0, SKIN_SLOTS):
		offers.append({"kind": "skin", "id": id, "price": Skins.PRICE, "sold": false})
	for class_id in FIGHTERS:
		if not class_id in GameState.class_ids() and Progression.seals_broken() >= int(FIGHTER_SEALS.get(class_id, 0)):
			offers.append({"kind": "fighter", "id": class_id, "price": FIGHTERS[class_id], "sold": false})
	# Only as strong as the deepest Crypt floor you've beaten (floor 1 before
	# any), so cheesing a boss for a higher tier doesn't buy better gear.
	# Gear (2026-11-04): set pieces at that floor's levels, half the merchant's
	# price, in Souls (Gear.SHOP_SOULS).
	var floor_number := maxi(1, GameState.crypt_floors_cleared)
	for i in GEAR_SLOTS:
		var rarity := _pick_rarity()
		var levels := Gear.level_range(floor_number)
		var item := Gear.make(Gear.PIECES.keys().pick_random(), Gear.SLOTS.pick_random(), rarity, randi_range(levels.x, levels.y))
		offers.append({"kind": "gear", "item": item, "price": Gear.shop_price(rarity), "sold": false})
	GameState.shop_stock = offers
	GameState.shop_rerolls = 0
	GameState.save_game()


## Skins you don't have, for fighters you do.
static func _skins_for_sale() -> Array:
	var fighters := GameState.class_ids()
	return Skins.CATALOG.keys().filter(func(id: String) -> bool:
		return not GameState.skins_owned.has(id) and Skins.CATALOG[id].fighter in fighters and not id in Skins.EARN_ONLY)


static func _pick_rarity() -> String:
	var roll := randf()
	for rarity in GEAR_RARITY:
		roll -= GEAR_RARITY[rarity]
		if roll <= 0.0:
			return rarity
	return "common"


static func reroll_price() -> int:
	return 0 if free_refresh_ready() else REROLL_BASE + GameState.shop_rerolls


## A new stock: free when the timer's run out (and it starts again), else for
## Souls.
static func reroll() -> bool:
	if free_refresh_ready():
		restock()
		_start_timer()
		return true
	var price := reroll_price()
	if GameState.souls < price:
		return false
	GameState.souls -= price
	var rerolls := GameState.shop_rerolls + 1
	restock()
	GameState.shop_rerolls = rerolls
	GameState.save_game()
	return true


static func buy(index: int) -> bool:
	var offers := stock()
	if index < 0 or index >= offers.size():
		return false
	var offer: Dictionary = offers[index]
	if offer.sold or GameState.souls < int(offer.price):
		return false
	GameState.souls -= int(offer.price)
	offer.sold = true
	match offer.kind:
		"emote":
			GameState.emotes_bought[offer.id] = true
		"idle":
			GameState.idles_bought[offer.id] = true
		"skin":
			GameState.skins_owned[offer.id] = true
			Toast.show_on(GameState.get_tree(), "SKIN: %s" % Skins.name_of(offer.id).to_upper(), "Wear it from Cosmetics.")
		"gear":
			GameState.add_to_armory(offer.item.duplicate(true))
		"fighter":
			GameState.fighters_bought[offer.id] = true
			Toast.show_on(GameState.get_tree(), "%s JOINS THE FIGHT" % GameState.fighter_name(offer.id).to_upper(), "Pick him from the Menu.")
	GameState.save_game()
	return true
