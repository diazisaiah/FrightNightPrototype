class_name SoulShop
## The Soul Shop (camp): spend Souls on emotes, fighters and gear. The stock
## refreshes after every fight (each return to camp from the Arena, the Crypt
## or the Dead League), and can be rerolled for Souls (one more each time).
## Achievements still unlock their emotes for free; buying one skips ahead.

const EMOTE_SLOTS := 2
const GEAR_SLOTS := 3
const EMOTE_PRICE := 5
const GEAR_PRICE := {"rare": 3, "epic": 6, "legendary": 10}
const GEAR_RARITY := {"rare": 0.55, "epic": 0.35, "legendary": 0.1}
## Fighters for sale ({class_id: price}). Tony stays a secret (the Yonker
## hats); new fighters go here as they're added.
const FIGHTERS := {}
const REROLL_BASE := 1


## The current offers, restocked if there's been a fight since.
static func stock() -> Array:
	if GameState.shop_stock.is_empty() or GameState.shop_restock_at != GameState.fights_done:
		restock()
	return GameState.shop_stock


static func restock() -> void:
	var offers: Array = []
	var emotes: Array = Emotes.ORDER.filter(func(id: String) -> bool: return not Achievements.emote_unlocked(id))
	emotes.shuffle()
	for id in emotes.slice(0, EMOTE_SLOTS):
		offers.append({"kind": "emote", "id": id, "price": EMOTE_PRICE, "sold": false})
	for class_id in FIGHTERS:
		if not class_id in GameState.class_ids():
			offers.append({"kind": "fighter", "id": class_id, "price": FIGHTERS[class_id], "sold": false})
	var floor_number := maxi(2, Progression.current_tier() * Progression.FLOORS_PER_TIER)
	for i in GEAR_SLOTS:
		var rarity := _pick_rarity()
		var item: Dictionary = Items._roll_with(floor_number, Items.SLOTS.pick_random(), rarity)
		offers.append({"kind": "gear", "item": item, "price": GEAR_PRICE[rarity], "sold": false})
	GameState.shop_stock = offers
	GameState.shop_restock_at = GameState.fights_done
	GameState.shop_rerolls = 0
	GameState.save_game()


static func _pick_rarity() -> String:
	var roll := randf()
	for rarity in GEAR_RARITY:
		roll -= GEAR_RARITY[rarity]
		if roll <= 0.0:
			return rarity
	return "rare"


static func reroll_price() -> int:
	return REROLL_BASE + GameState.shop_rerolls


static func reroll() -> bool:
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
		"gear":
			GameState.add_to_armory(offer.item.duplicate(true))
		"fighter":
			GameState.fighters_bought[offer.id] = true
	GameState.save_game()
	return true
