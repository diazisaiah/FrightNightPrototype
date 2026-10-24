class_name SoulShop
## The Soul Shop (camp): spend Souls on emotes, fighters and gear. The stock
## refreshes after every fight (each return to camp from the Arena, the Crypt
## or the Dead League), and can be rerolled for Souls (one more each time).
## Achievements still unlock their emotes for free; buying one skips ahead.

const EMOTE_SLOTS := 2
const GEAR_SLOTS := 3
const EMOTE_PRICE := 8
## Gear is a backup, not a way around the Crypt: mostly plain finds, priced
## against boss Souls (1 + tier each), with good gear rare and dear.
const GEAR_PRICE := {"common": 6, "uncommon": 12, "rare": 22, "epic": 38, "legendary": 60}
const GEAR_RARITY := {"common": 0.5, "uncommon": 0.32, "rare": 0.13, "epic": 0.04, "legendary": 0.01}
## Fighters for sale ({class_id: price}). Tony stays a secret (the Yonker
## hats); new fighters go here as they're added.
const FIGHTERS := {"elementalist": 80}
## Seals a fighter needs before he's offered (the Catalyst needs two powers).
const FIGHTER_SEALS := {"elementalist": 2}
const REROLL_BASE := 2


## The current offers, restocked if there's been a fight since.
static func stock() -> Array:
	if GameState.shop_stock.is_empty() or GameState.shop_restock_at != GameState.fights_done or _stale():
		restock()
	return GameState.shop_stock


## Unsold gear from older rules (another price, or deeper than the Crypt
## you've beaten), restocked so it doesn't linger.
static func _stale() -> bool:
	for offer in GameState.shop_stock:
		if offer.kind != "gear" or offer.sold:
			continue
		if int(offer.price) != int(GEAR_PRICE.get(offer.item.rarity, -1)) \
				or int(offer.item.get("floor", 1)) > maxi(1, GameState.crypt_floors_cleared):
			return true
	return false


static func restock() -> void:
	var offers: Array = []
	var emotes: Array = Emotes.ORDER.filter(func(id: String) -> bool: return not Achievements.emote_unlocked(id))
	emotes.shuffle()
	for id in emotes.slice(0, EMOTE_SLOTS):
		offers.append({"kind": "emote", "id": id, "price": EMOTE_PRICE, "sold": false})
	for class_id in FIGHTERS:
		if not class_id in GameState.class_ids() and Progression.seals_broken() >= int(FIGHTER_SEALS.get(class_id, 0)):
			offers.append({"kind": "fighter", "id": class_id, "price": FIGHTERS[class_id], "sold": false})
	# Only as strong as the deepest Crypt floor you've beaten (floor 1 before
	# any), so cheesing a boss for a higher tier doesn't buy better gear.
	var floor_number := maxi(1, GameState.crypt_floors_cleared)
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
	return "common"


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
			Toast.show_on(GameState.get_tree(), "%s JOINS THE FIGHT" % GameState.fighter_name(offer.id).to_upper(), "Pick him from the Menu.")
	GameState.save_game()
	return true
