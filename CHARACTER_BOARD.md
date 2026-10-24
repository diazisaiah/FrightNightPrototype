# Fright Night — Character Board

Ideas for future fighters, parked here until we're ready to build them. Nothing on this board is in the game yet. When one gets picked up, its section moves into `GAME_DESIGN.md` under Classes.

**Rules every fighter follows** (same as the current five):
- A living human, horror-comedy boxing tone. No crosses or religious symbols, and no ground slams.
- Three traits: a **passive**, a **signature** move or rule, and an **ultimate**.
- A 33-point skill web: three branches of three nodes, each ending in a sealed capstone, plus Ultimate Surge and Ultimate II. A full web should be worth about ×1.7 POWER like everyone else's, checked with `balance_report.gd`.
- Card art and versus art in the same style as the existing portraits (prompts go in `art/versus/VERSUS_PORTRAIT_PROMPTS.md`).

---

## The Catalyst (Elementalist) [Planned 2026-10-24]

A buff old wizard who put his spells into his fists. Planned in GAME_DESIGN.md ("New fighter: the Elementalist"): two powers at once, Elemental Fists and Flame Burst ultimates, sold in the Soul Shop. Card art prompt is there too.

## The Gambler — "Snake Eyes" [Idea, planned 2026-10-15]

> *"House always wins. I'm the house."*

A slick card-room hustler in a green felt vest, rolled sleeves, a gold watch chain and a toothpick. Gloves taped with old playing cards. Color: **felt green and gold**.

**Fantasy:** every fight is a bet. You never quite know what you're getting, but you can tilt the odds your way.

### Passive: Roll the Bones
Two dice tumble across the HUD (bottom center, by the ult gauge) on a short timer:

- **The color die picks what changes:**

  | Face | Stat |
  |---|---|
  | Red | Damage |
  | Blue | Defense (knuckle HP lost to hits) |
  | Green | Punch speed |
  | Gold | Coins from kills |
  | Purple | Ultimate meter gain |
  | White | **Wild:** all of the above at half strength |

- **The number die picks how much**, as a multiplier on that stat until the next roll:

  | Roll | 1 | 2 | 3 | 4 | 5 | 6 |
  |---|---|---|---|---|---|---|
  | Multiplier | ×0.7 | ×0.8 | ×0.9 | ×1.15 | ×1.3 | ×1.5 |

  Your example fits the table: a **red 3** is ×0.9 damage, a **blue 5** is ×1.3 defense. 1–3 are bad beats and 4–6 are hot streaks. The average is a little above ×1, so luck is roughly neutral and skill tilts it (see Loaded Dice).
- **When it rolls:** every 8 seconds, plus a fresh roll at the start of each bout and each Crypt room. The dice clatter, and the result pops as "RED 5 · ×1.3 DAMAGE" in the stat's color.
- **Readable:** the active roll stays as a small die pair in the corner with a draining ring, so you always know whether you're hot or cold.
- **Bad beats are short,** never a disaster: the worst roll is ×0.7 for 8 seconds.

### Signature: Double Down
On a bad roll (1–3), land a **counter** to reroll immediately. A rerolled 6 shows "DOUBLE DOWN!" and lasts twice as long.
- This gives the Gambler a reason to play the defense system, and makes bad luck something you can fight your way out of.
- Alternative to consider: **Let It Ride.** A clean dodge on a good roll (4–6) holds it through the next roll.

### Ultimate: Jackpot
A slot machine drops in front of the camera and pulls itself. Three reels land, each on a stat color:
- **No match:** all three stats get ×1.3 for 8 seconds.
- **Two of a kind:** that stat gets ×1.8, the third gets ×1.3.
- **Three of a kind: JACKPOT.** That stat gets ×2.5, coins rain out of every hit, and the screen flashes gold. Triple gold pays a pile of coins on the spot.
- **Triple sevens** is the rare secret: a fourth reel face, about 1 in 200. Everything gets ×2, and the HUD dice turn gold for the rest of the bout.
- The meter fills at a normal rate. Ultimate Surge and Jackpot II make the reels more likely to match.

### Skill web (draft)
- **Loaded Dice** (consistency): Weighted (rerolls a 1 once per roll), Card Counter (the next roll shows ahead of time), Shaved Corners (the number die can't roll a 1), and the capstone **Loaded** (both dice favor your best stat).
- **High Roller** (swing): Bigger Bets (good rolls ×1.6 / ×1.4 / ×1.2 instead), Hot Hand (two good rolls in a row add +10%), Let It Ride, and the capstone **All In** (rolls come every 5 seconds and the extremes go further).
- **House Edge** (sustain and money): Comp'd Drinks (a good blue or white roll heals 3%), Rake (bad rolls also tax enemies: they take +10% damage while you're cold), Marker (gold rolls pay double in the Arena), and the capstone **The House** (your worst roll is ×1.0, so you can't lose).
- Plus Ultimate Surge and **Jackpot II** (one reel pre-locks on your best stat).

### Base stats (draft)
Power 60 · Defense 55 · Speed 65 · Combo 50 · Counter 70. No class mods: the dice are his class mods.

### Unlock idea (pick one)
1. **Lucky die drop:** a rare drop from Crypt chests, like Tony's Yonkers. A "SNAKE EYES" card plays when you find it.
2. **Bet on yourself:** before a Dead League bout, an optional wager doubles your purse if you win at a B grade or better. Win 3 wagers to unlock him.
3. **Card table in camp:** a back-room table appears after the Headless. Beat the Gambler at a quick dice game to recruit him.

### Open questions
- Do the dice roll on a timer (steady, readable) or per kill (more control, but stalls against bosses)? The draft says timer.
- Should Wild (white) exist, or keep it to five clean faces plus a "re-roll" face?
- How loud should the dice sound be? Audio is waiting on your real sounds.

### Art prompt notes
Knees-up 3:4 voxel portrait. Slick-haired hustler, green felt vest over a white shirt with rolled sleeves, a gold watch chain, a toothpick, and gloves taped with playing cards (no readable text). Two glowing dice tumble in one hand and a cocky half-smile. Felt-green and gold aura with floating chips and cards.

---

## Quick ideas (not planned yet)

### The Cutman
A ringside medic who fights. **Passive:** punches stitch you up a little; every 5th hit heals 2%. **Signature:** cuts make enemies bleed, and bleeding enemies hit softer. **Ultimate: Stop the Bleeding:** a full patch-up plus a short window where every hit heals. Survival-heavy, slow damage. Color: surgical white and blood red.

### The Bouncer
A huge doorman. **Passive:** grab-and-throw on a held hook: toss an enemy into others for crowd control. **Signature:** "You're not on the list": a shove that resets an attacker's turn. **Ultimate: Last Call:** clears the ring, throwing everything nearby out of it. Slow but controls crowds. Color: velvet-rope red and black.

### The Showman
A crowd-hype entertainer. **Passive:** punches landed **on the beat** of the music deal more damage and build hype (pairs with the new soundtrack). **Signature:** taunts and flashy combos fill a hype meter that boosts coins. **Ultimate: Encore:** time slows to the beat and every punch is on rhythm. Color: spotlight gold and purple.

### The Magician
A sleight-of-hand fighter. **Passive:** after a clean dodge, a decoy double stays where you stood and draws the next attack. **Signature:** "Pick a card": a counter pulls a random bonus (a burn, a freeze or a stagger). **Ultimate: Now You See Me:** you vanish and land a chain of backstabs on everything nearby. Color: stage-smoke violet and silver.
