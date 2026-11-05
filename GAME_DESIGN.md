# Fright Night — Game Design

*(Renamed from PunchCraft on 2026-10-09. itch.io page: isaiahd0221.itch.io/fright-night. The Godot project folder is still `punch-craft/`; saves from the PunchCraft user folder are copied over automatically on first launch.)*

> Living design doc. **[Decided]** = agreed direction. **[Proposed]** = suggestion, not locked in. **[Open]** = still needs an answer.

## Pitch

A dark first-person brawler incremental. No weapons — you fight with your fists. Each run you go out into a night graveyard and punch your way through waves of zombies and skeletons until your knuckles break. Kills give coins and XP, which you spend at camp on permanent upgrades so the next run goes further.

Inspirations: Nodebuster and other run-based incrementals (short runs, big branching upgrade tree between runs), first-person melee games.

## Direction change (2026-10-08) [Decided]

The first version had stationary resources (trees, rocks) to punch for wood and stone. After playing it, that wasn't fun. The game is now about **fighting enemies for money**, with a **darker** look. Trees, rocks, wood, stone, ores, caves and the resource-gathering plans are dropped for now.

## Core loop [Decided]

1. **Run:** a night falls; waves of enemies come at you out of the fog.
2. **Knuckles break:** knuckle HP hits 0 and the run ends. Knuckle HP is the run timer **and the only health bar** — enemy hits damage your knuckles.
3. **Keep everything:** all coins and XP from the run are kept.
4. **Camp:** spend XP levels (stats + skills) and coins (upgrade tree).
5. Start the next run.

## Combat & punching [Decided]

### Controls

| Input | Punch |
|---|---|
| Left click | Jab |
| Right click | Cross |
| Shift + Left click | Left hook |
| Shift + Right click | Right hook |
| Ctrl + Left click | Left uppercut |
| Ctrl + Right click | Right uppercut |
| Q / E | Slip left / right |
| Ctrl + A / D | Roll left / right |
| Ctrl + S | Back step |
| Double tap W | Forward dash (~2.5m burst, 0.5s cooldown) |
| Space | Jump |
| R | Ultimate (when the meter is full) |

The table is the **Classic** scheme, which is the default.

#### Weenie Hut Junior Mode / Pro Gamer Mode [Built, 2026-10-14]

Playtesting said there were too many controls. **Settings → Controls → Mode**:
- **Weenie Hut Junior Mode** (the default): **Q dodges left and E dodges right**.
  - The game picks the slip, roll or back step that beats the incoming attack, as long as you press the side it goes to.
  - Back steps, and attacks either side dodges, accept both keys.
  - When you press, it reads the most urgent attack being wound up within 7m (`Enemy.incoming_attack` / `attack_eta`).
  - If a different attack lands than predicted, the dodge still counts, as long as the side you pressed beats it.
  - The wrong side grazes, as usual.
  - Training hints show just the key ("LEFT HOOK - E").
- **Pro Gamer Mode**: the original controls, where every dodge has its own input (the schemes below).
- **Picked on the first start (2026-10-29):** after choosing your first fighter, "HOW DO YOU DODGE?" offers both modes (Weenie Hut Junior highlighted), with "You can change this any time in Settings, Controls." in gold, then the tutorial offer (`title.gd` `_build_mode_offer`).

**Default dodge scheme is now Space + A / D / S / W** (playtesters liked it best; jump is on C). Settings saved before this change switch to it once.

#### Key bindings [Built 2026-10-16]
- **Weenie Hut Junior Mode jumps with Space.** Q / E do every dodge there, so there's no dodge modifier. Dash is a double-tap of W, or its own key.
- **Every action can be rebound** in Settings → Controls → Key bindings: move, sprint (also the hook modifier), jump, jab, cross, hook, uppercut, dodge/slip left and right, and dash. Pro Gamer Mode adds the dodge modifier, roll left/right and back step. Plus ultimate, use and map. Click a key, press the new key or mouse button, and Esc cancels.
- **Conflicts swap.** Taking another action's key gives that action yours. "Reset keys" clears them all. Rebound keys show in gold.
- **The hints follow.** Every hint (HUD line, pause Controls tab, tutorial keycaps, dummy cues) uses `Controls.key_name`.
- Dedicated roll, back step and dash keys work in any scheme. A hook or uppercut key works even in the Shift/Ctrl + click scheme, alongside the clicks.
- Saved in Settings as `bindings` ({action: "k:<physical key>" | "m:<mouse button>"}).
- The tutorial's coach card sits under the pause menu and Settings, instead of covering them.

#### Controllers [Built 2026-10-16]
Xbox-style and PlayStation (DualSense / DualShock) controllers, on desktop and in the browser (`pad.gd`, autoload "Pad").
- **Layout** (`Controls.PAD_LAYOUT`):
  - Left stick moves, right stick looks. Click the left stick to latch sprint until you stop.
  - X / Y (Square / Triangle) jab and cross. LT / RT (L2 / R2) hook and uppercut.
  - LB / RB (L1 / R1) dodge left and right (slips in Pro Gamer Mode).
  - A (Cross) jumps, B (Circle) uses.
  - D-pad: up dashes. In Pro Gamer Mode, left/right roll and down back steps.
  - Click the right stick for the ultimate. Start (Options) pauses, View (Create) is the Crypt map. In training, View skips the tutorial, then cycles the dummy's level.
- **Rebindable** in Settings → Controls → Bindings (a Controller column beside Keyboard). Buttons and triggers can be rebound; the sticks stay move and look. Swaps and "Reset keys" work like the keyboard. Saved as `pad_bindings` ({action: "j:<button>" | "a:<axis>:<+/->"}).
- **Settings:** controller look speed, invert look, vibration (a buzz when you're hit, a big one on a knockout).
- **Prompts follow the device.** `Pad.active` flips to the controller on any button or stick and back on any key, click or mouse move. Every hint swaps live through `Controls.watch()`: tutorial keycaps (`<move>`, `<jab>`...), practice card, pause Controls tab, ultimate gauge, dummy cues, Crypt "use" prompts, title card. PlayStation pads get PlayStation names (detected by name or Sony's vendor id).
- **Menus: a controller cursor.** Whenever a fight isn't running, the left stick (or D-pad) moves a gold pointer. A / Cross clicks (hold to drag, e.g. panning the upgrade and skill webs; double-tap buys a node). The right stick scrolls and zooms, and B / Circle backs out. It sends real mouse events, so every screen works, the browser included.
- Fights pause on a dedicated `pause` action (Esc / Start), not `ui_cancel`, which B also sends.

#### Control schemes [Testing, 2026-10-11]

Settings → Controls has three dropdowns, so layouts can be mixed and tried before choosing the default. The code is in `controls.gd`, which rewrites the InputMap. The HUD controls line, tutorial hints and demo reel captions all follow the chosen scheme.

| Setting | Options |
|---|---|
| **Hooks / uppercuts** | **Hold Shift / Ctrl + click** (classic) · **Hold Shift / Z + click** (2026-11-04: Z uppercuts instead of Ctrl, so a browser never sees Ctrl held with a click; Ctrl dodges still work in the schemes that use it) · **Scroll wheel**: down = hook, up = uppercut · **Mouse side buttons**: front = hook, back = uppercut |
| **Rolls / back step** | **Ctrl + A / D / S** (classic) · **Space + A / D / S / W** (W dashes; jump moves to C) · **Double-tap A / D / S** · **Tab left roll / R right roll / Ctrl+S back step** (ultimate moves to T; map moves to M) · **Shift + Q / E roll, double-tap S back step** (added 2026-10-30, the user's idea: Q / E alone still slip, Space stays jump, nothing needs a modifier with a direction) |
| **Slips** | **Q / E** · **Q / E or mouse side buttons** (back = left, front = right; not available when hooks use the side buttons) |

- With hook/uppercut buttons, the punch comes from the hand that didn't throw last, so jab → scroll keeps alternating hands and the heavy-punch setup works naturally. Shift is then only sprint, so you can sprint and jab.
- In the modifier dodge schemes, either key can be pressed first (S then Ctrl works, not just Ctrl then S). Double-tapping W always dashes.
- **Open:** which mix becomes the default. Mouse side buttons in a browser may trigger the browser's back/forward.

- All four punches are always available.
- Shift is also sprint: holding Shift sprints, and clicking while holding it throws a hook. No crouch for now.
- Hooks and uppercuts are **heavy** punches with more knockback. **They only get their damage multiplier and stagger when set up**: the previous landed punch must be a jab or cross from the *other* hand (e.g. jab → right uppercut, or jab → cross → hook). A heavy punch without a setup does plain 1× damage, so spamming uppercuts doesn't work.
- Stagger cancels a zombie slam or a skeleton's bow draw.
- Every hit knocks the enemy back a little, so you can keep a zombie out of range.

### Counters

- After a successful dodge, the next punch within 1.5s with the **matching hand** (see Defense v2) is a **Counter**: 2× damage, always staggers, extra knockback and a big impact. "COUNTER READY - LEFT/RIGHT/ANY HAND" shows under the crosshair.
- A defense that dodges nothing leaves you open for a moment before the next one, so they can't be spammed. A successful dodge can chain straight into another.
- A dodged zombie overcommits and stays open 0.6s longer.
- Telegraphs: zombie eyes flare and it growls during the windup; a skeleton's bowstring glows brighter as it draws, and arrows carry their own light.
- **Flinch:** a clean hit stops you punching for 0.35s and drops your combo.

### Defense v2: boxing defense [Built]

Replaces the single slip. Getting better at the game should mean better technique, not just better stats.

| Key | Move | Beats | Counter with |
|---|---|---|---|
| Q | Slip left | Cross (enemy's right straight) | Left-hand punch |
| E | Slip right | Jab (enemy's left straight) | Right-hand punch |
| Ctrl + A | Roll left | Right hook | Left-hand punch |
| Ctrl + D | Roll right | Left hook | Right-hand punch |
| Ctrl + S | Back step | Uppercuts, slams | Any punch |

Layout history: Z/C/X were too far from WASD; Space + A/D rolls made you keep strafing after the roll. Caps Lock / F mirrored the slips but were a reach. Double taps (A/A, D/D, S/S) were tried next but were too hard to pull off in time. **Now (2026-10-09): Shift + direction** — Shift+A roll left, Shift+D roll right, Shift+S back step; double tap W still dashes forward (Shift+W is how you start sprinting, so it can't dash). The key that triggered a dodge stops moving you until you let go of it, so you roll in place. Holding Shift after a roll means a click right after is already a hook — a natural roll → hook counter. Trade-off: pressing A/D/S while already sprinting rolls/back steps instead of sprint-strafing. Space is always jump. A dash punch counts as a running punch for the Free Runner. **Changed (2026-10-10): Ctrl + direction.** Shift-dodges meant you could not sprint sideways (Shift+A/D rolled instead), and Shift+S was awkward. Now Ctrl+A/D roll and Ctrl+S back steps; Shift only sprints, in any direction. Ctrl+W does nothing in-game (browsers close the tab on it), so the web build asks before leaving the page. Holding Ctrl after a roll means a click right after is an uppercut.

- The side you dodge to decides the counter hand: left slips/rolls → left punches, right → right. Back step works with anything.
- Each enemy attack has one correct answer; enemies must telegraph clearly *which* attack is coming, not just *when*.
- Current enemies map onto it: zombie slam → back step; skeleton arrows → slip.
- Later: enemies that throw real punches (jab, cross, hooks, uppercuts) and eventually combos.
- Slip = 0.3s window; roll = 0.4s window, dips under and comes up to the side; back step = 0.35s window, hops you back, then snaps you back to where you were (immediately if it dodged) so you're in range to counter.
- After a defense that dodges nothing, the next one is available 0.1–0.15s after its window ends (0.4s total for a slip, 0.5s for a roll or back step) — shorter than the gap between punches in an enemy combo. After a graze, 0.1s.
- Roll window is 0.4s.
- Getting hit cleanly causes a short flinch (can't punch, combo drops), so defense and super armor both matter.
- Graze = 40% damage.
- Right timing but the wrong move = **graze**: reduced damage, no counter.
- Arrows: **either slip** dodges them.
- Countering with the wrong hand = a **regular punch**, no counter bonus.
- Color language for telegraphs: **blue = slip, orange = roll, red = back step**.
- **Every attack telegraphs in three beats** (2026-10-09): the enemy winds up (pose only, no glow), then once it's fully wound a **short bright flash** in the defense color plus a "ting" sound, then the swing lands 0.22s later. The flash is the "dodge now" cue: pressing at the flash is inside every dodge window. Windups are always at least 0.37s so the flash never gets skipped.
- **Combos read ahead** (2026-10-09): when a combo's attack flashes, the arm throwing the *next* attack lights up dimmer in its own color and stays lit through its windup, then gets its own bright flash. E.g. jab (blue flash) → the other glove already shows the hook (orange/yellow) as you slip → as you roll the hook, the uppercut's red shows. Uppercuts and haymakers in a combo are thrown with the hand opposite the punch before them, like a real combo, so the preview can show right away. Gloves are tinted in the glow color while lit so the hue stays readable up close.
- Weapon attacks: staff swing → **roll** (either way); sword thrust → **slip** (either way), then counter with a hook to its open side; sword slash → **roll** (either way); fireball → **slip** (either way) or just move out of its path.
- **Ground smash (Hulk)**: slips and rolls don't help. **Jump** so you're in the air when it lands (counts as a dodge and readies a counter with either hand), or get out of the red ring (sprint).

### Head & body shots [Built]

Where you aim decides it — no extra keys. A punch landing above the enemy's neck is a head shot, below is a body shot.

- **Head shots:** ×1.3 damage (bright yellow numbers). Smaller target.
- **Body shots:** normal damage (light blue numbers), but each one adds body damage that slows *everything* the enemy does — movement, windups, cooldowns — up to 35% slower. It fades over time. "WINDED" pops when it gets high. Work the body to make enemies easier to read, then go upstairs to finish.

### Combos
- **Combo rules (2026-10-16):**
  - A set-up hook sets up an uppercut from the other hand, so jab, cross, hook, uppercut is fully set up.
  - Jab, jab keeps the combo for everyone (a double jab). The other hand has to come next; a third same-hand punch starts it over. The Blur's Triple Jab skill allows a third jab.
  - A hook or uppercut that isn't set up shows SLOPPY (jab damage at 2-3x the knuckle cost). After 3 in a row, a tip says to throw a jab or cross first (at most every 25s).

- Alternating left and right punches builds a combo, which adds a damage multiplier.
- The combo drops if you punch the same hand twice in a row or stop landing hits for too long.
- **Combo rules [rewritten 2026-11-02]:** see "Combo rules" in the Controls patch section below (grow / hold / lose). Jab, cross grows it once; a third straight in a row only holds it.

### Damage

`damage = base × punch type multiplier × combo multiplier − enemy armor`
Flat armor subtracted at the end means weak hits on armored enemies do nothing ("BLOCKED"), while combo hits and heavy punches get through.

**Every punch that lands costs a fixed amount of knuckle HP, whatever it hits:** jab / cross **1**, hook **2**, uppercut **3**. Defense does *not* reduce this (it only reduces damage from enemy hits), so lasting longer means more knuckle HP. Whiffs are free. Hard Knuckles (skill) gives a chance for a punch to be free; Counter Master counters are free 50% of the time.

### Feedback & juice

- **Head movement**: every punch moves the view a little — it loads up during the windup (cross shifts back onto the rear side, hooks dip toward the punching side, uppercuts dip down) then drives into the punch and settles back. Mirrored for the other hand. Layered on top of dodge leans.

**Finishing blows send bodies flying (2026-10-14):**
- The killing punch decides the flight:
  - uppercuts launch straight up with a backflip;
  - hooks throw the body sideways in the direction of the swing (a left hook goes to your right), spinning;
  - straights knock it back;
  - Spear Jabs skewer it backward;
  - Haymakers send it far.
- **Counters** make the launch 1.8x stronger, with a short slow-mo and "K.O.!".
- **Clean counters and Perfect KOs** are 3.4x and ridiculous:
  - heavy slow motion, a flash and fire ring, and a spark trail;
  - a random "OBLITERATED!" / "SENT TO THE MOON!" / "GOODNIGHT!" / "FATALITY!";
  - the flying body **bowls into other enemies** (3x damage, stagger, and they fly too).
- Bosses fly about half as far. Deaths from burns, poison and the like still crumple in place. The body shatters into cubes when it lands or hits a wall (`Enemy._launch` / `_fly`).

Freeze-frame (hitstop) on every hit, longer for heavy hits, counters and kills; camera shake and FOV kick; enemies flash, recoil and spray chips (green for zombies, bone for skeletons, sparks off armor); kills fling the body and burst coins; damage numbers with "HOOK!"/"UPPERCUT!"/"COUNTER!" captions; crosshair hit marker (color = hit type, X on kill); combo counter that pops and heats up; red edge flash when hit and a pulsing red vignette under 30% knuckles; slow-motion when knuckles break. All sounds are synthesized placeholders (`sfx.gd`), ready to swap for real recordings.

## Classes [Built — numbers are first guesses]

Future fighter ideas (The Gambler and others) are parked in `CHARACTER_BOARD.md`; nothing there is built yet.

### The fighters (2026-10-10)

Each class is played as a named fighter, from the character pitches. The fighter name is shown everywhere: the HUD class line, camp, the title footer and the select cards. The class name appears as a tag beside it.

| Fighter | Class | Color | Card traits | Tagline |
|---|---|---|---|---|
| The Mauler | Berserker | Ember orange | Super Armor, Massive Damage, Inferno Uppercut | Takes the hit. Gives it back. |
| The Blur | Combo Master | Violet | Rapid Combos, Fast Hands, Temporal Break | Fifty hits before they blink. |
| The Answer | Counter Master | Ice blue | Perfect Defense, Counter Focus, Perfect Counter | Every attack is a question. |
| The Stray | Free Runner | Green | Agile Movement, Sprint Punches, Highlight Reel | Never where they swing. |

Class colors are only used on the player's side (hands, cards, details). Enemy gloves keep the slip/roll/back step telegraph colors. Highlight Reel lightning stays blue. The Combo Master ultimate is now **Temporal Break** (was Time Stop).

**Fighter select** (title screen, CLASS or first PLAY): four cards using the pitch art (`art/fighter_*.jpg`), each with THE + name in red, a class tag, three trait rows with icons, a level badge, and PLAYING on the current one.
- Clicking a card slides it to the left, fades the other three, and opens a details panel: tagline, five stat bars in the fighter's color, the ultimate and how it works, and **Back** / **Choose The X**.
- The right side of the screen plays the **demo reel** (`demo_reel.gd`): a small 3D ring in its own SubViewport where the fighter's own hands fight a training dummy on a script. It loops the signature move (Super Armor / Shockwave / Perfect Counter / Running Punch), then the ultimate. A caption along the bottom shows which is playing.
- Back or Esc slides the card home and fades the others back in. Choose plays as that fighter; on the first start it goes on to the tutorial offer.

**Hands per fighter** (`fists.gd`): voxel models, thousands of 8.5 mm cubes drawn as one MultiMesh per material (only the visible surface is kept), painted per fighter with seams, creases, tape turns and slight color variation. Glow effects show only when the ultimate is ready. They render on their own layer with their own soft fill light; the player's lantern doesn't light them, because it sat right beside the arms and washed them out.

| Fighter | Hands (voxel models) | Ultimate-ready glow |
|---|---|---|
| Mauler | Padded red boxing gloves with a seam down the back, lighter knuckle padding, scuffs, a taped white cuff laced red on the palm side, heavy bare forearms | Cracks in the leather glow orange, embers rise off the gloves |
| Blur | Purple tape wound diagonally around each finger, over the knuckles and around the palm; purple wrist wrap; dark sleeve with a violet cuff | Violet speed streaks trail back along the arms, a ring turns around each wrist, the cuff glows (afterimages on punches at any time) |
| Answer | Black gloves taped white across the knuckles and around the hand; thick blue forearm wraps in bands (blue, navy, white stripes); dark coat | Blue lightning crawls along the arms, sparks, the white wrap stripes glow blue (sparks alone also show on a hand that's ready to counter) |
| Stray | Green fingerless gloves edged in black, bare fingers out front; white tape wound up the forearm; red bandana knotted on the left forearm; hoodie with a green cuff | Green energy ribbons spin around the forearms, the cuff glows |


Picked at camp (applies to runs and training). A HUD line shows the class special's status.

| Class | Stats | Special |
|---|---|---|
| Berserker (default) | Damage ×1.3, knuckles ×1.25, +3 defense, combo growth ×0.6 | Super armor (8s recharge); heavies need no setup |
| Counter Master | Damage ×0.85, knuckles ×0.9, counters ×3, dodge windows ×1.4 | Perfect counter KO (12s cooldown) |
| Combo Master | Damage ×0.75, punch speed ×1.35, combo growth ×1.5, combo window +1s | Every 5th combo hit: shockwave stuns enemies within 4m for 1.5s, combo timer frozen 1s |
| Free Runner | Sprint ×1.35 | Sprint punches lunge and deal ×2 to full-HP enemies; jump punches deal ×2 to enemies under 30% HP |

[Open] Class skill trees (upgrading super armor, etc.) — skills are still shared for now. Counter Master's perfect counter needs Hooks or Uppercuts learned (available in training regardless).

Classes change how you fight, so each one is a different technique to learn.

### Berserker (simplest to play)

- Big damage, not worried about getting hit or about combos.
- **Super armor:** counters by *taking* a hit instead of dodging it. Starts able to eat **one hit** — still takes the damage, but no flinch or hit feedback — and then counter.
- Super armor is upgradeable (more hits absorbed, less damage while armored, faster recharge…).
- The Berserker **can still dodge**.
- Super armor **recharges on a timer**.
- Heavy punches don't need a setup for the Berserker, but the combo multiplier grows slower.

### Counter Master

- Less damage, defense and knuckle HP than the Berserker.
- Higher counter multiplier and more forgiving dodge timing windows.
- **Special:** a perfect counter — correct dodge side *and* counter with a hook or uppercut from the matching hand — **instakills** (on a cooldown). Against bosses it deals big bonus damage instead.

### Combo Master

- Faster punches, less damage.
- Better combo multiplier and a longer combo timer.
- **Special:** the **5th punch in a combo stuns all enemies in a radius** and freezes the combo timer for 1 second.

### Free Runner

- Faster sprint; otherwise normal stats.
- **Dash punches (2026-10-14, replaced sprint punches)**: dash forward (Space + W, or double-tap W), then punch within 0.55s.
  - Only the straights count: hooks and uppercuts out of a dash are normal punches.
  - **Jab = Spear Jab**: x1.8 damage. It runs through every enemy in a 5m line; the others take 80% and are shoved along. It still finds the first enemy in the line if the crosshair misses.
  - **Cross = Haymaker**: x2.4 damage, always staggers, and knocks the target back 3.5x as far. Enemies beside it in front of you take 40% and get blasted back.
  - The Opportunist skill adds to both multipliers.
- **Jump punch on an enemy under 30% HP** deals bonus damage.

- [Proposed] Stats and the coin upgrade tree stay shared; each class gets its own skill tree.

### Ultimates [Built, 2026-10-10]

- **The Mauler's meter never drains from hits** (2026-10-16). Super armor only soaks one punch, and the rest of a combo used to cost 10% each, emptying the meter right when Inferno needed the hit. Every other class still loses 10% per clean hit.

Every class has an ultimate charged by an **ultimate meter** (0-100, bottom center of the HUD; it glows gold when full). Playing well charges it; mashing barely does:

| Event | Meter |
|---|---|
| Plain jab / cross that lands | +1 |
| Free Runner running punch | +4 |
| Heavy after a set-up (jab -> hook) | +3 x combo multiplier |
| Dodge / clean dodge | +5 / +10 x combo multiplier |
| Counter / clean counter | +8 / +12 x combo multiplier |
| Getting hit cleanly | -10 |

It doesn't charge while an ultimate is running, and the ultimate's own punches don't refill it. It lasts across Crypt rooms and Graveyard nights within a run. The ultimate action fires it: **R** normally, or **T** in the Tab/R roll preset (code: `ult.gd`, a child node of the player).

| Class | Ultimate | How it works |
|---|---|---|
| Berserker | **Inferno Uppercut** | With a full meter, super armor's counter window doubles (1.5s -> 3s) and the HUD says "INFERNO READY" with the current ultimate key. Use it in that window: slow-mo, a flaming uppercut at x3 on top of the counter/retaliation damage, the enemy is launched (7 m/s up), stunned 1.6s and set on fire for 4s. Bosses and floating Wraiths aren't launched, just stunned. Using the ultimate without a super-armor counter window tells you to take a hit first. |
| Combo Master | **Temporal Break** | (Reworked 2026-10-29, see Patchwork.) Every enemy (and projectile) freezes and the world drains to cold grey. You move and punch freely: each punch lands on what you aim at (or the nearest frozen monster in reach), +2 combo, but its damage is held, a spark frozen where it hit. The other hand from your last punch (it glows) gives back 0.25s (each refund x0.8 of the last, about 1.25s at most, never past the starting time); the clock runs 12% faster per hit. One used within 30s of the last one's end lasts 25% less, stacking down to half. When time resumes, every monster takes its held damage at once, and everything that was frozen is stunned for 1s. |
| Counter Master | **Riposte Stance** | For 4s every attack is slipped automatically (counts as a clean dodge) and, if the attacker is within 3.2 m, answered with a counter hook ("RIPOSTE!"), which can trigger the Perfect Counter KO. Ranged attacks are just dodged. |
| Free Runner | **Highlight Reel** | Marks up to 5 enemies in front, within 14 m and in line of sight, nearest first. Streaks to each one with a lightning bolt left behind, punching each (x2.5, alternating jab/cross), and finishes with a leaping haymaker (x5) on the last. Invulnerable throughout. With nothing in view it doesn't fire or spend the meter. |

The tutorial ends with an 11th step: the meter starts full and the coach explains the class's ultimate.

**Slow motion, turned down (2026-10-14):** playtesters didn't like it.
- Dodges: 0.7x speed for 0.15s (was 0.25x for 0.35s).
- Clean dodges: 0.5x for 0.2s (was 0.15x for 0.5s).
- Counter finishers: 0.75x for 0.12s; clean / perfect finishers 0.45x for 0.25s (was 0.12x for a full second).
- Inferno Uppercut: 0.45x for 0.25s; The Long Count: 0.4x for 0.4s.
- Settings → Display → **Slow motion** scales all of these, and 0% turns it off. Hitstop freeze-frames and the slow-mo when your knuckles break at the end of a run aren't affected.

## Browser performance [Built, 2026-10-14]

**Ctrl in the browser (2026-11-04):** Ctrl is a game key (Ctrl + click uppercuts; some dodge schemes hold it), and in a browser Ctrl + S saved the page, Ctrl + D bookmarked it, Ctrl + A selected everything and Ctrl + W closed the tab. The web export's head include (`export_presets.cfg`, both web presets) now: stops the page default of Ctrl / Cmd + any key (the game still gets the key; Ctrl + Shift combos like the dev tools are left alone), asks "Leave site?" if the page starts closing while Ctrl is held (Ctrl + W can't be blocked in a window), locks the keyboard in fullscreen (Chrome and Edge then let the game keep Ctrl + W too) and drops the right-click menu over the game (Ctrl + click is a right click on a Mac). All of that stays; for anyone who would rather not hold Ctrl at all, the **Shift / Z + click** punch scheme (Settings, Controls, "Hooks and uppercuts") moves uppercuts to Z.

The web build is the only one released, and family testers found it laggy. On top of the earlier web profile (no glow, SSAO or shadows, fewer props, batched fences):
- **3D resolution** (Settings → Display → 3D resolution, default Auto):
  - The browser renders 3D at about 1280x720 worth of pixels, however big or high-DPI the window, and scales it up. Big laptop screens were rendering 2-4x the pixels.
  - It drops another 0.1 (down to 0.4x) whenever the frame rate stays under 26, and creeps back up when it recovers. A browser's 30 fps cap doesn't count as lag.
- **Light budget**: only the 6 scenery lights (torches, candles, glows) nearest the camera stay on in the browser, within 18m. Lights on characters are never touched. Crypt draw calls dropped from about 1,520 to 1,110.
- **Mesh batching** (`Look.batch_meshes`):
  - Identical static scenery pieces are merged into MultiMeshes, one per 16m area so culling and lights still work: Crypt decor, graveyard decorations and the camp backdrop.
  - In the Crypt about 535 meshes become 28 batches.
- The camp backdrop and fighter demo reel have no MSAA in the browser, and the camp backdrop redraws every other frame.
- Upgrade-web nodes redraw every third frame while idle in the browser, and links every other frame. Hovering, buying and bursts stay at full rate.
- **Bench:** open the web build with `?bench` in the URL (local server or a direct link, not the itch page). It runs a crowded night, the Crypt, camp, Dead League and the title, twice: optimizations off, then on. Each prints fps, worst frame, draw calls and resolution scale to the browser console, using its own save.

## Visual style [Built, 2026-10-11]

The whole game was given a visual pass. The web build runs on Godot's Compatibility renderer, so everything uses features that work there; SSAO is switched on too but only shows on desktop.
- **Materials** (`look.gd`): every block (`Enemy._material`) uses a pixel-grain texture mapped in world space (triplanar, nearest filtering), so surfaces read as textured voxels rather than flat plastic. The Crypt walls use a generated **brick** texture (offset 25 x 12.5 cm bricks, varied shades, moss, cracks, mortar), and its floors use **flagstones** (50 cm stones, cracks, joints).
- **Lighting**:
  - Torches, the campfire and lanterns are shadow-casting fire lights that fade (shadows first) with distance.
  - Every flame is a layered fire: a hot core, an outer flame and a tip, with embers and smoke rising.
  - The environment grade (`Look.tune_environment`) sets the filmic tonemap, a tuned glow, and a little contrast and saturation.
- **Post FX** (`post_fx.gd`, on every gameplay scene and the title): a soft vignette, animated film grain, slight colour fringing toward the corners, and a split tone (cool shadows, warm highlights). It draws under the HUD, so text stays crisp. It can be turned off in Settings, under **Film effects**.
- **Settings:** **Torch shadows** can also be turned off for slower machines.
- **Combat FX** (`hit_fx.gd`):
  - Every hit pops a flash of light at the impact; heavy hits and counters add an expanding ring.
  - Dead enemies crumple, then **shatter into cubes** in their own colours, and a ghostly wisp rises.
  - Damage numbers pop in big (bigger for big hits), settle, then drift up and fade.
- **Graveyard scenery** (`scenery.gd`):
  - Ground and sky: a starry night sky with the moon and its halo; 14,000 grass blades (one MultiMesh); dirt patches.
  - Graves: plots of gravestones in rows (six kinds: slab, cross, obelisk, broken, Celtic cross, tomb chest) plus lone graves.
  - Around the edges: blocky dead trees with roots and twigs, small family crypts, rocks, and an iron fence ringing the graveyard.
  - Atmosphere: drifting ground mist (it fades near the camera) and wisps.
- **Crypt dressing** (`dungeon.gd` `_decorate`):
  - Structure: a stone ledge along every wall, half-pillars set into the walls, and ceiling beams in rooms and corridors.
  - Wall dressing: tattered banners between pillars, cobwebs in the upper corners, and chains hanging from above.
  - Floor props: bone piles with skulls, candle clusters with a small light, rubble, and a lidded, banded coffin.
  - Dust drifts in the torchlight.
- **Voxel enemies** (`voxel.gd`, 2026-10-11): every enemy part (boxes, cylinders, spheres, capsules with a plain colour) is rebuilt as a mesh of small cubes (1.6-4 cm). Each cube gets a slightly different shade, edges and corners are darker, grime specks show here and there, the top is a touch lighter, and about 1 in 20 surface cubes is raised for a chunky outline. Only visible faces are built, and each shape and colour combination is made once and shared. The Graveyard and Crypt pre-build every enemy type while loading, so spawns cost about 1-10 ms. Glowing and see-through parts (eyes, staffs, wraith glow) stay as they were. Hit flashes, the elite glow, animation and the death shatter (which uses each part's original colour) all still work.
- **Font**: **Anton** (SIL Open Font License, `fonts/Anton-Regular.ttf` with `fonts/Anton-OFL.txt`, which is included in exports) is the display face for the logo, menu items, fighter names and taglines, ultimate names, announcements and the combo. Body text keeps the default font.
- **Menus**:
  - Theme (`ui_theme.gd`): translucent panels with drop shadows and faint gold edges, chunky buttons with a dark lip and a gold glow on hover, a glowing underline on the open tab, gold sliders, a heavy display face (Anton) for titles and names, and bold for buttons.
  - Camp (`camp_backdrop.gd`): a live 3D campfire scene behind the menus, with the fire, sparks, a tent, log seats, crates, a lantern, the training dummy, graves and trees in the mist, and the drifting camera. The upgrade and skill webs float over it.
  - Web nodes have a lit sheen and a lip. Owned nodes glow, buyable ones pulse green, and owned links glow with sparks flowing along them.
  - HUD: a beveled knuckle bar with segment ticks every 10 HP and a pale damage trail that drains after a hit, and the display face on announcements, the night title and the combo.

## Title screen & settings [Built, 2026-10-10]

The game opens on a **title screen** (`title.tscn`, `title.gd`), a 3D scene built in code. It shows a moonlit graveyard with:
- rows of tilted gravestones (slabs, crosses, obelisks, broken stones) and a dirt path lit by lanterns;
- a mausoleum with columns, a glowing purple door and torches;
- dead trees, an iron fence, drifting ground mist, floating wisps and circling bats;
- the dead shambling up the path (zombies, a skeleton, a Possessed Armor), plus a Wraith and a Hulk by the mausoleum.

The camera drifts slowly and follows the mouse a little. Lightning strikes every 7-15s with a double flicker, lighting the scene and the logo, followed by thunder.
- **Logo:** FRIGHT NIGHT drops in letter by letter with a bounce, then bobs; blood drips off the letters.
- **Menu:** PLAY (fade to camp; Enter also works), CLASS, SETTINGS, QUIT (not shown in the browser). The buttons slide in and nudge right on hover.
- **Footer:** the current class, its level and ultimate, plus Graveyard and Crypt progress.
- **First start:** the first time, PLAY opens the class picker ("CHOOSE YOUR FIRST FIGHTER", with a Continue button), then asks "Learn to fight the dead?" with **Play the tutorial (recommended)** or **Skip - straight to camp**. Either choice sets `onboarded` in the save; after that, PLAY goes straight to camp. Saves from before this existed count as already onboarded, and resetting the save starts it again.
- **Class picker:** four cards with icon, level, description, stat changes, and the ultimate with what it does. Click a card or CHOOSE. The camp no longer has a Class tab; its **Menu** button goes back to the title. The detail and the title footer name the **equipped** ultimate, not the default. The picker darkens the title behind it almost to black (the logo and menu showing through was clutter).

**Settings** (`settings.gd` autoload, saved to `user://settings.cfg`, separate from the save so a reset keeps them; window in `settings_panel.gd`, opened from the title and from the pause menu):

| Group | Settings |
|---|---|
| Sound | Master, Music, Effects, Ambience volume; Mute all |
| Controls | Mouse sensitivity (x0.25-3), Field of view (60-100) |
| Display | Screen shake (0-100%), Fullscreen |
| Save data | **Reset save**: two clicks, the first arms it for 4s. Erases all progress, including the tutorial. Not shown in the pause menu. Plus **Default settings**. |

Audio buses (Effects and Ambience) are created at startup; all sound effects play on Effects. Ambience is a synthesized looping night wind: louder on the title, quiet in the Graveyard, low and muffled in the Crypt, off in camp and training.

**Music (placeholder, 2026-10-16):** a looping track per place on the Music bus (default 60%), starting with the first click (browsers block audio before that) and crossfading over 1.4s as you move (`Sfx.play_music`). All synthesized by `audio_lab/make_tracks.py`, 16 bars each, mono 24 kHz:
- **title** (78 BPM, A minor): music box and choir over a slow heartbeat. Title screen.
- **camp** (72 BPM, E minor): lo-fi campfire, soft drums, warm keys, crackle. Camp and training.
- **arena** (140 BPM, D minor, 32 bars; rewritten 2026-10-17 to be much more upbeat): a spooky phonk fight anthem. Cowbell riff, hard sliding 808, four-on-the-floor kick with claps and rolling hats, a detuned saw hook in the second half, and two breakdowns with rising snare rolls into the drop. Underworld Arena (2 dB under the others, since it's denser).
- **crypt** (66 BPM, C# phrygian): a drone, tolling bells, sparse heavy drums. The Crypt.
- **league** (104 BPM, D minor): driving drums, choir stabs, big 808. Dead League menu and bouts.

To be replaced by real tracks.

**Sound Lab (dev tool, not shipped):** `audio_lab/Sound Lab.bat` opens `sound_lab.tscn`: the training ring with a panel (F1) to swap any game sound live and trim its volume, from the Kenney CC0 pack suggestions (`audio_lab/slots.json`) or any file dropped in `audio_lab/drop/`. Picks save to `audio_lab/picks.json`. `audio_lab/index.html` is the browser version of the same comparison. Excluded from the web export.

## Training dummy [Built]

A practice dummy with unlimited HP and selectable levels, for learning the systems. No coins or XP; knuckles refill instead of ending the session.

| Level | What it does |
|---|---|
| 1 | Slams only (back step) |
| 2 | Throws jab / cross / hook / uppercut, singly and in combos |
| 3 | Also slips your punches and counters — dodge the counter and counter back |
| 4 | Ring: level 2 punches, but it moves — closes in, backs off when crowded, circles you |

Each attack shows its color cue and a hint with the right key. Dodging a punch doesn't stop the dummy's combo — it throws the rest so you can practice chaining dodges, then is left open for your counter (a counter mid-combo staggers it and cuts the combo short). A back step that carries you out of reach still counts as a dodge.

**Telegraph levels** (Up / Down in training), independent of the dummy level:

| Telegraph | Key hint | Glove color | Windup |
|---|---|---|---|
| 1 Full | Yes | Yes | ×1.3 (slow) |
| 2 Color only | No | Yes | ×1.0 |
| 3 Pose only | No | No | ×1.0 |
| 4 Fight speed | No | No | ×0.75 | 

Reached from the **Training** button at camp (labelled **Tutorial** until the tutorial is finished); number keys 1–4 change the level. Training takes place inside an enclosed boxing ring.

### Tutorial [Built]

**Set-ups and combos (2026-10-16).** "Hook and Uppercut" became two steps:
- **SET IT UP:** explains the cost of each punch (jab and cross 1 knuckle HP, hook 2, uppercut 3) and that a hook or uppercut only hits hard straight after a jab or cross from the other hand. Thrown cold it's SLOPPY: weak and expensive. You land 3 set-up heavies on a still dummy, and each punch's cost floats off the knuckle bar.
- **COMBOS:** four drills shown as punch chips that light up in order: jab, cross, hook / cross, hook, cross / jab, jab, cross / jab, cross, hook, uppercut. Heavies must be set up and the combo has to stay alive; a wrong or sloppy punch shakes the chips and starts the drill over.


The first time a player opens Training it runs a guided tutorial; **T** skips it, or restarts it later from free practice. A coach panel down the left side shows the step, what to do, and progress toward its goals; a step completes when every goal is met, shows NICE! and moves on. If the player gets hit, the panel says what the attack was and which dodge answers it (e.g. "Hit by a left hook - next time: Ctrl+D roll right"). Finishing or skipping saves `tutorial_done`.
- **Coach card (2026-10-15):** the shared gold-edged card on the left shows "STEP 4 / 11", the move's name in the display face, one short line, the keys as keycap chips (filled with your control scheme, e.g. `Q / E` Slip), a swatch of the glove color the step teaches (blue straights, orange hooks, red uppercuts and slams), and goal pips that fill. Finishing a step flashes NICE!; getting hit shows a short "LEFT HOOK -> <your roll right>" in your own controls (bindings, scheme, keyboard or controller). T skips. Free practice shows a PRACTICE card with keycaps for the dummy level (1-4), telegraph (Up / Down) and the tutorial (T).

| # | Step | Goal | Dummy |
|---|---|---|---|
| 1 | Move | Move 6 m (WASD, mouse, Shift sprint) | Still |
| 2 | Jab and cross | 2 jabs, 2 crosses landed | Still |
| 3 | Hook and uppercut | 1 hook (Shift+click), 1 uppercut (Ctrl+click) | Still |
| 4 | Slip (blue) | 3 slips | Single jabs/crosses, full telegraph, extra slow |
| 5 | Counter | 3 counters with the glowing hand | Single jabs/crosses, slow |
| 6 | Roll (orange) | 3 rolls (Ctrl+A/D) | Single hooks, slow |
| 7 | Back step (red) | 3 back steps (Ctrl+S) | Uppercuts and slams, slow |
| 8 | Read the combo | 2 combos fully dodged + 2 counters | 2-hit combos, next glove lights up |
| 9 | Clean dodge | 2 clean dodges (dodge at the flash) | Mixed singles, color only |
| 10 | Fight speed | 6 dodges + 3 counters | Any combo, color only |
| 11 | Ultimate | Use the class ultimate once (meter starts full) | Single jabs/crosses, slow |

## Enemies [Built]

One telegraph color language everywhere: **blue = slip, orange = roll, red = back step**.

**Body language (2026-10-10).** Boxer-type enemies (brawler, runner, Champion, dummy, priest, armor) have **two-part arms with elbows** and a **torso that twists at the hips** (legs stay planted):
- Guard: elbows tucked, gloves up by the chin. Jab/cross load with the elbow bent and snap out straight. Hooks: elbow out wide and level, forearm bent ~90°, swinging across. Uppercuts: elbow drops, fist down by the waist, then drives up to head height. Slams: both arms overhead, elbows bent.
- Torso wind-up, about a third to half of the Possessed Armor's turn: jab ~8° shoulder load; cross pulls the rear shoulder back ~20° then rotates through; hooks coil ~25° toward the hook side with a small dip, then unwind; uppercuts drop ~10cm and lean to the punching side, then rise; haymakers coil ~35° leaning back; slams lean back, then crunch forward.
- Timing: the coil builds over the first 70% of the windup, then **holds still, fully loaded** — that's when the flash happens — then snaps through on the strike and settles.
- Zombies rear back harder into the slam and crash forward after it (arms stay straight — zombie style). Skeletons bend the drawing elbow, pulling the string back to the cheek.

| Enemy | First appears (old wave; now see the unlock table below) | Fights by | Answer | Base HP / armor (armored) | Coins / XP |
|---|---|---|---|---|---|
| Zombie | 1 | Walks in, raises arms (eyes flare red), slams | Back step | 20 / – (45 / 4) | 3 / 4 |
| Skeleton | 2 | Keeps 8–14m away, draws (string glows blue), shoots | Either slip | 14 / – (29 / 3) | 5 / 6 |
| Runner | 3 | Fast zombie: sprints at you, winds up a big looping haymaker (arm swung way back, fist glows orange) | Roll under it, either way — a dodged haymaker leaves it open 1s | 18 / – (33 / 3) | 5 / 6 |
| Ghoul Brawler | 4 | Boxes like the training dummy: footwork, jab/cross/hook/uppercut combos, gloves glow in the defense color | Read the gloves | 40 / – (70 / 4) | 8 / 10 |
| Hulk | 3 | Big slow zombie. Doesn't swing at you: raises both fists overhead and smashes the ground in front of it. A red ring on the ground shows the 5m blast radius (pulses faster, flashes bright right before it lands). Left open 1.4s after every smash | Jump it, or sprint out of the ring. Heavy punches stagger it out of the smash | 60 / – (100 / 5) | 10 / 12 |
| Fire Mage | 4 | Skeleton-style ranged AI (keeps 7–15m away). Stops, raises its hands, a fireball grows between them, flashes, is thrown. Fireballs are slow (11 m/s) and fly at where you were | Keep moving sideways so it misses, or slip it (either side) | 16 / – (31 / 3) | 7 / 8 |
| Grave Priest | 5 | Healer with a staff. While any other enemy is alive it runs from you (if within 9m) and hangs back behind its allies; every 4s it raises its staff (green crystal glows) and heals enemies within 8m for 20% of their max HP. Any stagger interrupts the heal. Once it's the last enemy left, it fights: staff swing at head height | Chase it down early, or interrupt with heavy punches. Alone: roll under the staff | 22 / – (37 / 3) | 8 / 9 |
| Possessed Armor | 6 | Empty plate armor with a cursed sword. Hits hard (11), **8 armor always** (12 armored). Thrusts (the whole suit turns side-on, sword arm drawn away from you, flashes blue, then twists back square as the blade drives in) and wide horizontal slashes (wound far back, flashes orange), sometimes back to back. The open joints at its sides glow purple | Slip the thrust, roll the slash. **Hooks hit its weak spots: ×2 damage that ignores armor** ("WEAK SPOT!") — so a slipped thrust → hook counter is the big payoff | 45 / 8 (70 / 12) | 12 / 14 |
| **The Grave Champion** (boss) | 10 | 1.5× size, armored, long combos and slams. Below 50% HP: enrages (windups ×0.8, faster) and raises 3 zombies | Everything | 500 / 6 | 150 / 120 |

- Armored enemies (helmet + chestplate) get more common as the night bar fills (see below), max 60%. Double coins, +50% XP.
- The boss has a health bar at the top of the screen. A Counter Master's perfect counter takes 25% of its max HP instead of KO'ing it.
- [Proposed] Later: enemies that combo and feint, more bosses per night tier.

(The Runner replaced an earlier Crawler — a low, four-legged enemy that was too hard to hit.)

## Nights & the progress bar [Built]

(Replaced numbered waves on 2026-10-10.)

- **Night 1 is the first chapter and is gentler** (2026-10-10): 30 kills instead of 50; enemies at x0.6 HP and x0.6 damage; 2-5 on the field instead of 3-8; spawns 40% slower; no armored enemies and only zombies, skeletons, runners, hulks and ghoul brawlers; punches cost half the knuckle HP; every kill heals 2 knuckle HP and every tenth of the bar heals 8% of max; when the Champion rises the remaining dead crumble, and he comes with one skeleton, no armor, x0.3 HP, x0.7 damage and no summons. Night bot (fresh level-1 build, reading 60% of tells): Counter Master, Combo Master and Free Runner all cleared it, finishing with 14-33 knuckle HP. Berserker cleared it with an earlier version of these rules. Before the boss changes it died to the armored Champion every time: a fresh fighter's 1.7 damage does nothing through 6 armor.
- A run starts at your next unbeaten **Night**. Enemies keep coming out of the fog; every kill fills the **night progress bar** (50 kills). When it's full, **the Grave Champion rises** (14m in front of you, with a skeleton and a mage). Regular spawns stop; escort and summoned kills don't count.
- **Enemies scale with the bar, locked in at spawn**: an enemy is as strong as the bar was full when it appeared — it never changes while alive. From empty to full: +160% HP, +96% damage, +24% speed, +120% rewards (the same range waves 1–9 used to cover). The bar's label shows the current multiplier ("new enemies x1.99").
- **Spawning**: on the field at once grows 3 → 8; a spawn every 2.2s → 1.0s as the bar fills. Armored chance (progress − 10%) × 0.8, max 60%.
- **New enemy types unlock along the bar**, and the first of each is sent right away (with a "joins the night" feed message):

| Enemy | Unlocks at | Weight | Max alive (after 75%) |
|---|---|---|---|
| Zombie | start | 3.0 | – |
| Skeleton | 4% | 1.2 | 2 (3) |
| Runner | 12% | 1.4 | 3 (4) |
| Hulk | 20% | 0.6 | 1 (2) |
| Ghoul Brawler | 28% | 1.0 | 2 (3) |
| Fire Mage | 36% | 0.8 | 1 (2) |
| Grave Priest | 45% | 0.6 | 1 |
| Possessed Armor | 55% | 0.7 | 1 (2) |

- **Milestones** every 10% of the bar (9 per night): +5 × milestone coins (× Bounty), and the "as the night wears on" heals (Ice Bath, Cornerman, Second Wind — the old between-wave heals).
- **Boss down → dawn breaks**: every other enemy crumbles (their rewards still count), +100 coins × night number (and a Champion Sigil the first time). The game pauses and you choose:
  - **Continue to the next Night** in the same run — harder and richer (enemies +75% HP, +50% damage, +75% rewards per night). It starts fresh like a new run: full knuckle HP, class specials ready, the bar empty again.
  - **Return to camp** to spend what you earned. Your next run starts at the next unbeaten night.
- The run summary shows how far through the night you got (or that you reached the Champion).

### Balance target: upgrades are required

Rough punches-to-kill for a Berserker (average landed punch ≈ 2× base damage). Every punch costs knuckle HP, so a fresh character can't win.

| Build | Wave 5 zombie | Wave 6 armored brawler | Wave 9 armored brawler | Boss |
|---|---|---|---|---|
| Fresh (Lv 1, no upgrades) | 7 | 117 | 152 | blocked by armor (only big counters/heavies get through) |
| Mid (Lv 6, 8 dmg points, Wraps + Iron Fists I + Armor Breaker I) | 1 | 4 | 5 | 13 |
| Strong (Lv 10, + Iron Fists II, Armor Breaker II) | 1 | 2 | 3 | 7 |

Expected: a fresh character dies around waves 4–6; a few runs of coins and levels get to a mid build that can clear Night 1. Night 2+ then needs more.

## The Crypt: roguelite mode [Built — first slice, 2026-10-10]

**Unlocking (reworked 2026-10-16):** the Crypt opens with **the Bellman's seal**. His first defeat lists THE CRYPT in SEAL BROKEN with the ring, power and Trophy. Back at camp, the menus fall away and the camera turns to the graveyard past the fence. The ground shakes, a stone crypt pushes up out of the earth (`crypt_door.gd`), its iron gate lifts and a purple beam lights the fog. Then "THE CRYPT HAS OPENED / The Bellman's last toll cracked the graveyard open. What you find down there, you keep." The menus return with the Crypt button wearing a pulsing NEW badge until your first descent, and the crypt stays standing behind camp from then on. It plays once (`crypt_reveal_pending`). Saves that beat the Bellman without finding the old Arena crypt get it on load, reveal included. Saves that found it the old way keep it. The old mid-bout version (kill-feed hint, a crypt rising at 30% of the bar, F to pry the gate) is gone. The bout-end screen still offers "Descend into the Crypt" once it's open.
- **The Bellman is tuned for a fighter with no gear** (`Progression._par_gear(1)` is empty), since gear only comes from the Crypt. That's about 16% less health and damage than before, and a gearless fighter at par rates 0.94-1.01 of him.

A second kind of run, chosen at camp (**Graveyard** or **Crypt**). The Crypt is a dungeon beneath the graveyard, generated fresh every floor.

- **Layout:** a random-walk main path of 6 rooms from the entrance to the boss room (rooms on the path never touch each other), plus 2 **chest rooms** hanging off it. Rooms are 16m squares (boss room 22m, with pillars) joined by 4m-wide torch-lit corridors. Stone walls, ceilings, bones and coffins.
- **Fight rooms:** walking in **seals the doors** (iron bars slam down with a red glow) until everything inside is dead. Enemies rise from the floor inside the room: 3 + room depth (+2 per floor deeper, max 11), at most 3–5 alive at once. Enemy types and strength come from the room's place in the run (the graveyard's unlock table); floor 1's first room is zombies and skeletons, its last can have armor and priests. Clearing a room: +10 coins × floor, the "as the night wears on" heals, and a 25% chance a chest rises.
- **Boss room:** the Grave Champion + a skeleton and a mage. When he falls, the rest crumble, the doors open, and a **boss chest (always rare or better)** and the **stairs down** appear. First clear of each floor: a Champion Sigil, +100 coins × floor.
- **Stairs:** descend to the next floor (new layout, tougher enemies, better loot; you keep your items and knuckles refill) or return to camp.
- Death ends the run: coins and XP are kept, **items are lost**.

### Crypt roadmap [Planned, 2026-10-10]
1. **Readable, varied floors [Built 2026-10-10]:**
   - **Minimap** (top right): rooms appear once visited (bright) or next to a visited room (dim outline); icons for chest rooms, unopened chests, the elite room (orange diamond), the boss (red ring) and the stairs; your arrow. **Tab** toggles a full-floor map. Worn items moved below it.
   - **Room sizes**: fight rooms are small 12m, medium 16m, large 20m, or a **long hall** 24×12m when its doors line up. Start 14m, chest rooms 12m, boss 22m.
   - **Interior layouts** (solid stone, full height — they block line of sight, arrows and fireballs): small = open/pillars; medium = open/pillars/cross/ring/corner; large = pillars/cross/ring/corner; halls = open/two pillar rows. Cross = corners filled (a plus shape with 8m arms to every door); ring = a center block 30% of the room; corner = one big corner block. Spawns, chests and torches avoid the blocks.
   - **Enemy steering**: walking into a wall or block makes an enemy step around it, sticking to one side until that's blocked too (a brawler gets around a ring room's center block in ~4s).
   - **Elite room** (one per floor, depth 2+, not small): an elite melee enemy first (smaller escort), with an orange aura, ×2 HP, ×3 rewards and a trait — **Swift** (+35% speed, windups ×0.85), **Brutal** (×1.5 damage), **Ironclad** (+5 armor and 35% less damage after armor, so it stays tough late), **Hulking** (bigger, ×1.5 more HP). Its chest is uncommon or better. The room has an orange glow.
2. **Items that change how you fight [Built 2026-10-10]:**
   - **Clean dodge** (base mechanic, everyone): a dodge whose attack lands within **0.12s of the key press** (pressing late, right before impact — later than the flash) is CLEAN: gold flash and "CLEAN SLIP!" callout, bigger slow-mo, and the counter does **+25%** ("CLEAN COUNTER!").
   - **Specials** (gold on item cards): Uncommon 15%, Rare 40%, Epic always. By slot —
     - Gloves: **Shatter** (counters burst 50% damage within 2.5m), **Venom** (jabs poison: 0.25× base dmg/s per stack, max 5, 4s), **Serrated** (hooks bleed: each attack a bleeding enemy throws costs it 1× base dmg per stack, max 5, 6s), **Lunging Jab** (dash into a jab: +60%).
     - Wraps: **Thorns** (attackers take 100% of the knuckle damage they dealt), **Iron Will** (first hit in each room blocked), **Grit** (below 30% knuckles, take 30% less).
     - Boots: **Frost Slip** (30% chance a slip/roll chills enemies within 3.5m: −40% pace for 2s), **Spear Jab** (dash into a jab spears every enemy in a 4m line), **Clean Read** (clean dodges heal 4).
     - Charm: **Rhythm** (each dodge +0.15 combo multiplier, up to +1, lost on a clean hit), **Executioner** (counters finish non-boss enemies under 25% HP).
   - **Risk specials** (6% on any item, any rarity): **Glass Jaw** (+50% damage, +30% damage taken), **Last Stand** (up to +60% damage as knuckles fall), **Blood Price** (+40% damage, punches cost +1 knuckle). Cursed chests (phase 4) will hold more dramatic versions.
   - **Legendaries** (orange; boss chests 15%, elite chests 5%, floor 2+; two rolled stats at ×1.6 + a signature): **Bone Breaker** (every 5th hook ignores all armor and damage reduction, and staggers), **The Long Count** (once per floor, survive a knockout at 1 HP and stun everything for 3s), **Champion's Hands** (counters throw a free follow-up punch), **Slipknot Wraps** (+50% dodge windows; 3 dodges in a row heal 8), **Gravewalker Boots** (after a dodge, the next attack within 1.5s hits your ghost), **Lantern of the Dead** (elites and bosses drop an extra chest). Salvage 120.
   - **Item cards** compare against what's worn: green = better, red = worse, gold = special, and "Lose: …" for effects you'd give up.
   - Cut from the proposal: Ember Dash, Recoil, Metronome. Frost Slip became a chance; Thorns became 100% reflect; bleed triggers on the enemy's attacks.
3. **Crypt enemies & bosses [Built 2026-10-10]:**
   - **Mimic**: 25% of chests in chest rooms, 15% of dropped chests (never boss/elite/cursed). Its lid twitches now and then; walk within 2.6m and it stands up on bony legs (tall enough to punch), the room seals. It scuttles in and **bites** (lid yawns, red flash → **back step**); a missed bite leaves it open. 60 HP. Dies → a real chest (uncommon+), +5 silver.
   - **Shieldbearer** (unlocks 20%): skeleton with a tower shield on its left arm. The shield **stops jabs, crosses and uppercuts** ("SHIELD", still costs knuckles, breaks the combo); **hooks go around it; counters always get through**; staggered, it drops its guard. Attacks: **shield bash** (blue → slip either side) and an overhead chop (slam → back step). 50 HP.
   - **Wraith** (unlocks 35%): floats, no gravity, **passes through walls**. Punches go straight through it ("PHASED", free, like a whiff) except **for 1.4s after it attacks** (it turns nearly solid) or with a **counter**. Attack: **claw** (orange → roll). 34 HP.
   - **Bone Lich** (unlocks 65%, max 1): robed caster, keeps 6–13m away, raises its staff and throws a **fan of 3 purple bolts** (slip, or step out of the fan); every 10s **raises two skeletons** (capped). 70 HP.
   - **Floor bosses**: 1 Grave Champion · 2 **Bone Colossus** · 3 **Lich King** · 4 Grave Champion · **5 Lich King (finale)**; then Champion → Colossus → Lich King, stronger each floor.
     - **Bone Colossus** (650 HP, armor 6): 2.2× giant skeleton. **Slams** (back step) and huge **sweeps** (roll). Its head is out of reach; the **glowing core in its ribcage takes ×2 damage through armor** — aim up. Enrages below 50% (faster, longer combos). Escorts: two Shieldbearers.
     - **Lich King** (600 HP): 1.6× lich with a bone crown. **5-bolt fans**, raises a Shieldbearer + skeleton every 12s, and **blinks away** across the room if crowded for 1.2s (7s cooldown). Below 50%: faster casts, 7-bolt fans, raises three at once.
4. **Run structure [Built 2026-10-10]:**
   - **Silver** (renamed from "bones"): a run-only currency. 1 per kill, 5 per elite or mimic, 15 per boss. Shown on the info line.
   - **Merchant room** (every floor): a hooded ghoul with three wares on stands (uncommon+, 4% legendary from floor 2) — **12 / 25 / 45 / 90 silver** by rarity (cursed 40) — and a **healer's kit** (+40% knuckle HP for 15 silver, once).
   - **Shrine room** (60% of floors): pray to trade **25% of your max knuckle HP** (from current HP) for a **blessing** that lasts the run and takes no slot: Might (+20% damage), Stone (+20% knuckle HP, +2 defense), the Slip (+15% dodge windows, +0.3 counter), Plenty (+30% coins, +20% XP), Fury (combo step, punch speed) — or 40% of the time any item special (e.g. "Blessing: Shattering").
   - **Cursed chests** (15% of ordinary chests): bound in glowing purple chains. A cursed item has three strong stats plus a turned-up risk: **Glass Jaw** (+100% damage, +60% damage taken), **Last Stand** (up to +120% damage, −25% max knuckle HP), **Blood Price** (+80% damage, punches cost +2 knuckle HP).
   - **Winning**: beating **floor 5's boss clears the Crypt** — first time: +300 coins, +2 Champion Sigils. Then "Go deeper (endless)" or leave. The info line shows "Floor 3 / 5", then "Floor 6 (endless)".
   - Minimap icons for wares, the healer and shrines.
   - **Balance bot** (headless autoplay, ~20× real time; reacts to 85% of tells, counters, throws combos, opens chests, takes stairs; logs every room). First pass (2026-10-10) and the tuning it led to:
     - Level-7 Counter Master (≈12 damage, 110 knuckles): floor 1 always cleared; floor 2 too steep (died on floor 2 in 2 of 3 runs). → Floors ramp gentler (progress step per floor 0.25 → 0.15, +1 enemy per room per floor instead of +2, floor HP growth 0.4 → 0.3), **clearing a fight room heals 10% max knuckles**, and floor 1's entrance has a **starter chest** (uncommon+, never a mimic or cursed). (Removed 2026-10-25: the entrance room has no chests.) After: floors 1–2 cleared every run, runs end around the floor 3 Lich King.
     - Fresh level 1 (1.7 damage, 45 knuckles): dies in room 1–2 either way — **open question:** fresh characters are very weak since the upgrade rebalance (each punch costs 1 knuckle HP and a zombie takes ~10 of them).
     - Bugs it caught (fixed): salvaging a cursed item crashed; a lich could raise a skeleton outside the walls (it fell forever and the room could never be cleared — enemies under the floor are now put back in the room); arrows fired straight up/down errored.
- Rejected: rat swarms, and anything that needs punching the floor or ground slams to answer.

### Equipment [Built]
- Four slots: **Gloves** (damage, set-up bonus, armor pierce, head shots, counters, punch speed, boss/finisher damage; power: **Fire Fists**), **Wraps** (max knuckle HP, defense, heal on kill, free punches, graze/flinch reduction; power: +% max knuckle HP), **Boots** (move/sprint speed, dodge windows, jump, counter time; power: **Ground Pound**), **Charm** (coins, XP, combo step/time, finisher damage; power: **Chain Lightning**).
- Rarity: Common (1 effect), Uncommon (2, ×1.15), Rare (3, ×1.3, 35% chance one is a power), Epic (3 incl. a power, ×1.5). Floor 1 odds ≈ 55/30/12/3%, shifting toward rare each floor. Values grow +30% per floor and roll ±15%.
- Items use the same effect names as upgrades and skills, so they stack with everything (and can give powers without sigils).
- Opening a chest pauses and shows the new item next to what's worn in that slot: **Equip/Swap** (the old one is lost) or **Salvage** for coins (8 / 15 / 30 / 60 by rarity, more on deeper floors). Worn items are listed at the top right.
- F is the use key (chests, stairs).

### Rebalance (2026-10-10)
Permanent power was too strong for found items to matter (the maxed coin web gave +39 damage on a base of 2, +270 knuckle HP on a base of 50, and enough defense to quarter every hit). Now:
- Coin upgrade **raw power cut**: damage ×0.35, max knuckles ×0.4, defense ×0.4, heal on kill/heals ×0.5, armor pierce ×0.5, heavy bonus ×0.6 (rounded, per level). Powers, utility and costs unchanged. Class skill webs (XP) unchanged.
- **Flatter enemy scaling**: the night bar now goes +100% HP / +60% damage (was +160% / +96%); each night +40% HP, +30% damage, +50% rewards (was +75 / +50 / +75). The Crypt uses the same ranges per floor.
- These are first-pass numbers; the idea is camp upgrades make you a bit stronger every run, and the big spikes come from what you find.

### Progression and crowd rebalance (2026-10-11)

The first floor-5 Crypt clear was still far too generous: it bought essentially the entire coin web, granted 10+ fighter levels, and Chain Lightning turned an endless jab/cross string into a room clear. At the same time, a wall of melee enemies made the defense system unreadable. The follow-up pass changes all four pressure points:

- **Economy:** the coin web now costs **43,350 coins** to max, about **2.5x** the previous roughly 17,000. Crypt kill rewards and XP are multiplied by **0.6**, reward scaling per room/floor is flatter, room-clear rewards are **8 × floor**, floor-clear rewards are **60 × floor**, and the first floor-5 victory bonus is 300. A 2,000-run reward simulation using the live encounter tables puts the required-room floor-5 clear around **4,414 coins / 2,787 XP** before optional summons, mimics, salvage or player reward bonuses—about 10% of the full coin web rather than enough to finish it.
- **Combo variety:** replaced on 2026-11-02 by the grow / hold / lose rules ("Combo rules" in the Controls patch section). The old 4-straight limit is gone.
- **Chain Lightning:** it only triggers on a hit that actually grew the combo. Its damage starts at 40% of the triggering hit, falls to 75% on each successive jump, and receives only half of the triggering punch's combo bonus. This removes the high-combo room-deletion loop while keeping Storm useful against groups.
- **Melee turns:** ordinary melee enemies form a loose ring about 3.8m away. One attacks at a time through Graveyard Night 3 and Crypt Floor 2; two may attack from Night 4 / Floor 3 onward. An attacker gives up its slot after its combo and rests before rotating back in. Ranged enemies and bosses keep acting independently, and punching a waiting enemy pulls it into the active fight.
- **More sigil sinks:** each elemental branch ends in a second-sigil capstone (Pyre, Thunderhead, Shatter, Bloodbath). Each fighter's skill web also offers two center-adjacent sigil purchases: **Ultimate Surge** (+25% meter gain) and a class-specific **Ultimate II** upgrade.

## Progression v2: The Climb [Built 2026-10-14]

Goal: the game should feel like you get **way stronger to face way stronger enemies**, with the three modes feeding one climb. Tone: pulpy horror-comedy.

**This replaces two earlier rules:**
- Dead League is no longer upgrade-free. Bouts use your full build (upgrades, skills, kept gear), and each contender is tuned to its tier.
- Champion Sigils go away as a currency. Dead League wins break seals instead, and night and Crypt bosses drop Souls.

### Five tiers, one per Dead League contender
Each tier is the same climb: **earn** in the Underworld Arena, **loot** in the Crypt and keep what you can, **build** up to about 85% of the unsealed upgrades, then **break the seal** by beating the contender. Each seal opens the next ring of upgrades, a power and a tougher, better-paying Arena division.

| Tier | Contender | Arena division | Crypt floors | Seal broken on win |
|---|---|---|---|---|
| 1 | The Bellman | Gravedigger | 1–2 | Upgrade ring 2 + Fire |
| 2 | The Headless | Bone | 3–4 | Ring 3 + Frost |
| 3 | Sister Southpaw | Ghost | 5–6 | Ring 4 + Storm |
| 4 | The Plague Doctor | Plague | 7–8 | Ring 5 + Blood |
| 5 | The Coffin King | Crown | 9–10 | Capstones, the ending, endless mode |

### Underworld Arena (replaces Graveyard nights)
- The camp's **Arena** button opens a division picker. A division opens once the previous contender is beaten.
- Each **bout** is the old night: kills fill the bar, then the Grave Champion rises.
  - Bouts climb from the last contender's par toward this division's: bout 1 at 0% of the way, bout 2 at 33%, bout 3 and on at 67%. You farm below par and face the contender at it.
  - Runs pick up at your next unbeaten bout.
  - Division 1 bout 1 keeps the gentle first-night rules.
- **Performance pay:** the winning purse is 180 coins x the tier's pay x a **style grade**.
  - Style score = 600 + 20 per clean dodge + 12 per counter + 50 per punch type landed, minus 30 per hit taken and 10 per graze.
  - Grades: S+ (1300+) x2.6, S x2.2, A x1.7, B x1.3, C x1.0, D x0.8.
  - Kills and milestone coins also scale with the tier's pay.
- The Grave Champion drops **Souls**.
- A ringside **announcer** calls each bout with a pulpy one-liner in the feed.
- One melee attacker at a time in divisions 1-2, two from division 3.

### Crypt gear you can keep (the Enchanted Cave idea)
- **Ten floors**, two per tier, then endless. The camp's **Crypt** button picks a starting pair (floors 1-2, 3-4 and so on); a pair opens once its tier is reached. *(2026-11-03: now a pair opens when its contender is beaten: the Bellman opens floors 1-2, the Headless 3-4 ... the Coffin King 9-10; beating floor 10 opens the endless floors. See "Boss pacing and the power shift".)*
- Enemies climb to 40% of the way to the tier's contender on the pair's first floor and 80% on the second.
- **Souls show on the Crypt HUD** (top right, beside silver) and count up as bosses drop them, since the altars spend them.
- **Your worn gear comes in with you.** Anything found this run is **bound** to the Crypt.
- **Gilding altar:** in every floor's first room. Gilding a find costs silver by rarity (2026-11-04: the Souls cost is gone):
  - Silver: 10, 15, 25, 40, 60 and 40.
  - A gilded item shows [GILDED] in gold.
- **Leaving:** the stairs offer "Descend" or "Leave the Crypt (keep gilded finds)".
  - Leaving keeps your gilded finds plus what you came in with. Ungilded finds are lost, and their slot goes back to what you brought.
  - **A knockout, or abandoning the run, leaves you with only what you came in with**, gilded finds included.
- Kept gear goes to the **Armory**, a camp page:
  - Wear or take off items; worn gear counts in every mode, Dead League included.
  - **Reforge** for Souls: x1.25 to the item's numbers and +2 floors. Costs 3 + 2 per earlier reforge + half the item's floor.
  - **Salvage** for coins.
- Swapping out a kept item in the Crypt sends it back to the Armory; swapping out an ungilded find loses it.

### What bosses drop instead of sigils: Souls
- Grave Champions and Crypt floor bosses drop **Souls**: 1 + the tier, plus 3 on a first clear. A first full Crypt clear (floor 10) pays +10.
- Spent on gilding finds, reforging kept gear and **rerolling a stat** (Armory: pick one regular stat and it becomes a different stat for that slot at the same relative strength; powers and specials can't be rerolled; costs 2 + 1 per earlier reroll on that item + floor/3 Souls).
- Old Champion Sigils became 3 Souls each.

### Seals: Dead League wins open the upgrade web
- Every upgrade has a **ring** (1-6). Ring 1 is open from the start; each contender beaten opens the next.
- A sealed node shows purple with a lock, reads "SEALED - beat THE BELLMAN", and can't be bought.

| Ring | Opens after | Contents | Cost |
|---|---|---|---|
| 1 | start | the basics around the center | ~4.5k |
| 2 | The Bellman | Heavy Hitter, Iron Will, Pickpocket, Rhythm, Thick Skin + **Fire** + Trophy **The Bellman's Bell** | ~13k |
| 3 | The Headless | Champion's Belt, Armor Breaker, Guard, Quick Wraps... + **Frost** + Trophy **Headless Helm** | ~22k |
| 4 | Sister Southpaw | Bone Plating, Giant Killer, Night Owl... + **Storm** + Trophy **Southpaw's Veil** | ~33k |
| 5 | The Plague Doctor | Dawn Patrol + **Blood** + Trophy **Plague Censer** | ~51k |
| 6 (Crown) | The Coffin King | the four capstones + Trophy **The Coffin Crown** (5 levels), for endless mode | ~107k |

- **Trophies** are big raw-power nodes (damage, knuckle HP, defense), so every seal makes you feel way stronger.
- Prices are scaled by ring (x1, 1.25, 1.6, 3, 7, 15).
- **Fighter skill webs:** Ultimate Surge opens with ring 3 (after the Headless) and the class's Ultimate II with ring 5 (after the Plague Doctor).
- **Stat points** are now worth less: Damage +0.5 per point (was +1), Durability +6 knuckle HP (was +10). This keeps levels from outweighing upgrades.
- Upgrade web version 4: older saves are respecced. Coins come back at pre-ring prices, sigils become Souls, and camp explains it once.

### Contenders scale to a par build
- `Progression.par(tier)` is the build expected when facing contender t:
  - the cheapest 85% of the upgrade levels in the open rings;
  - the fighter level for that tier (9, 14, 19, 24, 29), with stat points split evenly;
  - decent rare-ish gloves and wraps from the tier's deepest floor.
- Par per tier:

| Tier | Damage | Effective knuckle HP |
|---|---|---|
| 0 (fresh) | 2 | 50 |
| 1 | 15.9 | 367 |
| 2 | 21 | 665 |
| 3 | 30 | 1,215 |
| 4 | 42 | 1,969 |
| 5 | 51 | 2,713 |

- **Contender HP** = their base HP x par damage / 2. **Contender damage** = their base damage x par effective HP / 50. Their bases were tuned for a fresh fighter, so at par the bout feels like that original fair fight.
- **Everything else on the climb scales the same way** (`Progression.enemy_scaling(x)`): enemy HP with par damage, enemy damage with par knuckle HP, interpolated by position on the climb (Arena bout, Crypt floor). You get way stronger, and so do they.
- **Under par is clearly harder:** at 60% of tier 3's upgrades you have about 77% of par damage and 75% of par knuckle HP.
- **Pay** by tier: x1, 2.85, 4.9, 7.3, 11.2, then x1.35 more per tier beyond.
- `balance_regression` checks that every tier's ring takes about 5 good bouts to reach par (it's ~5.3 each), that par grows every tier, and that a 60% build is clearly weaker.
- **Dead League:** the fight card shows how much of the contender's open web you own against the ~85% they're tuned for, and the bout uses your real build (`dead_league_active` no longer zeroes anything).
- **Winning:** a first win shows "SEAL BROKEN" with what opened (ring, power, Trophy, the next Arena division and Crypt floors).

### Story (pulpy horror-comedy)
- Each contender taunts you before every round, in the feed. The Headless just points.
- Each has a line when they go down, on the victory screen.
- The Coffin King's ending: "Your soul is your own again..." The Crown Ring opens, and the Arena and Crypt go endless.

### Code
- `progression.gd`: tiers, seals, par build, scaling, pay, Souls.
- `game_state.gd`: rings, Souls, armory, loadout, gilding, reforging, migration.
- `world.gd`: the Arena.
- `dungeon.gd`: tiers, altar, leaving.
- `dead_league_*.gd`: scaling, seals, taunts.
- `camp.gd`: pickers, Armory page, tier banner.

## Launch polish: show, don't tell [Built 2026-10-14]

The game should feel like a finished release, not a build in progress: no formulas, multipliers, tier numbers or rule paragraphs on screen. Things are shown (bars, pips, colors, medals, card art) and the design lives here, not in the UI.

### Endings play out
- **Knockout (first person):** the view sags woozily, then tips over sideways and drops to the floor with a thud; your arms fall out of view. The screen goes slightly red as you go down, then fades to black (2.6s, `Player.knock_out()` + `Hud.knockout_fade()`). Enemies keep moving around you. Then the results.
- **Win:** the ring bell rings ("bell" sound), K.O.! pops, and you keep control for ~2.6–2.8s (invulnerable, `Player.invulnerable`) while the rest of the dead crumble. In the Dead League the contender's last words show as a speech line. Then the results.
- Abandoning a run from the pause menu goes straight to the results.

### Results cards (`Hud.show_results`)
Big title (gold for wins, red for knockouts), one short subtitle, a grade that stamps down, four medals that light up (CLEAN xN, COUNTERS xN, FULL ARSENAL, UNTOUCHED), rewards that count up as icon chips (this bout's coins / XP / Souls), and at most a short gold note (e.g. "SEAL BROKEN / RING 2 · FIRE · THE BELLMAN'S BELL / NEXT: THE HEADLESS", "1 FIND CRUMBLED TO DUST", "LEAVE NOW: KEEP 2 GILDED · LOSE 1").

### The fight HUD (revised: the first pass was too bare)
- No controls bar: controls are a **CONTROLS tab in the pause menu** (`Controls.rows()`).
- **One top row** (`Hud.TOP_ROW`): knuckle bar on the left (HP centered in it, "55 / 69"), the bout bar ("12 / 30" kills) or boss bar (name) in the center, coins on the right, all the same height with gaps between them. The info line ("GRAVEDIGGER DIVISION · BOUT 3", "FLOOR 1", "ROUND 2") sits under the center bar, or in the row when there's no bar.
- Under the knuckles: "LV 3" and a thin XP bar. No class status line: mid-fight, class moments pop as callouts.
- **Passive chip** (bottom left, 2026-10-26): the equipped passive's icon and name, plus its live readout when it has one (Perfect Counter / Phantom Step / Fuggedaboudit cooldown or READY, Berserker +%, Dodge Chain xN, Momentum x1.2, Shockwave in N hits, Vinnie's timer, The Take +%, Grudge MARKED). READY turns it gold with a small pop.
- **Ultimate gauge** (`UltGauge`): a slanted 10-segment meter in the fighter's color with a flowing shine, the ultimate's name over it and a diamond badge with the percent. It bumps as it charges; full, it turns gold, throbs, sparks, reads "READY" and the badge shows the key.
- No worn-gear list in the fight and no kill-reward feed (the coin chip counts up). Combo reads "12 HITS  x2.25"; counters read "< COUNTER" / "COUNTER >".
- Boss taunts and the Arena announcer are a speech line across the top (`Hud.say`), not feed text. LEVEL UP! is a callout.
- Everything but the results card hides while it's up.

### Title screen (rebuilt 2026-10-14)
The Dead League's ring at midnight, in the game's blocky look (same `Scenery` pieces as the arena): a low camera just outside the ropes looks up at **the next contender** (the Coffin King once you hold the crown) standing in guard under a spotlight. The dead stand still in the fog beyond the iron fence, watching. Braziers burn at the ring's corners, the mausoleum door glows behind, the moon sits behind the logo, with mist, wisps, circling bats and a lightning strike every 9-18s. Nobody walks in or out: the dead shuffle side to side on the spot with a walking hop, each to its own beat, and the contender runs a random boxer routine (`_drive_contender`): single hops, quick double hops, breathers in its guard, and now and then one or two punches thrown at nothing, never two flurries in a row (their AI is off; the title drives the motion). The camera only drifts slightly and follows the mouse a little.

### Loading screen (`loading.gd`, autoload "Loading")
Every scene change goes through `Loading.go(path)` (rematches through `Loading.reload()`), so there's never a grey frame (the default clear color is near-black too). Each load picks someone at random (2026-10-15): any of the first four Dead League contenders, the Coffin King once he's been reached, and every fighter (Tony once unlocked), never the same one twice in a row. Heading into a Dead League bout always shows that bout's contender. The portrait on the right with a two-layer aura breathing behind it in their color, embers rising, and a slow push-in; on the left THE DEAD LEAGUE (or the fighter's class), the name in their color, the tagline and a line: a contender's taunt (the Headless's stage directions show without quotes), a fighter's catchphrase, or one of Tony's insults (tame or censored by mode); LOADING with a sweeping bar bottom left. It stays up at least 2s so the art can show off and the tagline can be read, loads on a thread where the platform allows, and fades out once the new scene has drawn.
- Fighter portraits are `art/versus/fighter_<class>.png` (same size and style; prompts in `art/versus/VERSUS_PORTRAIT_PROMPTS.md`), shared with the VS intro.
- Portraits are `art/dead_league/portrait_0..4.png` (Bellman, Headless, Southpaw, Plague Doctor, Coffin King): dedicated painted portraits (1086×1448, dark backgrounds; prompts in `art/dead_league/PORTRAIT_PROMPTS.md`). A canvas shader feathers their edges into an oval so the aura glows around the figure, not a box.

### Startup
- Godot's boot splash is replaced by a still of the title screen (the ring, the Bellman, the moon and the FRIGHT NIGHT logo, `splash.png`) on near-black; the app icon is a red "FN" under the moon (`icon.png`, also the browser tab icon). The title screen shows no progress text.

### Menus
- One theme everywhere: `UiTheme.make()` is merged into Godot's default theme at startup (a theme on the window stops at CanvasLayers), so HUD buttons, dropdowns, popup menus, tooltips, scrollbars and text fields all match. Godot's window dialogs are replaced by `GameDialog` (a dimmed, titled card).
- Camp header: "NEXT: <contender>" in their color. No instructions strip or legend on the upgrade web, no rules text in the Armory, resource tooltips are just names.
- Arena/Crypt pickers are five big cards edged in each contender's color, with bout pips; sealed ones say who holds the seal.
- Dead League menu: no rule badges or pattern text. Contenders you can't face yet stand in deep shadow in the key art (`art/dead_league/locked_N.png`, soft dark overlays). Readiness is **POWER vs POWER** with a tug-of-war bar and one word.
- Camp header shows your **POWER** (it replaced "NEXT: <contender>").

### POWER rating (`power_rating.gd`)
One number for a whole build; a fresh fighter is 100.
- **POWER = 100 × √(OFFENSE × DEFENSE) × (1 + 5% per special)**
- OFFENSE = damage per punch / 2 (stats, upgrades, skills, gear, class, damage %) × punch speed × average 6-hit combo multiplier vs. a fresh one × (1 + 0.5 heavy + 0.3 counter + 0.25 head + 0.15 body + 0.2 finisher + 0.3 boss damage + 0.02 armor pierce) × (1 + 0.5 fire + 0.4 burn + 0.08 per chain bolt + 0.3 frost + 0.25 ult power + 0.3 ult charge).
- DEFENSE = effective knuckle HP / 50 ÷ (1 + extra damage taken) × (1 + 0.6 dodge window + 0.3 counter window + 0.3 graze cut + 0.15 move speed).
- Specials (each +5%): venom, serrated, shatter, thorns, Iron Will, Grit, The Long Count, Bone Breaker, Slipknot, Gravewalker and the other item/skill specials.
- Contenders are rated with the same formula on the par build they're tuned for: Bellman ≈ 850, Headless ≈ 2,000, Southpaw ≈ 3,900, Plague Doctor ≈ 6,800, Coffin King ≈ 10,000.
- Verdict by your POWER ÷ theirs: under 0.7 OUTMATCHED, 0.88 UNDERPOWERED, 0.97 CLOSE, 1.15 READY, above that OVERPOWERED.

### No crucifixes
The contenders carry no crosses or pendants: Sister Southpaw's headband is plain, and her necklace and the Coffin King's chains just hang, in the models and the key art. Her trophy is **Southpaw's Veil**.
- Crypt altar shows just your Souls and silver; item cards say "Swap".
- Settings only shows a note when two control choices clash.
- **Settings** (`settings_panel.gd`): a wide card with a big SETTINGS title and a Done button, a tab rail on the left (Sound, Controls, Display, and Save data on the title screen only) with Restore defaults under it. Every setting is its own row card (icon, name, one-line hint) that lights up on hover: chunky gold sliders with a value pill, sliding on/off switches, and the control schemes and 3D resolution as tiles you click (the picked one glows gold) instead of dropdowns. Opened from pause, the pause card steps aside.
- **One menu style** (`UiTheme.heading`, `UiTheme.card`, `UiTheme.section`): every menu sits on the same near-black card with a gold edge (Settings, pause, tutorial offer, found items, the gilding altar, dialogs, the League panel), headings are the gold display face (SETTINGS, PAUSED, YOU FOUND, STATS, YOUR FIGHTER, WORN, KEPT GEAR), and Settings sections are small gold caps over a thin rule. Copy is short: the tutorial offer is one line ("Five minutes against a training dummy."), option labels drop their explanations, and the Stats heading shows points to spend.
- **Locked things aren't shown**: the camp's Crypt button appears once the Crypt is found, the Arena/Crypt pickers only show open tiers, and the Dead League only shows contenders you can face.

## Dead League [Built, 2026-10-11; reworked for the Climb 2026-10-14]

1v1 boss bouts, opened from the camp's **Dead League** button (`dead_league_menu.tscn`).
- **Since the Climb, bouts use your full build** and each contender scales to its tier's par build (see Progression v2). It was upgrade-free before.
- **Five contenders in order**, each unlocked by beating the one before:
  1. The Bellman
  2. The Headless
  3. Sister Southpaw
  4. The Plague Doctor
  5. The Coffin King
- **Contenders:**
  - Each is one code-built undead boxer with its own silhouette, accent color and combo pool (`dead_league_boss.gd`, data in `dead_league_rules.gd`).
  - At low HP they enrage: faster windups, never summons.
  - **Signature moves (2026-10-26)**, so each later contender is a clear step up:
    - **The Headless, Skull Toss:** the skull rises, flashes blue and flies at your face (`skull_shot.gd`). Slip it (either side) and it bites air and floats home. **Punch it** out of the air and the Headless takes x3 the punch, the skull drops to the floor, and the body fights **blind** for 5s: staggering about and throwing wild hook combos at whatever it faces (only the swings that face you can land). Then the skull floats back on. Punches reach "punchable" things before monsters (`Player._punch_thing`).
    - **Sister Southpaw:** slips 40% of the time between combos, and also at the tail of her open window if you keep punching. She answers every slip with a right-handed jab (the right straight, at minimum windup), doubled 40% of the time. Once a combo (40%) she **pivots** around your side to behind you between punches (0.24s, afterimages, "BEHIND YOU"); the next punch waits 0.2s longer so you can turn.
    - **The Plague Doctor:** no more single punches: 3-4 punch strings, each follow-up stuttered early or late. Every punch that lands **heals him 4%** of his max HP (a graze 1.5%). Below 70% HP his **Adrenaline Shot** (head back, a green burst) sets off a 7s **RAMPAGE**: 5-punch strings, windups x0.75, pauses x0.45, moving x1.3, heals x1.5. Then 20s before the next shot.
    - **The Coffin King:** quicker the more he's hurt: windups up to 40% shorter, pauses up to 60% shorter, footwork up to 30% faster and specials up to 35% sooner; 5-punch strings below half HP. "THE KING QUICKENS" at 2/3 and 1/3 HP.
    - Stat steps widened: the Plague Doctor 104 HP / 6.9 damage / windup 0.72 / idle 0.26 (was 98 / 6.7 / 0.76 / 0.3), the Coffin King 134 / 8.1 / 0.64 / 0.2 (was 120 / 7.6 / 0.68 / 0.24).
- **Three rounds** in a roped ring.
  - The boss gets +16% / +34% HP and +8% / +17% damage in rounds 2 and 3.
  - Between rounds you get back 18% of your knuckle HP.
- **Grade** (D to S+) is scored for defense and variety, not raw damage (reworked 2026-10-15):
  - base 800;
  - +40 per perfect dodge, +30 per counter, +50 per punch type landed;
  - −500 × the share of your max knuckle HP lost (so it reads the same at every tier), −15 per graze, −2 per second;
  - then × the **build factor** √(their POWER ÷ yours), capped 0.8–1.2: winning as the underdog scores up to +20%, stomping with a far stronger build up to −20%. The results card shows "UNDERDOG BONUS +N%" or "OVERPOWERED −N%".
  - A win with no dodges or counters lands around C; the regression checks it can't reach A.
- **VS intro** (`vs_intro.gd`): before every bout, your fighter's art slams in from the left and the contender's portrait from the right on tilted panels, VS crashes down with a flash, shake and the bell, names and the contender's tagline appear. The portraits are zoomed out to show the whole 3:4 art (head to knees), lifted clear of the names, with feathered edges (2026-10-15); ~3s, any key or click skips. The boss spawns and the clock starts when it ends.
  - Personal bests are saved per contender.
- **Rewards:** the first clear of each contender **breaks their seal** (see Progression v2). Replays only chase grades.
- **Look (2026-10-14), rebuilt from the key art:**
  - **The Bellman:** stone skull with red eyes, molten ribs glowing through a cracked chest, a big gold bell on gold chains, red-and-white wrapped forearms and red fists, a tattered skirt.
  - **The Headless:** the skull floats and bobs above a burning neck stump, with blue ghost-fire on it and on the shoulders; bandaged arms, bone ribs, a ragged navy skirt with a white sash.
  - **Sister Southpaw:** veil and hood, a plain white brow band, glowing violet eyes, long dark hair, a gold chain, a floor-length torn habit.
  - **The Plague Doctor:** hood, a long bone beak with round green lenses, a belt of glowing green vials and a pouch, wrapped forearms, a tattered coat.
  - **The Coffin King:** skull with a gold crown and red jewels, a red-and-white robe and cape, gold chains, a gold skull buckle, gold gauntlets.
  - All five get thick prizefighter arms with bigger fists, and hold a high guard: fists up at head height and a little out in front of the face, not tucked at the shoulders (their punches use the normal boxer poses).
  - Each glows faintly at the edges in its accent color (a rim-light overlay), trails motes of it, and has an accent light behind it.
- **Arena (2026-10-14):** the key art's graveyard around the ring.
  - An iron fence, about 40 graves and dead trees, a mausoleum behind the boss's corner with a burning doorway, and four fire braziers hanging from iron posts.
  - Moon and stars, ground mist, and a white spotlight over the canvas.
  - Fog thinned so the graveyard shows. The boss starts 4.3m away (was 3m), so it's fully in view at the opening bell.
- **Tests:** `dead_league_regression.tscn` and `balance_regression.tscn`, run headless.
  - Both point GameState and Settings at the test files themselves. The league test resets and saves progress, and on 2026-10-11 it overwrote a real save.

## Progression [Built]

Camp has four pages: **Upgrades**, **Skills**, **Stats**, **Class**.

### Class levels [Built]

- **Each class levels separately.** XP from a run goes to the class you played. Each class has its own level, XP, stat points, stats, skill points and skill web; switching class switches all of them. Each level-up gives that class **3 stat points** and **1 skill point**.
- **Shared by every class:** coins, Champion Sigils, the upgrade web, and nights cleared.

### Upgrade & skill webs [Built]

- Both are **webs** of small icon squares around a center node, joined by arrows. Upgrade types are **mixed together** — no category branches. Drag to pan, scroll to zoom, right-click to re-center. Click a node for its details (level, now/next, cost) in the side panel; buy with the Buy button or by double-clicking the node.
- In the shared coin upgrade web, a node appears only after every node feeding into it is **maxed**. Fighter skill nodes still appear after their prerequisites have one rank. Many nodes have several levels (pips).

#### Node map look & feedback [Built, 2026-10-11]

- **Every node has its own icon.** There are about 90 vector icons in `icons.gd`, for example wraps, a boxing glove, brass knuckles, a heavy bag, a champion's belt, a snowflake, an icicle, a thermometer, a match, storm clouds, a battery, fangs, an eye, a ghost and an axe. Nodes with the same id share an icon across fighters (Headhunter is always the crosshair head).
- **Shapes tell node types apart:**
  - The center node is a large medallion with a turning rune ring.
  - Sigils are round power medallions with a lock badge until they're bought.
  - One-level nodes are octagons, called keystones.
  - Multi-level nodes are rounded squares with level pips.
- **Colors:**
  - Owned nodes are lit in their branch color; maxed nodes are brighter, with a shine sweeping across them.
  - Nodes you can buy have a pulsing **bone-white** rim. It's not green, so it never clashes with a fighter's color.
  - Nodes you can't afford are dim.
  - Nodes waiting on a Champion Sigil are purple and locked.
- **Branches:** each Sigil's branch sits on a soft cloud of its power's color, with the power's name beside the medallion: FIRE orange, STORM violet, FROST cyan, BLOOD red. The skill web takes the fighter's own color.
- **The map:**
  - Faint constellation rings and a dot grid sit behind the web.
  - Owned links glow and carry sparks. Links to buyable nodes are dashed bone-white; others are dashed grey.
  - Unrevealed nodes show as a turning dashed **"?"** on the end of a dashed line, so you can see where the web continues.
  - The view frames the revealed web when it opens.
  - An "owned / total" counter with a bar sits at the top right, and a color legend at the bottom left.
- **Feedback:**
  - **Hover:** the node grows, a soft click plays, and a card shows its name, branch, level and price with icons.
  - **Buying:** a flash, expanding rings and sparks, then "LV 2", "MAX", "UNLOCKED" or "FIRE AWAKENS" floats up. A pulse runs down the link into the node, and newly revealed nodes spring in one after another.
  - **Sigils and maxing a node:** a deeper "power awakens" chord plays.
  - **Can't afford it:** the node, the price and the resource you're short on shake red, with a dull double buzz.
- **Detail panel:** a tag line (CORE / KEYSTONE / SIGIL · AWAKENS FIRE / FIRE POWER · UPGRADE), the name in the display font, the icon tile in the branch color, and the price in a dark well with resource icons.

#### Resource icons [Built, 2026-10-11]

- Every resource has an icon token: a dark disc with a colored rim (`res_icon.gd`).
  - **Coins:** gold coin.
  - **Silver:** stack of coins.
  - **XP:** green gem.
  - **Champion Sigils:** purple sigil.
  - **Skill points:** blue sparkle.
  - **Stat points:** orange arrow.
  - **Knuckle HP:** heart.
- **Pills** (`resource_chip.gd`) hold the camp header's four resources and the HUD's coins, plus silver in the Crypt. They count up or down when the amount changes, pop the icon, and drop a green +N or red -N.
- Text anywhere can carry tokens like `+40 {coins}` (`icon_label.gd`):
  - the kill feed, announcements and Crypt prompts;
  - the item and shop buttons ("Buy 12 {silver}", "Salvage +8 {coins}");
  - the dawn and run summaries ("Earned +245 {coins} +180 {xp}").
- **Sigil nodes** (power roots), capstones and Trophies are coin purchases behind Dead League seals (see Progression v2). Champion Sigils no longer exist.
- **Each class has its own skill web** around a class center node: Fury (Berserker), Read the Fight (Counter Master), Flow State (Combo Master), Light Step (Free Runner). Most nodes cost only skill points; Ultimate Surge and the class's Ultimate II node are behind seals (rings 3 and 5). Each web mixes:
  - **class special boosters** — Berserker: Unbreakable, Rage, Retaliation, Juggernaut (super-armor hits hurt less); Counter Master: Perfect Timing, Free Flow, Executioner, Precision Strike (perfect counters with any punch); Combo Master: Wide Wave, Aftershock, Flurry, Rolling Thunder (shockwaves deal damage); Free Runner: Momentum, High Ground, Parkour, Dive Kick (jump punches stagger);
  - **class stat bonuses** — Berserker: Might (+% damage), Thick Hide (+% knuckle HP), Iron Body (defense); Counter Master: Ghost (dodge windows), Patience (counter window), Cold Blood (+% damage); Combo Master: Flow (combo growth), Fast Hands (punch speed), Endurance (+% knuckle HP); Free Runner: Stride (sprint), Light Body (move speed), Acrobat (jump height), Opportunist (vs weakened enemies);
  - a class-specific selection of **general technique** nodes (Headhunter, Slick, Second Wind, Liver Shot, ...).
- Node data lives in `UPGRADES` / `SKILLS` in `game_state.gd` (`pos` = grid cell around the center, `requires` = the node the arrow comes from, `sigil_cost` = seal).

### Champion Sigils [Retired 2026-10-14]

- Replaced by seals (Dead League wins) and Souls (boss drops). Saves converted each sigil to 3 Souls.

### Sigil Powers (2026-10-10)

The upgrade web has four **Sigil nodes**. Each costs coins and opens with a Dead League seal (Fire after the Bellman, Frost after the Headless, Storm after Southpaw, Blood after the Plague Doctor), and **unlocks a power**. The nodes past it are that power's upgrades, split into branches. **Since 2026-10-27 each power has its own corner** (Fire top right, Storm bottom right, Frost bottom left, Blood top left): the Sigil needs nothing but its seal (it shows sealed from the start), three branches fan out of it (along the edge, the diagonal, and down the other edge; each step one seal later, so later steps wait on later contenders), and the three meet at the capstone (Pyre, Thunderhead, Shatter, Bloodbath; every branch maxed first, Crown ring). New nodes: Furnace Heart, Tinderbox, Ember Rain; High Voltage, Ball Lightning, Tesla Coil; Black Ice, Hoarfrost, Glacier; Blood Bank, Transfusion, Open Vein, Death Wish, Red Tide. Glass Breaker moved to (4, -2). Saves keep what they bought (same ids). The other parts of the web have no seals any more (heavy hitting, economy, Champion's Belt are open).

| Sigil (where) | Power | Branches |
|---|---|---|
| **Fire** (east, past Heavy Hitter) | Set-up hooks/uppercuts and counters burst into flame: x0.3 of the hit to everything around the target, and everything it touches burns (0.25x base damage/s for 3s) | **Damage**: Hotter Flames (+20% burst) -> Wildfire (+1m radius). **Duration**: Lingering Flames (+1.5s burn) -> Searing (+0.2x burn/s). **Proc**: Kindling (any landed punch: 6% chance per level) |
| **Storm** (west, past Light Feet) | Every 5th combo-growing hit arcs lightning to the 2 nearest enemies for 40% of a combo-limited version of the hit; each jump falls to 75% of the previous | **Reach**: Forked (+1 jump) -> Storm (every 4th hit). **Damage**: Overcharge (+15% per level) -> Conductor (every counter arcs too). **Control**: Static Shock (staggers) |
| **Frost** (north, past Skull Cracker) | Set-up heavies and counters freeze the target and everything within 2.5m: 40% slower for 2s | **Strength**: Deep Freeze (+10% slow, max 85%) -> Brittle (frozen enemies take +10% damage from everything). **Duration**: Permafrost (+1s) -> Cold Snap (any punch: 8% chance per level). **Reach**: Frost Nova (+1m) |
| **Blood** (north-east, past Giant Killer) | Every kill heals 2 knuckle HP | Vampiric Knuckles (+1 per kill) -> Blood Rage (up to +15% damage per level as knuckles fall). Bloodletting (counters heal 1 per level) |

Frost replaced Ground Pound in the web; Ground Pound still exists as a Crypt boots power. Power damage costs no knuckle HP.

Each elemental branch has a one-sigil capstone: **Pyre** makes burning deaths explode and spread fire; **Thunderhead** calls lightning on clean dodges; **Shatter** makes frozen deaths spread frost; **Bloodbath** doubles healing below half knuckle HP. Each fighter can spend two additional sigils in its skill web: one on **Ultimate Surge** and one on **Inferno II / Riposte II / Temporal Break II / Highlight Reel II**.

**Old saves:** the web has a layout/balance version (3). Saves from before the four-power layout still receive the original full migration refund. Version-2 saves receive a one-time progression respec: their upgrade nodes are cleared, all spent Champion Sigils return, and coins return at the approximate pre-rebalance prices (not the new 43,350-coin prices, which would immediately max the web again). Levels, stats, class skills, clears and unspent resources are preserved. Camp explains the respec once.

## Camp [Open]

The camp buildings planned earlier (training dummy, furnace, workbench, cooking pot) were tied to the resource-gathering design. Which of them still make sense with coins-only is undecided. The training dummy (XP over time while playing) and the cooking pot (single-run buffs, bought with coins) still fit.

## Open questions

- Which camp buildings to keep, and whether the camp becomes a 3D place.
- Does anything other than coins drop (e.g. bones as a second currency)?
- Should runs have a final wave / boss, or go forever?

## Boss combo super armor [Built 2026-10-15]
Bosses (the Grave Champion, Crypt floor bosses and the Dead League contenders; `Boxer.combo_armor`, on in `boss.gd`) can't be interrupted mid-combo. While more punches are still queued, counters and other staggering hits land for full damage, but they don't stagger the boss, cancel the combo or knock it back (20% push). The first such hit in a combo pops SUPER ARMOR with a gold ring and a metallic clang. The last punch of a combo, or a single-punch attack, can be interrupted, and after the combo the boss is open as before. The lesson: dodge the whole combo, then punish the end. Regular enemies are unchanged.

## Enemy gear tiers [Built 2026-10-15]
Enemies wear tiered armor and weapons (`enemy_gear.gd`), so you can see you're fighting stronger dead as you climb.
- **Pieces:** helmet, chest plate, leg guards, boots, and gauntlets (or the held weapon, recolored).
- **Tiers** follow the Climb position the enemy spawns at:

| Tier | Climb | Look | Power |
|---|---|---|---|
| 1 Rusted | up to the Bellman | rusty brown iron | ×1.0 |
| 2 Iron | to the Headless | plain grey | ×1.25 |
| 3 Steel | to Southpaw | bright steel, gold trim, a crest | ×1.55 |
| 4 Blackiron | to the Plague Doctor | near-black with glowing orange trim, horns | ×1.9 |
| 5 Grave-gold | to the Coffin King and beyond | gold with glowing teal trim, crown spikes | ×2.3 |

  There's a 25% chance of one tier lower.
- **How many pieces:** each piece shows up with chance 12% + 18% per Climb step + 25% of the way through the current tier (capped at 95%), weighted chest > helmet > legs > gloves > boots. The first bouts are mostly bare, and late tiers often wear full sets. The old "armored" spawns now mean at least a helmet and chest plate. Bosses always wear a full set.
- **Stats:**
  - Chest, legs and boots block 12% / 6% / 4% of the punch unit (par damage where the enemy spawns) × the tier's power, flat, from every body punch.
  - The helmet blocks 16% × power, on head shots only.
  - Gauntlets or a weapon add 6% × power damage.
  - Each piece adds +4% HP and +12% coins and XP.
  - Armored hits spark in the tier's color.
- **Fitting:** pieces are shaped from each enemy's own head, torso, legs and hands (found from its box parts; thin bony parts get a minimum size so skeletons still get a proper breastplate).
  - **Robed casters** (mage, priest, wraith, lich): their robes are recolored to the tier's cloth, with collar and hem trim, a circlet and bracers.
  - **Possessed Armor:** its own metal is reskinned.
  - **No gear:** Dead League contenders (built-in defense, tuned in `configure`), the training dummy and the mimic.

## Livelier passives and ultimates, pass 1 [Built 2026-10-25]

- **Knockdowns** (`Enemy.knock_down`): the monster topples away from the blow on a pivot at its feet (its own animation keeps posing the body), thuds with a puff of dust, lies there, then hops back up. Out of the fight while down. Used by Wrecking Ball strikes (2s with Strike!), the Haymaker dash punch and its blast, Hype Train, Inferno Uppercut's launch, Highlight Reel's finisher, Avalanche, the Brimstone burst, Spear Line's bowling and the Ground Pound launch. Bosses are too heavy to fall: they get a stun their poise can refuse.
- **Dazed stars** circle a monster's head for any stun of 0.6s or more (they ride down with it when it's knocked over).
- **The Catalyst:** fireballs and icicles have a white-hot core in a glowing shell, a brighter light and a longer trail; fireballs burst with a ring of flame, icicles flash on each hit. His runes flare in a power's color whenever it goes off (on the hand that threw it), and in each Elemental Fists spell's color; the blood heal streams drops of blood back into his fist. A flare, not a glow: the steady glow is still only for a ready ultimate.

## Livelier passives and ultimates, pass 2 [Built 2026-10-25]

`MoveFx` (streaks, afterimages, ghost fists, view swooshes, speed lines, the Grudge skull):
- **The Answer:** Phantom Step leaves a fading blue afterimage where he stood and a streak to where he lands. Riposte Stance and Flow State whip a blue swoosh across the view with every slip they make for him.
- **The Blur:** Echo Fists' echo is a violet ghost fist flying into the target a beat behind the punch. From 10 hits in a combo violet speed lines rush past the edges of the view, faster as the combo grows.
- **The Stray:** green speed lines build with Momentum, and run hard all through Hype Train. Head Stomp squashes the monster flat for a moment before it springs back.
- **The Mauler:** the Grudge mark is a glowing red skull turning over the marked monster's head, bigger with every hit it lands on him.
- Tony has nothing new here: an insult bubble over the monster would read as the monster talking.

## Boss poise [Built 2026-10-25]

Every set-up hook and uppercut staggers, and a stagger cancels what the monster is doing. The Mauler's heavies need no set-up, so spamming hooks staggered a boss every half second and it never got to attack (a 3,143 POWER Mauler beat contenders rated 15,636).
- **After a stagger or stun, a boss holds its poise** for the stagger plus 4.5s (3s before 2026-10-29) (`Enemy.BOSS_POISE`): further staggers and stuns don't take, and hits during the stagger can't stretch it. Hits still do full damage. The first one it shrugs off shows "STEADY".
- Bosses are everything with `is_boss`: Arena and Crypt bosses and the Dead League contenders. Regular monsters, elites and champions have no poise, so the Mauler's hook spam still works on a crowd.
- Checked in `card_runtime_regression`.

## Hats and Tony [Built 2026-10-15]

**Code:**
- `hats.gd`: the catalog, rolls and the block-built looks.
- `hat_popup.gd`: GIMME THAT.
- `tony_unlock.gd`.
- `insults.gd`: shuffled line bags, tame/explicit.
- Enemy hooks: `_wear_hat`, `_pop_hat`, `_lose_hat` and `taunt` in `enemy.gd`.
- The Hat Rack tab in `camp.gd`, with thumbnails in `art/hats/`.
- Tony's class `wise_guy` in `game_state.gd` (`SECRET_CLASSES`, `class_ids()`).
- Big Mouth in `ult.gd`, Fuggedaboudit in `player.gd`.
- Tony's fists (`_paint_tony`), demo-reel scenes, and `art/fighter_wise_guy.jpg` (cropped from the proposed card).

**As built:**
- Hats are drawn 1.4× head size (the Fruit Hat 1.3× more) so they read across the room.
- Legendaries sparkle on the enemy.
- The popped hat flies off spinning before the card.
- On the card, censored words sit in a black bleep bar with a synthesized censor beep.
- Tony's card trait reads "Wise Up: Hits harder. Bleeds more."
- The class picker shrinks the cards to fit five, and drops the "THE" for Tony.

The humor pillar: a hat collection and a secret character.

### Hats
- **Spawning:** any Arena or Crypt enemy has a 2% chance to wear a hat (raised from 1% on 2026-10-16) (never Dead League contenders, the dummy or the mimic). Rarity: common 60%, uncommon 25%, rare 11%, epic 4%. Legendary starts at 1% of hats, +0.25% for every hat that spawns without being legendary (resets on a legendary), and a legendary is always one you're missing. That's about 22 hats per legendary and about 88 hats (~125 bouts) for all four. The step is the tuning knob.
- **Taking it:** each uppercut has a chance to pop the hat off (common 60%, uncommon 45%, rare 30%, epic 20%, legendary 12%). Finishing a hatted enemy with an uppercut always gets the hat. Any other KO and the hat tumbles off and vanishes in a puff.
- **Popup:** the game pauses; the hat turns slowly with sparkles in its rarity color; then its name, a one-line joke, its boost, and one button: **GIMME THAT**. It's collected and the game resumes.
- **Duplicates** become Souls, with a smaller "Already got one, ya greedy ghoul" popup.
- **Boosts:** small and permanent (about 1-2% for a common, up to ~5% for an epic), counted in stats and POWER.
- **Hat Rack:** the Hats tab in camp's Cosmetics, owned hats on pegs and missing ones as silhouettes.
- **Roster draft:**
  - Commons: Party Hat, Traffic Cone, Shower Cap, Propeller Beanie, Lampshade, Bucket.
  - Uncommons: Bowler, Chef's Toque, Viking Helmet, Pirate Tricorn.
  - Rares: Top Hat (bunny inside), Tinfoil Hat, Hard Hat.
  - Epics: Paper Crown, Witch's Hat, Grim Reaper's Hood, and the **Fruit Hat**: a towering voxel fruit basket (pineapple leaves, oranges, a banana, grapes, cherries, strawberries) on a ruffled hot-pink brim with pink and yellow ruffles trailing down. "Five servings a day. Too late for this guy." +4% max knuckle HP and +1 heal on kill.
  - Added 2026-10-17:
    - **Big Monkey Mask** (epic): a big rubber monkey head over the whole head, with a heavy brow, wide eyes, a toothy grin and round ears. "Ook. The dead find it deeply unsettling." +3% damage, +3% dodge window.
    - **Fast Guy Fleece Cap** (epic): a blue fleece hood with a rolled edge round the face, pointed ears with tan insides and quills swept back, the top one biggest (a speedy hedgehog parody, unnamed like the Strong Guy Wigs). "Blue, spiky, and already gone." +5% move speed, +4% punch speed.
    - **Pocket Trainer Cap** (rare): a ball cap with a white front, red back panels, a red brim and button, and a green swoosh on the front. "Gotta punch 'em all." +4% XP, +3% coins.
    - **Straw Hat** (epic): a wide round straw brim with a red band round the crown and darker strands woven through. "Stretchy guy's. He'll want it back." +4% max knuckle HP, +3% damage.
    - **Rebellious Guy Hat** (epic): a tall black peaked cap leaning forward, a drooping visor with a sheen, a linked gold chain across the front, a round gold button and a gold hand badge, the back torn into jagged hair sweeping up and back with locks by the ears. "Good grief." +4% punch speed, +3% damage.
    - (References for the parody hats are in `refs/hats/`.)
    - **Strong Guy Wigs:** big blocky spiked hair. The black one fans out every way; the powered-up colors stand straight up and taller.
      - Black (common): +1.5% damage. "Spiky. Suspiciously heroic."
      - Blonde (uncommon): +2.5% damage, +2% ultimate gain. "Took three episodes of screaming to put on."
      - Blue (rare): +3.5% damage, +3% ultimate gain. "Dyed. Don't tell anyone."
      - White (epic): +6% dodge window, +8% counter damage. "It moves on its own. So do you."
  - Added 2026-10-31 (Halloween), both dropped like any hat and worn over the whole head like the masks:
    - **Pumpkin Helmet** (rare): a squat orange pumpkin with ribs, a bent green stem and a leaf. "Happy Halloween 2026!" +3% max knuckle HP, +2% damage.
    - **Jack-o'-Lantern** (epic): the pumpkin carved, a glowing triangle-eyed grin with two teeth left in and a candle's light spilling out. "Happy Halloween 2026!" +4% max knuckle HP, +3% damage.
  - **Skeletons love the Fruit Hat:** when a skeleton (including skeleton mages and archers) rolls a hat, 1 in 4 times it's the Fruit Hat. The overall 2% hat rate is unchanged; on other enemies it's as rare as any epic.
- **Legendaries** (generic navy caps with a stitched "Y", no real logo): **Yonker with Brim, Yonker with No Brim, Brim with No Yonker, No Yonker with No Brim** (an empty spot with legendary sparkles). Each does nothing ("Does nothing. Yet."). All four unlock Tony.

### Tony (secret character)
- **Unlock:** the fourth legendary pops, the screen goes black, a deli bell dings: "TONY WANTS HIS SANDWICH." Then he appears in the class picker (hidden until then).
- **Who he is:** Tony, class **Wise Guy**. He found out too late that processed meat is a carcinogen, and he's punching his way out of the underworld for one more bite of that deli sandwich. First-person fists: taped knuckles, a gold chain and a gold pinky ring, a black tracksuit with white stripes (matching his card art).
- **Big Mouth (ultimate):** the meter refills very fast (~3×). Tony insults the enemy he's looking at (single target); it's enraged and comes for Tony only (ignoring the take-turns rule) for 8s or until one of them drops. A KO on an enraged enemy refunds half the meter. Bosses keep combo super armor.
- **Wise Up:** an enraged enemy deals +50% damage to Tony and takes +100% damage from him. Its attacks and attack speed are unchanged; only damage dealt and taken change. (Card line: "Mad monsters hit harder. They bleed easier.")
- **Fuggedaboudit (passive):** once every 10s, the first hit he'd take is waved off with a quip (no damage, no flinch) and tops up his ultimate a little.
- **Insults follow Mode:**
  - Weenie Hut Junior: childishly tame ("Get the frick outta here!").
  - Pro Gamer: censored "explicit" ("Get the *^%# outta here!"), with the grawlix in a black bleep bar (and a censor beep once audio exists).
  - About 20 lines each, shuffled without repeats. Quips and KO callouts follow the same split.
- **Skill web**, about 25 skills in three branches:
  - Mouth: longer enrage, bigger Wise Up bonus, insulting two at once.
  - Fuggedaboudit: shorter cooldown, a heal when it triggers.
  - Hustle: more coins, enraged KOs pay double.
- **Art:** his card art is cropped from the proposed Tony card (the right side) for the class picker and VS intro.

## Upgrade & skill revamp [Built 2026-10-15]

Why: skill webs couldn't be finished (28 points by the Coffin King against 57-73), classes got wildly different raw power from them (Berserker +33% damage and knuckles, Combo Master and Stray none), par ignored skills, flat heals were worthless late, Armor Pierce was a flat 3, nobody built head shots, and dodge/counter windows grew too forgiving.

**Skill webs v2 (all five fighters):** fewer, stronger nodes. A center node, three branches of three nodes that each end in a **sealed capstone** (rings 2, 4 and 6: the Bellman, Southpaw and the Coffin King), plus Ultimate Surge (ring 3) and Ultimate II (ring 5), so every Dead League win also opens a skill. Each web costs **33 points** (level 34 maxes it). Branches per fighter:
- The Mauler: Wrecking Ball (Sledgehammer, Rib Breaker, Lights Out, **Wrecking Ball**), Iron Hide (Thick Hide, Iron Jaw, Bloodthirst, **Juggernaut**), Super armor (Short Fuse, Unbreakable, Payback, **Berserk**).
- The Answer: Punish (Counterpunch, Cold Blood, Precision Strike, **Executioner**), Ghost (Ghost, Thick Skull, Iron Chin, **Free Flow**), Timing (Perfect Timing, Patience, Snap Back, **Checkmate**).
- The Blur: Flurry (Fast Hands, Build-Up, Double Jab, **Thousand Fists**), Stamina (Endurance, Hard Knuckles, Iron Jaw, **Second Wind**), Shockwave (Wide Wave, Rolling Thunder, Aftershock, **Flurry**).
- The Stray: Hit and run (Momentum, Opportunist, Cheap Shot, **Blindside**), Slippery (Rubber Legs, Slick, Hard Knuckles, **Ghost Step**), Parkour (Stride, Acrobat, High Ground, **Dive Kick**).
- Tony: Heavy Hands (Heavy Hands, Knuckle Sandwich, Last Word, **Bada Bing**), Fuggedaboudit (Tough Guy, Shrug It Off, Deli Run, **Made Man**), Big Mouth (Trash Talk, Below the Belt, Hustle, **Say It To My Face**).
- Every full web is worth about the same: **x1.64-1.76 POWER**. No head-shot nodes anywhere (they're hard to land).

**Par counts skills:** enemies and contenders now assume the skill points the par level affords (up to +60% damage and knuckle HP for a full web, `Progression.SKILL_PAR`), and par only counts **power** upgrades (damage, knuckle HP, defense), so buying utility never drops you under par. At par every class rates 0.94-1.13 of its contender at every tier (`balance_report.gd`, checked in `balance_regression`).

**POWER vs contenders is class-fair:** the contender is rated as your class (its built-in bonuses and drawbacks on both sides). POWER's weights cover the new effects (Berserk, Payback, dash punches, Tony's duels, shockwaves, heals, free punches, super armor) and respect the caps.

**Coin web retune:**
- Renamed: Taped Up, Leather Knuckles, Bricks for Hands, Brass Knuckles, Twinkle Toes, Grave Tax, Cemetery Sprint, Rawhide, Snap Wraps, Haymaker, Can Opener, High Guard, Bigger They Fall, Speed Bag, Film Study, Chin Check, Crowd Pleaser, Lead Tape, Prize Fighter, Sap Gloves; powers Hellfire (Brimstone, Slow Burn, Scorch, Firestarter), Deathchill (Brittle Bones), Thunderclap (Forked Lightning, Perfect Storm, Lightning Rod), Blood Moon (Bloodsucker, Seeing Red), Ribcage Armor, Jump Rope.
- Skull Cracker (head shots) became **Sap Gloves** (+0.75 damage per level).
- **Heals are a percent of max knuckle HP** (kills, milestones and Crypt rooms, counters, clean dodges, Slipknot), so they matter at every tier. Values cut to fit: Blood Moon 1% per kill, Bloodsucker +0.5%, Cornerman and Ice Bath 1% per milestone.
- **Can Opener** ignores 15% of enemy armor per level (Piercing gear rolls 10%+), capped at 75%.
- Trophies raised so every seal is a real jump: Bellman's Bell +2.5 dmg / +15, Headless Helm +2.5 / +20 / +1, Southpaw's Veil +4 / +25 / +1.5, Plague Censer +7 / +50 / +2.5.
- Night-era wording is now Arena wording (milestone bonus, purse).

**Caps:** dodge windows +25% at most from everything you own (class bonus on top), counter time +0.5s at most, armor ignored 75% at most.

**Icons:** `art/icons/<icon>.png` replaces a vector icon everywhere; prompts for every icon in use are in `art/icons/ICON_PROMPTS.md`.

**Secret:** typing FUGGEDABOUDIT anywhere in Settings unlocks Tony (with his unlock screen; the title reloads so he's in the picker). Typing ABRACADABRA unlocks the Catalyst the same way, as if bought in the Soul Shop (his own unlock screen: "THE OLD WIZARD THROWS HANDS").

**Old saves:** upgrade web version 5 refunds every coin spent at the version-4 prices (`V4_PRICES`); skill web version 2 clears every class's skills and returns all its points (level - 1). Kept Piercing gear converts to the new percent. Camp says so once.

## The spoke web and early money [Built 2026-10-16]

**Upgrade web v6** (`punch-craft/tools/coin_web.py` generates `UPGRADES`; 83 nodes):
- **Four straight spokes** from the center (Taped Up), one tier per seal ring (1-6). Each tier only shows once the one before it is maxed, and is stronger and pricier than the last:

  | Spoke | Direction | Tiers |
  |---|---|---|
  | DAMAGE | east | +1 / 1.2 / 2 / 3 / 4 / 6 damage a level, 5 levels each: Bricks for Hands, Iron Fists, Sledge Fists, Wrecking Fists, Anvil Hands, Hands of the Damned |
  | HEALTH | west | +6 / 9 / 13 / 19 / 27 / 38 knuckle HP: Leather Knuckles ... Undying Hide |
  | DEFENSE | south | +0.6 / 0.8 / 1.2 / 1.7 / 2.4 / 3.2: Mouthguard ... Iron Coffin |
  | MONEY | north | +5-12% coins, 3 levels each: Grave Robber ... King's Ransom |

- **Related side lines:**
  - Damage: Haymaker → Rib Shot (set-up heavies), Counterpuncher → Return Fire, Can Opener → Bigger They Fall, Lead Tape, and **crits** (Lucky Shot, Dirty Shot: crit chance; Glass Breaker: crit damage). A crit is x1.5 + crit damage, capped at a 50% chance, and shows CRIT!.
  - Health: Ice Bath, Chin Check, Calloused (free punches), Thick Skull, Second Wind.
  - Defense: Cornerman, Jump Rope, Bob and Weave, Rope-a-Dope.
  - Money: XP, sprint, punch speed, combo build, milestone and purse bonuses.
- **Powers are straight lines off the spokes:** FIRE off damage tier 2, STORM off damage tier 4, FROST off defense tier 3, BLOOD off health tier 5. Each opens with its contender's seal and ends in a Coffin King capstone (Pyre, Thunderhead, Shatter, Bloodbath).
- **The Trophies** hang off the defense spoke's west side, one per seal.
- **Prices:** see the pay ladder below; each ring takes about 4-6 good bouts of its division's pay (ring 1 about 2.5).
- **Respec:** upgrade web version 6 refunds version-5 saves at their old prices (`V5_PRICES`), and version-4 saves at version-4 prices.

**Skill webs:** same shape, but deeper is stronger per point (x0.8, 1.1, 1.35 along a branch, x1.15 for the capstone). A full web is still worth about the same for every class (x1.69-1.82 POWER).

**Early money:**
- **Pick your bout:** after the division, choose any bout you've won (to farm it) or the next one.
- **The pay ladder (revised 2026-10-16):** every coin source (kills, milestones, purses, Crypt rooms, salvage) climbs a ladder. Each bout pays 1.5x the one before, and each new division jumps two steps past the last bout of the one before:
  - Division d, bout b is step 4(d - 1) + (b - 1).
  - Pay is 1.5 x 1.5^step, so Division 3 bout 3 is 1.5^10 and a division pays about 5x the last.
  - The Crypt sits on the same ladder by climb position (`Progression.pay`).
  - XP stays on the old, gentler curve (`Progression.xp_pay`), so levels don't run away.
- **Ring prices scale with it.** About 5.4k, 44k, 255k, 1.45M, 7.9M and 43M coins. Ring 1 takes about 2.5 good bouts, rings 2-5 about 4-5.6 (averaged over a division's bouts).
- **Old refunds** (saves from before the Climb) use version-4 prices, rings and levels (`V4_PRICES`, `V4_RINGS`, `V4_LEVELS`), not today's.
- **First win of each bout:** a one-time bonus of 150 / 250 / 400 coins x the tier's pay.
- **Knocked out:** you still get 35% of the purse times how far through the bout you got.
- **Tier 1 pays 1.5x** (`Progression.PAY`).

**The Mauler (2026-10-16):** Inferno Uppercut fires any time the meter is full. It goes at the last enemy to hit his super armor if it's in reach, otherwise the nearest one. No super-armor hit is needed first. His meter fills 30% faster and never drains from hits.

## Brighter Arena and Crypt [Built 2026-10-16]
- **Arena:** a brighter moon (0.75), more ambient light (0.8, cooler), and moonlit mist instead of black (fog color 0.12/0.13/0.2, density 0.032), so you can see farther.
- **Crypt:** more ambient between torches (0.7), warmer dust in the air (fog 0.1/0.08/0.09, density 0.024), torches 2.4 bright with a 13m reach, and exposure 1.35.
- **The fighter's lantern:** 1.1 bright, 10m reach.
- **Browser builds** (no glow) get +16% brightness and +25% ambient to make up for it (`Look.tune_environment`).

## Daily drills [Built 2026-10-16]

Camp's **Daily** button (a READY badge while any reward is unclaimed) opens three score runs in the training ring (`drills.tscn`, `drills.gd`). Each gets harder the longer you last. The first run of each drill each day pays coins and XP for the score; after that it's practice, chasing your best. Punches cost no knuckle HP in drills.

| Drill | How it plays | Scoring | Gets harder by |
|---|---|---|---|
| **Pad Work** | The coach calls a combo as punch chips (with your keys); throw it in order before the clock runs out. Only the input is judged (2026-10-17): a wrong punch (or, with Shift / Ctrl + click hooks, the wrong hand, shown as L / R on the chip) or the clock running out costs a life (3 lives). | 10 a punch, 25 a set-up heavy, plus (40 + 15 a punch) x (1 + time left) x (1 + 5% a level) per combo | Combos grow from 2 punches to 6 (heavies from level 3); the clock shrinks 5% a level down to 0.9s |
| **Slip Line** | The dummy follows you round the ring and throws; dodge it. Getting hit costs a life (3 lives). | 12 a dodge (25 clean) + 2 a level; counters 30 + 3 a level | A new level every 5 dodges: longer combos (2, 3, then 4 punches), less warning (full, color, pose, fight speed), windups 3.5% faster a level down to 30% |
| **Heavy Bags** | 60 seconds to knock bags off a three-bag rack (Wii Sports style). Bags swing on their chains and fly off when knocked out. | 10 per base punch of damage dealt (set-up heavies hit hardest), plus 100 + 25 a bag for each one knocked off | Each new bag has 14 + 2.5 x (bags knocked) base punches of HP |

**Rewards** (`GameState.claim_drill`): coins = 770 x pay x (score / a good score), XP = 250 x XP pay x the same share. Pay comes from **your furthest fight on the climb** (`GameState.climb_position`): the next bout after your best Arena win, or the deepest Crypt floor you've cleared, whichever is further. Farming an easy division never shrinks them, and the picker shows where they pay from. Good scores: Pad Work 1,700, Slip Line 1,200, Heavy Bags 4,000.
- Pad Work and Slip Line have **no cap**: the longer you last, the more you earn.
- Heavy Bags caps at 1.5x.
- The difficulty floors (0.9s for a 6-punch combo, 30% windups at fight speed) are where it gets too hard for a human, around level 40.

**Pad Work fixes (2026-10-17).** Correct inputs were being marked wrong, for two reasons:
- The drill checked the player's combo count, which stops growing after 4 plain jabs/crosses in a row (the "mix it up" rule).
- The generator could call a combo like jab, hook, cross. The hook comes from the right hand, so the cross was the same hand twice.

Now the generator tracks hands (jab left, cross right, a hook or uppercut from the hand that didn't punch last). Every called combo alternates hands (one double jab allowed) and sets up every heavy. A regression test throws 1,800 combos through the player's rules.

**Results card (2026-10-17).** Again and Back to camp could go dead, for mouse and controller alike. If the game paused as the drill ended (Esc / Start, or the browser losing focus when the mouse is released), the card froze with the tree while the cursor still moved. The results card now ends the fight, turns pausing off, unpauses, keeps processing while paused, and focuses Again. The drill picker cards are bigger, with the status and best score on their own lines.

Saved as `drills: {drill: {best, day}}`; the day is your own clock's date.

## Achievements, the Endless Arena and the Playground [Built 2026-10-23]

**Achievements unlock emotes** (`achievements.gd`, `toast.gd`). The Default is free; every other dance is earned, and the wheel only shows the ones you have (locked things are hidden). Earning one pops a toast at the top.

| Achievement | How | Emote |
|---|---|---|
| Hat Trick | Pop your first hat | Dab |
| Grave Diver | Clear a Crypt floor | Griddy |
| Seal Breaker | Beat a Dead League contender | Floss |
| Flurry | Land a 25-hit combo | Earl Run |
| Drill Sergeant | Finish a daily drill | Nae Nae |
| Veteran Slayer | Knock out a veteran | Take the L |
| No End in Sight | 100 knockouts in one endless bout (was 50 in the Endless Arena) | Horse Ride |
| Legend | Find a legendary hat | Bros. Shuffle |
| Untouchable | Beat a Dead League contender without getting hit | Boo-Yah |

**Soul Shop only (no achievement):** Tree Dance and Warm Up (`Achievements.STORE_ONLY`), 8 Souls like the other emotes; they sit after Boo-Yah on the wheel.

Older saves get what they'd already earned, quietly, when camp loads. The list and which emote each gives are expected to change as emotes are added.

**Endless bouts (2026-10-25: every division's third bout is endless).** The one Endless Arena after the Crown Division became the Crown's third bout, and every other division's third bout works the same way, in that division's own place with its own monsters. It's the ENDLESS card in the bout picker (with your best). Finishing bout 2 and choosing Next bout goes straight into it.
- No progress bar and no champion.
- It starts at the division's third-bout difficulty. Every **25 knockouts** starts a new wave: monsters get tougher (difficulty climbs 0.15 of a tier a wave, was 0.3; pay 0.25 a wave), you get the wave heal, and a **mini-boss** steps in.
- **50 knockouts win the bout** (`ENDLESS_CLEAR`): it counts as bout 3 won, with its first-win bonus and Souls, and the Dead League contender is called out if you haven't beaten them. Then you keep going for the score.
- Any spawn has a **0.5%** chance of being a mini-boss too (was 2%). A mini-boss is an elite (Swift, Ironclad or Hulking; no Brutal) of a monster this bout has already brought, its veteran from the Bone Division on, with 3x a regular's health. (2026-10-25: it used to be any veteran in the game, so Banshees and Crushers turned up in the Gravedigger Division, at 6x health.)
- Monsters attacking at once follow the division (one through Ghost, two in Crown).
- **Score:** 10 a knockout, 30 an elite, 75 a champion, 150 a mini-boss. Each division keeps its own best (`GameState.endless_bests`); an old Endless Arena best moved to the Crown Division.
- **Pay:** kills pay as usual, plus a purse at the end of score x pay x 0.3.

**The Playground** (`playground/`) is a separate Godot project for testing.
- `sync.py` mirrors the game into `playground/project/` (generated, ignored by git) and adds `src/`.
- The project has its own name, so its own save.
- `run_playground.bat` (or `.sh`, `-e` for the editor) syncs and launches it.
- It opens on the training ring with a dev panel (F1): fighter, hat, every emote, spawn anything at any tier (veterans, bosses, contenders), freeze enemies, force any special on the nearest boxer, give and select a power line, god mode, fill the ultimate, +5 levels, replay tips, and arena theme backdrops.

## Hand idles [Built 2026-10-24, reworked with real hands]

After 5s of doing nothing (no keys or buttons held, no movement; looking around is fine) the first-person hands play an idle, then again every 7-11s. Purely cosmetic; any input cuts it off at once and the fingers close back into fists.

**Rigged hands** (`fists.gd`): every finger is three jointed segments and the thumb two, pivoting at the knuckles; closed, they fold into the same fist as before (punches unchanged). Each fighter's colors (tape, wraps, creases) are painted where they fall in the fist, and anything painted over the knuckles (Tony's tape and ring, the Catalyst's runes) rides on the nearest finger. The Mauler's boxing gloves are mittens: the padded front bends as one piece, plus the thumb.
- **Shapes** (`IdleAnims.SHAPES`): fist, open, wide, relax, loose, cup, claw, point, gun, pinch, flick, and finger ripples.
- **Poses** (`IdleAnims.POSES`): named arm poses worked out from where the hand should sit in view and which way the palm faces (palm to face, back of hand, palm up, side-on, fists meeting...), so the fingers are actually seen.
- **Palms turn the natural way** (supination: thumb outward) when they go palm up or palm to face.
- **No passing through:** idles run frame by frame (not tweens); each frame the hands push apart where they'd overlap, so fists bump and stop.

**Each fighter's own:** Mauler Glove Tap (gloves bump, then a punch into his own open glove), Answer Tape Check (flexes the hand, tugs his wrist tape), Blur Shadowbox (shakes his wrists loose, snaps into fists, then a flurry), Stray Shake Out, Tony Pinky Ring (curls his other fingers to show the gold band on his pinky, turns the hand, wiggles it), Catalyst Palm Flame (a flame in his palm, tossed hand to hand, snuffed in a fist).

**Soul Shop** (one per restock, 6 Souls), any fighter: Fist Bump (bump, then blow it up), Coin Flip (thumb flick, catch), Juggler (a skull tossed palm to palm), Drum Roll (a bone in each fist for drumsticks), Windmill, Stretch (fingers spread and rippling), Finger Guns (one hand then the other, the thumb drops like a hammer), Nose Pick (the index finger goes up past the camera, then flicks a booger away).

**Equip** per fighter in Cosmetics → Hand Idles, each card playing live (`IdlePreview`); shop cards preview too.

## New fighter: The Catalyst (Elementalist) [Built 2026-10-24]

A buff old wizard with a white beard and long white hair who put his spells into his fists (card art `art/fighter_elementalist.jpg`, versus art `art/versus/fighter_elementalist.png`). Class id `elementalist`, color pink-magenta. Tagline: "Why cast it when you can punch it?" A little less punch damage (x0.9); his power is in the Sigil powers.

**Unlock:** offered in the Soul Shop for 80 Souls once two seals are broken (`SoulShop.FIGHTERS`, `FIGHTER_SEALS`), so he always has two powers. Hidden from the fighter picker until bought (`GameState.SHOP_CLASSES`). Buying him shows a toast; pick him from the Menu.

**Passives:**

| Passive | Level | What it does |
|---|---|---|
| Dual Sigil (default) | 1 | Two owned powers at once, with all their upgrades. Select one and it joins the last pick; the older drops out (`power_pick` + `power_pick_2`). |
| Attunement | 5 | One power at x1.5 (+5% a point of passive power): damage, burn, freeze, radius, chances, heals. Counts and switches (lightning jumps, Pyre...) aren't scaled (`GameState.AMPLIFIED`). |
| Prism | 15 | Four owned powers at once (any of the eight), base node only: no upgrades (+4% a point of passive power). Select swaps one in; until four are picked, owned powers fill the rest in climb order (`GameState.prism_picks`). |

**Ultimates:**

| Ultimate | Level | What it does |
|---|---|---|
| Elemental Fists (default) | 1 | 10s. Every landed punch rolls each element at 20% (was 15%; 25% with the Elemental Fists II card): a **fireball** flies ahead from the fist and bursts on the first monster (splash, burn); an **icicle** flies ahead and pierces the line (freezes each); **lightning** chains to 3 more; a **blood heal** of 30% of the damage dealt (`SpellBolt`, `Ult.on_landed`). |
| Flame Burst | 10 | A ring of fire 6m around him: 5x damage to everything in it (staggers, knocks back), and they burn (0.8x/s for 5s). |

**Skill web:**
- **Weave** (feeds Dual Sigil; adapts to passive power for the others): Conduit, Resonance, Wellspring, Archmage capstone. Stronger powers (`power_amp`) plus some punch damage.
- **Spellfists:** Spark Knuckles (+2% a level), Hot Hands (spell damage), Long Spell (+3s), Spellfists capstone (+4%). 15% + 6% + 4% = the 25% cap.
- **Kindle:** Old Bones (knuckle HP), Kindle (burst damage), Wide Flames (+1.5m), Phoenix (burn, knuckle HP).
- Ultimate Surge and Spellfists II medallions.
- POWER rating weights his web's effects. A full web is about x1.8, like the others.

**Look:**
- **First person:** heavy old forearms (a vein, white hairs), a dark robe sleeve with white trim, tape wraps up the forearm and over the knuckles carved with runes. When the ultimate is ready, the right hand's runes, light and sparks glow in his first power's color and the left in his second (fire orange, frost blue, storm violet, blood red). Prism cycles through them.
- **Third person** (emotes): see the body under Emotes (open torn robe, hakama, wild white hair and beard, key-pattern wraps).
- The demo reel shows Dual Sigil (burn + chill) and Elemental Fists (fireball, icicle, zap, heal).

## Bounties, mastery and the Crypt merchant [Built 2026-10-24]

**Bounties** (`bounties.gd`, camp's Bounties tab, shown after your first bout win): three tasks at a time. Finishing one pays out at once (a toast) and rolls the next. Swap one for 2 Souls.
- **Tasks:** knock out N monsters / N of a kind / elites / champions / veterans; find hats; beat the Grave Champion; clear Crypt floors; win Dead League bouts; land counters; land an N-hit combo; win an Arena bout at a grade; finish daily drills.
- **Only what you've unlocked:** a kind only once you've knocked one out, champions from the Plague Division, veterans after your first, hats after your first, Crypt floors once it's open. Counters and combos only count in real fights.
- **Rarity:** common / uncommon / rare / epic / legendary. Rarer asks more and pays more: coins 150 / 300 / 600 / 1100 / 2000 x the pay where you are on the climb, Souls 0 / 1 (half the time) / 3 / 6 / 12, bounty XP 10 / 22 / 45 / 90 / 180.
- **Mastery:** bounty XP levels it (to 25; 60 x level^1.4 a level). Odds start 55 / 27 / 12 / 5 / 1% and shift each level (about 28 / 32 / 23 / 13 / 5% at 10).

**Prices up** (bounties pay coins and Souls): Soul Shop emotes 8 Souls (was 5), gear 6 / 12 / 22 / 38 / 60 (was 4 / 8 / 15 / 25 / 40), rerolls start at 2. Gilding Souls 1 / 2 / 3 / 5 / 8, cursed 5 (removed 2026-11-04: gilding is silver only). Stat reroll 3 + 2 per earlier reroll + floor/3. Reforge 5 + 3 per earlier reforge + floor/2.

**The Crypt merchant:** an undead shopkeeper hunched behind a table (hooded skull, glowing eyes, a jaw that works, bony hands, a lantern). His three wares and a healing flask sit on the table. He watches you, taps the table and grunts (a new low "grunt" sound) when you walk up, now and then while you're near, and when you buy. Trading with him opens a shop panel: the three items against what you wear, and Patch Up. The minimap now sits under item panels.

## Clear enemy tells; skill webs follow the loadout [Built 2026-10-24]

- **Tell lights:** every boxer's glowing glove carries a small light in the tell color, so a tell shows even when the hand is behind the body, edge-on or under gear.
- **Gear keeps tells:** gear gauntlets, bracers and tiered weapons glow with the arm's tell (before, gloves gear covered the glow and weapons lost it).
- **Bull Rush / Ghost Charge:** a tackle stance with both gloves glowing red, brighter until the rush.
- **Possessed Armor thrust:** blade drawn back at the chest, point aimed at you, then driven straight out (was a side-on windup that read as a hook).
- **Wraith claw:** wound out wide like a hook; the ghost goes more solid while winding up.
- **Skill webs follow the loadout:** a node that feeds the passive shows the equipped passive's icon, "Powers <passive>." and what it gives it ("-0.2s Phantom Step cooldown"), and the web rebuilds when the passive changes (`Abilities.adapt_tree`, `POWER_TEXT`).

## Capped stats say where you stand [Built 2026-10-24]

Dodge window (+25% max) and counter window (+0.5s max) have caps on the total bonus.
- **Tooltips show your total against the cap:** "+0.12s counter window (0.3/0.5s)", or "(maxed)".
- **Stats page:** Dodge windows and the new Counter window row show the bonus used out of the max.
- **Gear can't max them alone:** these two affixes no longer grow with floor depth (`Items.UNSCALED`); only rarity raises them. Boots roll counter window at 0.12 base (was 0.25, which grew past the whole cap by mid-Crypt). Floor-10 rolls top out around +0.22s and +15%.
- **The Answer's skills:** Patience is +0.05s a level (was +0.15s) and Read the Fight +0.05s (was +0.1s), so his web gives 0.15s of the 0.5s cap instead of 0.4s.

## Camp fits any screen; League bosses press harder [Built 2026-10-24]

- **Camp header and nav row shrink to fit** (`camp._fit_width`) when they're wider than the screen (points waiting, a long fighter name, Loadout and Shop), instead of pushing the camp off the right edge.
- **Contenders slip and counter:** between combos, a punch can be slipped ("SLIPPED", combo broken), then a counter punch comes back: dodge it and counter. 12/20/28/36/45% by contender (was 15-35%), +5% a round, +10% at the final bell, at most once per 1.5s. Never mid-combo, mid-special, while reeling from a hit or while left open (`DeadLeagueBoss.try_evade`).
- **Dead League contenders combo more often:** pauses between combos are about 35% shorter (Bellman 0.95s to 0.6s, and so on), and settling after an undodged combo is 0.45-0.8s (was 0.8-1.4s). Dodging a whole combo still leaves them open as long as before (`DeadLeagueBoss._idle_time` / `_recover_time`).

**A bigger gap between contenders (2026-10-25).** A Junior Mode player beat all five while under par for the Ghost division (S+ on four), so each contender is now a clear step up. Every knob lives in its profile (`DeadLeagueRules.BOSSES`), on top of the tier's par build:

| | Bellman | Headless | Southpaw | Plague Doctor | Coffin King |
|---|---|---|---|---|---|
| HP (× par damage / 2) | 52 | 64 (was 58) | 80 (62) | 98 (68) | 120 (78) |
| Damage (× par EHP / 50) | 4.6 | 5.2 (4.3) | 5.9 (4.4) | 6.7 (4.9) | 7.6 (5.4) |
| Windup (tell speed) | 1.08 | 0.94 | 0.84 | 0.76 | 0.68 |
| Pause between combos | 0.6s | 0.46s | 0.36s | 0.3s | 0.24s |
| Slips your punches | 12% | 20% | 28% | 36% | 45% |
| Open after a dodged combo | 1.0s | 0.9s | 0.8s | 0.7s | 0.6s |

Rounds still add HP, damage and speed on top, and the final bell still speeds them up.

## Arena elites and champions [Built 2026-10-24]

Regular Arena spawns can be **elites** (as in the Crypt: one trait, x2 health, x3 coins and XP, orange aura) or **champions** (new: two different traits, x3.5 health, x6 coins and XP, violet aura, announced in the feed with a growl). Traits: Swift, Brutal, Ironclad, Hulking.

| Division | Elite | Champion |
|---|---|---|
| Gravedigger | 4% | none |
| Bone | 6% | none |
| Ghost | 8% | none |
| Plague | 10% | 2.5% |
| Crown (and Endless) | 12% | 4% |

- Never on the very first bout, and never the Grave Champion's escorts or summons.
- **Worth the trouble:** toward the bout bar an elite counts as 2 knockouts and a champion as 3. In endless bouts they score 30 and 75 (a knockout is 10).
- `world.gd` `ELITE_CHANCE` / `CHAMPION_CHANCE`, `Enemy.make_champion`.

## Combos across enemies and coin bursts [Built 2026-10-24]

- **Switching enemies keeps the combo:** the first punch on a different enemy can be from either hand. The same hand twice on one enemy still starts the combo over (double jab excepted). `player._last_target_id`.
- **Coin bursts in denominations** (`HitFx.coins`, just for show): 100 copper = 1 silver, 100 silver = 1 gold, 100 gold = 1 platinum. A KO paying 367 bursts 3 silver and 67 copper coins, and the HUD counts +367. Bursts come from the Arena and Crypt payouts, so they show what was actually paid (bonuses included). Coins are little spinning discs: copper, silver, gold and a pale blue platinum.

## Ability loadouts and the Soul Shop [Built 2026-10-24]

Each fighter has **three passives and two ultimates** (`abilities.gd`): the default of each is free, the second passive unlocks at class level **5**, the second ultimate at **10**, the third passive at **15**. You pick them in camp with the **Loadout** button (it shows up once there's a choice), never mid-run. `GameState.loadouts` keeps each fighter's picks; `passive()` / `ultimate()` / `has_passive()` / `has_ultimate()` read them.
- **Mini tutorial:** each new unlock gets a camp pointer at the Loadout button ("NEW PASSIVE: ...") until you open it.
- **Skill webs adapt:** the nodes that fed the default passive (`Abilities.PASSIVE_NODES`) give **passive power** to whichever passive is equipped instead (+1 a level, +3 for a capstone, or the node's own `passive_power`). The detail panel says so. Every new passive scales with passive power (`player._pp()`), and POWER counts it (OFFENSE 0.02, DEFENSE 0.025 a point), so full webs still rate the same.
- No floor punching or player ground slams.

### The Mauler
- **Super armor is gone.** His default passive is **Grudge**: whatever hits you is marked with a red skull, and your next punch on it deals **x3** and staggers. His old super armor nodes (Short Fuse, Unbreakable, Payback, Berserk) feed passive power for all his passives; Juggernaut is now +6% knuckle HP and 25% less flinch.

| Passive | Level | What it does |
|---|---|---|
| Grudge | 1 | Hit him, get marked: next punch on you x3 and staggers. |
| Wrecking Ball | 5 | A monster you KO flies like a bowling ball, smashing everything along its path for 2x damage. |
| Berserker | 15 | Up to +60% damage as knuckle HP runs out. |

| Ultimate | Level | What it does |
|---|---|---|
| Inferno Uppercut | 1 | Now **leaps** up to 7 m at the grudge target (or the nearest monster), then the flaming uppercut; the landing splash sets everything nearby alight. |
| Brimstone Shield | 10 | A burning shield soaks the next 3 hits (12s). When it breaks it explodes (4 m) for 2x what it absorbed. |

### The Answer (toned down)
- **Perfect Counter** no longer KOs: it deals **x2.5** more, so Riposte Stance's counters no longer KO either.

| Passive | Level | What it does |
|---|---|---|
| Perfect Counter | 1 | Dodge, then a matching-hand hook or uppercut: x2.5 (every 12s). |
| Phantom Step | 5 | Dodge an arrow, fireball or bolt and you appear 1.3 m behind the shooter, counter ready (every 3s). |
| Dodge Chain | 15 | Every dodge in a row adds +40% to your next punch (up to 6); the punch spends it. |

| Ultimate | Level | What it does |
|---|---|---|
| Riposte Stance | 1 | Every attack slipped and answered with a counter hook, for a few seconds. |
| Flow State | 10 | 10s of dodging everything automatically; punch freely. |

### The Blur
- **Temporal Break** now starts with 6s (about twice as long) and you can **move** while time is stopped.

| Passive | Level | What it does |
|---|---|---|
| Rapid Combos | 1 | Every 5th hit stuns everything nearby and holds the combo timer. |
| Echo Fists | 5 | Every punch repeats 0.25s later as a violet echo for 30% damage. With the **Flurry** node, echoes add +0.05 to the combo multiplier. |
| Long Reach | 15 | Punches reach 3.2 m instead of 2.5 m (+0.05 m a point of passive power; 2026-10-29: was 3.8 m + 0.1). |

| Ultimate | Level | What it does |
|---|---|---|
| Temporal Break | 1 | Time stops; punches land all at once when it resumes; alternating hands buys back time. |
| Unbroken | 10 | For 10s every hit grows the combo multiplier and the combo can't drop. |

### The Stray

| Passive | Level | What it does |
|---|---|---|
| Dash Punches | 1 | Spear Jab and Haymaker out of a dash. |
| Head Stomp | 5 | Land on a monster's head: bounce off, stun it 1s, deal 1.5x; chain head to head. With it you jump 30% higher (a plain jump peaks around 1.2m, short of a head at about 1.8m), and coming down within 1m of a head counts, not just a landing on its round top (2026-10-25). |
| Momentum | 15 | Sprinting builds momentum (up to x2); your next punch that lands spends it as a multiplier. It fades if you stand still. |

| Ultimate | Level | What it does |
|---|---|---|
| Highlight Reel | 1 | Blue lightning dash from monster to monster, ending in a leaping haymaker. |
| Hype Train | 10 | For 6s you run 1.6x faster and bowl over every monster you run into for 2x damage. |

### Tony

| Passive | Level | What it does |
|---|---|---|
| Fuggedaboudit | 1 | Wave off one hit every 10s, with a quip. |
| The Muscle | 5 | Every 15s Cousin Vinnie, a ghostly goon in a fedora, grabs the nearest monster (within 8 m) and holds it 2s. |
| The Take | 15 | +25% coins from everything (more with passive power), and enraged monsters pay double. |

| Ultimate | Level | What it does |
|---|---|---|
| Big Mouth | 1 | Insult a monster: it comes only for you, hits harder and takes double. |
| The Family | 10 | Three ghost goons in green suits and fedoras brawl beside you for 10s (`goon.gd`). |

### The Soul Shop
A **Shop** tab in camp (`soul_shop.gd`) where you spend **Souls**:
- **2 emotes** you don't have yet, 8 Souls each.
- **1 hand idle** you don't have yet, 6 Souls (Hand idles). Achievements still unlock theirs free; buying one just skips ahead (`GameState.emotes_bought`).
- **3 pieces of gear** rolled at the deepest Crypt floor you've beaten (floor 1 if none), never your tier, so cheesing a boss for a higher tier doesn't buy stronger gear. Mostly plain so the shop never replaces the Crypt: common 6 Souls (50%), uncommon 12 (32%), rare 22 (13%), epic 38 (4%), legendary 60 (1%). Bosses drop 1 + tier Souls, so a rare is several bosses' worth. Bought gear goes straight to the armory.
- **Fighters**, as new ones are added (`SoulShop.FIGHTERS`; Tony stays secret).
- **Restock after every fight:** each return to camp from the Arena, Crypt or Dead League counts (`GameState.fights_done`, counted in `Loading.go`). Sold offers stay sold until then. **Replaced 2026-11-04:** the stock keeps until you refresh it. A real-time timer (`SoulShop.FREE_REFRESH_TIME`, 20 minutes, saved as `GameState.shop_free_at`, so it runs while the game's closed) makes the next refresh free: the header reads "New stock in: 19:42" counting down, then "New stock ready!" in gold, and the Refresh button reads "Refresh (free)" with a pulsing "!" (the Shop tab gets one too). A free refresh starts the timer again.
- **Reroll:** 2 Souls, +1 each time, resets on restock. (2026-11-04: the button is "Refresh"; paid any time, 2 Souls +1 each time until the next free one, which doesn't reset the timer.)
- **Layout (2026-10-24):** the cards wrap into centered rows (4 across at 16:9), scrolling only if the window is too short for them.

## Mini tutorials and one power at a time [Built 2026-10-23]

**Freeze-frame mini tutorials** (`tutorial.gd`): the screen dims except a spotlight on one thing (a spot in the world or a control), with a card. Each plays once per save (`GameState.tips_seen`), and only one per scene, so a round is never interrupted twice (chained follow-ups are the exception).
- A **card** ("Got it") pauses the game.
- A **pointer** has no button: only the spotlit control can be clicked, and it closes when its condition is met.

The tips so far:
- **First hatted monster** (`hat_first`, `Enemy._check_hat_lesson`): when a hatted monster is within 12 m and on screen, the game freezes on its hat. "Knock it off with an uppercut... This one only goes down to an uppercut." That monster gets "UPPERCUT IT! (your keys)" over its head and can't be finished by anything but an uppercut (it holds at 1 HP), so the hat always drops.
- **Camp, after your first hat** (`hat_rack`, then `hat_rack_tour`): a pointer at the Cosmetics tab, then a card on the rack (boosts are for good, worn or not, collect them all, click to wear, emote to show it off).
- **First power bought** (`power_select`): "You unlocked a power!" with a pointer at Select until you press it.

**One power at a time:** Fire, Storm, Frost and Blood each work only while selected (`GameState.power_pick`, `power_of`, `power_active`).
- An owned power's Buy button becomes **Select** ("Selected" when it's the one).
- Its line's nodes say "NOT SELECTED" when it isn't.
- Buying deeper nodes still upgrades it.
- Saves from before keep their first owned power selected.

**Heavy bags** hang at eye level. The bag's collision now reaches the floor; before, gravity sank every bag 0.3 m into the canvas.

## Pausing without leaving full screen [Built 2026-10-23]

In a browser, Esc also leaves full screen and frees the mouse, and a page normally can't stop that.
- **P pauses** too, everywhere. It's the key the hints show; Esc still works.
- **Chromium browsers** (Chrome, Edge, Opera): the game asks for Esc with the Keyboard Lock API (`Settings._ready`). In full screen, Esc then just pauses, and **holding** Esc leaves full screen (the browser says so).
- Firefox and Safari don't support Keyboard Lock, so use P there.
- Keyboard Lock may be refused inside an embedded frame (itch's player); P always works.

## Deeper tiers: places, veterans and music [Built 2026-10-17]

- **Places** (`themes.gd`, `arena_scenery.gd`, Crypt `_theme_decor`): each tier has its own look, music and hazard.

  | Tier | Arena | Crypt |
  |---|---|---|
  | 2 | Ossuary Pit (skull wall, skull pillars with blue fire, giant ribcages) | Catacombs (skull niches) |
  | 3 | Drowned Pier (dock over black water, ghost lanterns, sunken ships) | Flooded Vaults (water, sunken coffins, drips) |
  | 4 | Plague Carnival (tents, broken carousel, bulb strings, dead Ferris wheel) | Rot Gardens (glowing mushrooms, spores) |
  | 5 | Coffin King's Colosseum (arcade, skeleton crowd, crown banners, lava cracks) | Royal Tomb (gold sarcophagi, carpet, chandelier, treasure) |

- **Hazards** (`hazard.gd`), always marked and avoidable:
  - Tier 4: toxic puddles that sting while you stand in them.
  - Tier 5: fire vents that glow for a second, then erupt.
- **Veterans** (`veterans.gd`): from tier 2, a growing share of each kind comes as its tougher version, from 25% at tier 2 to 85% at tier 5.
  - Grave Bruiser: bull rush.
  - Sprinter: double haymaker and bull rush.
  - Bone Crusher: combos ending in a ground slam.
  - Pit Fighter: leap slam.
  - Bulwark: shield rush.
  - Pyromancer: fire circles every other cast.
  - Bone Sniper: a lane shot.
  - Banshee: a shriek cone; back step out of it.
- **Shared specials:** the contender specials now live in `Boxer`, with `Telegraphs` for the floor marks, so any boxer can use them.
- **Music:** all tracks are Ogg now (about 0.3-0.45 MB each, looped in game). New tracks:
  - Four Arena tracks and four Crypt tracks, one per tier.
  - A theme for each contender: Bellman iron-bell doom, Headless gallop-western, Southpaw harpsichord drill, Plague Doctor carnival waltz-trap, Coffin King epic.

## Gilding is for keeps [Built 2026-10-17]

- **A gilding altar rises in every Crypt boss room** when the boss falls, next to the boss chest and the stairs. You can gild the boss's drop right there, not only at the floor's first room.
- **Gilded finds survive a knockout.** Going down (or abandoning the run) keeps every gilded find, worn and in the Armory, the same as leaving by the stairs. Only finds that weren't gilded crumble.
- The results card says "KEPT N GILDED · M FINDS CRUMBLED TO DUST", and camp lists what came home.

## Gentler difficulty ramp [Built 2026-10-17]

Crypt floors and Arena bouts got too hard too fast. Monsters are now built for a position on the climb that trails what the fight pays, using `Progression.enemy_scaling(x, difficulty)`.

- **Arena** (`arena_difficulty`): bout 1 sits at the last contender's par. Each bout climbs a fifth of a tier (was a third), so bout 3 is 40% of the way to the contender, not 67%. Pay still climbs 1.5x a bout.
- **Crypt** (`crypt_difficulty`): a run starts at its bracket's base and climbs a quarter of a tier a floor, however deep it goes. It used to jump a whole tier every two floors, so a bracket-1 run was at the Headless's par by floor 3. Now it reaches the Bellman's par at the end of floor 4. Pay and gear still follow the floor number, so going deep pays well.
- Contenders are unchanged: still at par, now with specials.

**Freeze on bosses:** Frost slows by up to 85% for 2s (+3s from upgrades) and reapplies on every set-up heavy, so bosses stayed slowed through whole fights. Every boss (Arena, Crypt, Dead League) now shakes a freeze off in 0.5s (`Enemy.BOSS_CHILL_TIME`). Other monsters keep the full time.

## Contender specials [Built 2026-10-17]

Two contenders went down back to back. Each Dead League contender now has signature moves on top of the boxing (`dead_league_boss.gd`, Specials).

**Timing:**
- The first special comes about 5s into a round, then every 9 / 8.5 / 8 / 8 / 7s (Bellman to Coffin King).
- Each later round brings them 12% sooner, and the final bell 30% sooner.
- A boss with several moves never repeats one twice in a row.
- In round 3 or after the final bell, a slam or charge can come twice.

**Warnings:** each special pops its name over the contender, and the HUD tells you what to do, with your keys. The marks can be under your feet, out of view.

**Armor and punishment:** hits land during a special but don't stagger it, except while dazed. Every special leaves an opening after.

| Move | Who | What happens | How to beat it |
|---|---|---|---|
| **Death From Above** (leap slam) | Bellman, Plague Doctor, Coffin King | Crouches (0.45s), a red ring follows you until it jumps, then it lands on that spot in a shockwave (radius 1.9 m, 1.6x a punch) | Get out of the ring, or jump it. Jumping it readies a counter |
| **Ghost Charge** | Headless, Southpaw, Coffin King | A lane lights the canvas toward you, tracking you, then locks 0.4s before the dash. A shoulder charge to the ropes at 13 m/s (1.9x a punch). It hits the ropes **dazed** for 1.5s | Step out of the lane, or roll it (Q/E in Weenie Hut Junior Mode). Punish the daze |
| **Judgment** | Southpaw, Coffin King | Leaps to the far edge and calls down circles: one under you (it goes off last) and 1 + round more around the ring. They burst after about 1.4s (1.3x a punch) | Stay out of the circles; no dodge helps |
| **Miasma** | Plague Doctor | Leaps to the far edge and lobs three vials around you. They burst, then leave poison clouds for 3.5s that sting every half second you stand in them | Stay out of the clouds |

New attack types: `charge` (answered by either roll) and `zone` (no dodge beats it).

## Tamer upgrade prices [Built 2026-10-17]

Upgrade costs climbed too fast. Two changes in `tools/coin_web.py`:
- **Level growth:** spokes went from 1.45x to 1.22x per level; side nodes and trophies from 1.6x to 1.3x.
- **Ring prices:** reaching par in a ring now takes about 2.7 good bouts of that division's pay (ring 1 about 2), down from 4 to 5.6 and rising.

| Ring | Before | Now |
|---|---|---|
| 1 | 5.4k | 4.3k |
| 2 | 44k | 29k |
| 3 | 255k | 152k |
| 4 | 1.45M | 763k |
| 5 | 7.9M | 3.9M |
| 6 | 43M | 18.6M |

Maxing the Coffin Crown went from about 19M to about 7.3M.

**Existing saves (upgrade version 7):** saves from version 6 keep every level they bought and get back what each level cost over its new price (`_refund_price_drop`, `V6_PRICES`), with a notice. Older saves respec as before.

## Emotes and your fighter's body [Built 2026-10-17]

**Cosmetics (2026-10-24):** the camp's Hats tab is now **Cosmetics**, with its own tabs:
- **Hats:** the Hat Rack.
- **Emotes:** your fighter on a little stage, wearing your hat, doing the emote you click; every emote you own, with a count.
- **Hand Idles:** the idle cards (moved out of the Loadout, which is back to passives and ultimates).
- **Skins:** your fighter's own look and the skins you've bought, each dancing on its card; click one to wear it (see Skins below).

Hold **Emote** (G; View / Create on a controller, plus D-pad down in Weenie Hut Junior Mode, where it's free; in Pro Gamer Mode it's the back step) for the emote wheel, steer with the mouse or right stick, and let go on a dance. The camera pulls out to third person (about 0.35s, Destiny style) around your fighter. The mouse or right stick orbits the camera. Moving, punching, dodging, jumping, the ultimate or getting hit ends the dance and glides the camera back. Emoting works mid-fight; you're open while you dance. A quick tap repeats your last dance (or stops one). On a controller, a tap opens the map where there is one (the Crypt, the tutorial's dummy cycling), since the map gave up its own button.

**Dances** (one file each in `punch-craft/emotes/`, played by `emotes.gd`; see Emote pipeline below):
- The Default
- Dab
- Nae Nae
- Floss
- Take the L
- Griddy (heel taps, then the goggles)
- Horse Ride (reins hop, then the lasso)
- Earl Run
- Bros. Shuffle (the Mario & Luigi dance: fists bouncing at the chest, knock-kneed sway, alternating fist pumps)
- Boo-Yah (Vector's "Oh yeah!" from Despicable Me, added 2026-10-24): whip round into a T-pose and sway; lean back, hips thrust, hands wiggling low; claws up by the face; both fists pumping overhead; a double biceps flex; smug hip swivels, fists at the hips. Earned by Untouchable.

### Emote pipeline [Built 2026-10-30]

Emotes are redone to match real sources (clips, GIFs, stills, written breakdowns), so making one has to be accurate and quick.

**Dance files** (`punch-craft/emotes/<id>.json`, exported with the game):
- A dance is keys on a timeline: `t` in seconds, a pose of joint rotations in degrees, and the hips' offset (`pos`) in cm.
- A key can name only some joints. Each joint flows through the keys that name it.
- Ease per key: smooth (the default: flows through the keys without swinging past them), ease (stops on the key), snap (fast out, settles in), linear, hold.
- `length`, `loop`, `loop_start` (an intro that plays once), `plant` (hand-made: the hips drop on bent knees with the feet kept down; tracked: the legs as keyed).
- `source` and `ref` point the Studio back at the tracked clip; the game ignores them.
- The 13 old dances (plus the secret ending's swing and uppercut) were moved over as they were, now on smooth curves instead of stop-start eases.

**More joints** (`FighterBody`): a chest over the waist (body rolls), a neck under the head (head bobs), and ankles measured from flat on the floor, so feet stay flat however the knees bend unless a dance tips them.

**Emote Tracker** (`emote_lab/`, run `Emote Tracker.bat`): a browser page. Drop in a video (trim it to one loop), a GIF, or stills. Pose tracking (MediaPipe) finds the dancer's 33 joints in 3D every frame. Saves `<id>.track.json` into `emote_lab/sources/` (local only, not committed) with the notes, links and a strip of reference frames.

**Emote Studio** (playground: Character Lab, Emote Studio):
- **Import** a tracked clip onto the rig (`EmoteRetarget`): smoothed, each joint's rotation worked out frame by frame, the weight foot kept planted (hips drop and sway over it), lifted for jumps, moved for travel, then cut down to the keys the motion needs (a slider sets how close).
- **Edit:** the source frame beside the fighter and the tracked skeleton over him, synced to the timeline. Click a joint on the body and drag it (limbs point where you drag), or use its sliders. Editing between keys makes a key. Move keys on the timeline, drag the end to change the length, Faster / Slower stretch the whole dance, a beat grid snaps keys to the music, mirror a pose or the whole dance, copy and paste poses, undo.
- **Save** writes the game's file.
- Checked by a round trip (`-- --selftest`): five game dances written out as tracking and imported back land within about 2 cm.
- **Import corrections (the Griddy, 2026-10-30):** tracked depth is the shaky axis, so the import squares the dancer to the camera (the clip's typical lean, turn and chest twist taken out, measured from the legs standing straight), counts each foot's typical angle as flat and the head's as looking ahead, and lands hands that touch the face on the fighter's own face (his head is far bigger for his body, so arm angles alone stop at the cheeks). Depth trust and squaring are sliders in the import panel.

**Redone from sources:**
- **Griddy (2026-10-30):** tracked from the user's clip of the game emote (fingers ignored). Crouched heel-tap footwork with pumping arms, a wide-arm lean, the forward lean, then the goggles; 3.96s loop, keys straight from the import.
  - Second pass (the user's notes): the head was looking up and to the side, the body swayed side to side, the feet and knees moved too little, the Mauler's ankles poked out of his high tops, and one arm swing glitched. The import now levels the head's typical turn and tilt as well as its tip and calms its motion (HEAD_CALM 0.6); the body stands between both feet (only shifting onto one clearly lifted off), is steadied side to side and doesn't follow travel unless asked; the legs' moves play 1.6x as big (LEG_GAIN, a slider); a nearly straight arm keeps the twist it had instead of flipping half way round in a frame (the glitch: 73 degrees in 1/60s), and each turn keeps the set of angles nearest the frame before.
  - **Hands on the face** go in the dance file as where they touch the head (`lhand` / `rhand`: ear-widths round the ears' middle, and a weight), and each fighter's arm reaches that spot on his own face as he plays it (`PlayerBody._reach_hands`), whatever his head, arms or gloves. Before, the goggles stopped at the Answer's cheeks and went over the Mauler's head.
  - **Boot shafts and shoe collars ride the shin** (`FighterBody._collar`), so a bent ankle turns the shoe under them instead of swinging the shaft off the leg.

- **Redone from the user's clips (2026-10-30), hand-keyed from the clip's timing** (the raw tracker import was too noisy on loose clothing and blur; the Studio import stays for cleaner clips). Each is a generated file with its feet kept on the floor (hips ride exactly as high as the lower leg allows):
  - **Boo-Yah:** T-pose, drop with arms bent at the hips, slow rise, then 5 sides of coil (butt back, chest forward, knees bent, arms forward at 90 degrees) / thrust (hips forward, chest back, arms back) / hop to the other side, 90 degrees of turn; 9.2s.
  - **Nae Nae is now Watch Me** (id stays `nae_nae`): leg raise and arm wind-up, stomp, arm whip straight out in front, backward walk in a deep wide squat with hip shifts (feet locked while the hips slide) and an overhead wave with the elbow bent, then mirrored; 9.15s.
  - **Dab:** loose stance, then feet together and knees bent (48 degrees) as the arms go to the side, the bent arm beside the face (not over it), a 0.6s hold each side; 2.4s.
  - **Intense Yelling / Overexerted:** a wide horse stance (hips back, chest forward, head level, elbows bent about 78 degrees, fists forward). The aura is only thin rising sparks and a soft light (the solid glowing shell covered the player and is gone); lightning every 1.6-3.4s and 12 dB quieter.
  - **Running Man is now Earl Run** (id stays `running_man`; a nod to the Cloudy With a Chance of Meatballs officer). Not redone yet.
  - **Tree Dance (new, Soul Shop only):** cactus arms and straight legs, roll the arms forward and cross them coming down, touch the hips, cross out front, sweep up, clap in front, drop into a wide squat, then six hip thrusts alternating one hand up (wrist flicks back) and one down (wrist flops forward) with the head toward the raised hand; 6.7s.
  - **Warm Up (new, Soul Shop only):** one-foot hops (two a side, 0.68s each) with the arms long and loose, flopping out from and back in to the body, the neck tilting every second hop; a low coil, a jump and a hard landing into a boxing stance (left foot forward, fists by the chin); dust on every landing and a slight aura on the stance; 7.1s.
  - **Wrist joints** (`lw` / `rw`, pitch only): every fighter's hand now hangs on a wrist pivot (`PlayerBody._hand_frame`), so a hand can flop forward and back. Also in the Studio's joint list.
  - **Emote effects** (`punch-craft/emote_fx.gd`): a dance file may carry an `fx` list of `{"t", "do": "dust" | "aura", ...}`; `Player.start_emote` plays it while the dance runs, and the Studio's render shows it.

**Tightened 2026-10-17:** the dances were stiff from the front, because knee bends and hip dips happen front to back, and the feet sank into the floor.
- `PlayerBody._plant_feet` now keeps the feet on the canvas: dropping the hips bends the knees, and swaying them sideways leans the legs.
- Every dance moves in the frontal plane: wide hip sways, arms out to the sides, sideways kicks.
- Timing is snappier, about 0.15-0.2s a beat.
- The Nae Nae has a big overhead wave, a loose low arm, and a hip-to-hip rock with a knee pop into each side.

**The body** (`player_body.gd`, re-sculpted 2026-10-24) is sculpted in small voxels after each fighter's voxel model (`art/fighter_*_voxel_model.png`, Tony's is `fighter_tony_`, the Catalyst's `fighter_catalyst_`).
- **Shapes, not boxes:** limbs are tapered ellipses with muscle swells (deltoids, biceps, triceps, forearms thick below the elbow, quads, calves), the torso narrows to the waist with pecs, abs, obliques, lats and traps on it, and each fighter has his own build (`BUILDS`: chest, waist, arms, legs, neck, jaw from square to pointed, face width).
- **Faces** are drawn in whole voxels like the models: a dark brow bar, eyes (white, pupil, iris, white), a nose standing out, a mouth. Cheekbones, ears with a bowl and a lobe.
- **Clothes** are shells over the body: ragged hems and trim, folds (a ruffled surface), knotted sashes with hanging tails, flaps below the belt, wraps in bands, laced shoes with soles and stripes.
- **Baking** shades each cube by how closed in it is: darker in creases (between abs, under the pecs, cloth folds), lighter on edges.
- **Building** is spread over frames (6 ms a frame, 12 in camp) and kept per fighter for the session, so a fight never hitches on it.
- **Hats sit in the hair (2026-10-25):** every hat sits just over the skull (`PlayerBody.HAT_SEAT`). The hair above that line is built as its own part (`HairTop`) that hides while a hat's on, so the hat sits down in the hair instead of floating on top of big hair. The hair below the brim stays: the Blur's curls, the Stray's headband and locs, the Answer's bangs.
- **Cloth wraps the chest (2026-10-25):** clothing shells cover the pecs as well as the torso (`_in_chest`), so muscle no longer pokes through the edges of a shirt.

Each fighter:
- **The Mauler:** huge arms and neck, square jaw, flat-top swept forward; open black vest with ragged white trim, red sash knotted in front, black trunks with a ragged hem, blood spatter, giant red gloves with taped cuffs, high boots with red laces and soles; orange eyes.
- **The Answer:** spiky hair with bangs over the brow; sleeveless black hoodie piped white with the hood down round the neck, white belt, the hoodie's long front below it; baggy pants slashed with white lightning; blue wraps, black fists; ice eyes.
- **The Blur:** a huge mass of curls over a slim build and pointed chin; crop top with a high collar and violet piping, bare abs, violet sash knotted at the hip; balloon pants with big pale patches into striped leg wraps; violet eyes.
- **The Stray:** a bush of thick locs, red headband with long flying tails; black gi crossed at the chest with ragged white trim, red scarf, red belt with white cloth hanging, a torn skirt; pants torn at mid-shin with white cross patches, red ankle wraps, white sneakers; green fingerless gloves; a grin; green eyes.
- **Tony:** knit beanie, gray stubble, red nose; half-zip track jacket over a white tee, white zip piping, pocket flaps, puffy striped sleeves into ribbed cuffs; loose striped track pants; gold chain and pinky ring; taped hands.
- **The Catalyst:** wild white hair streaming back, a full beard to the chest; open black robe with ragged white edges and short torn sleeves; knee-length hakama frayed white; strapped boots; wraps with a key pattern, fire orange on the left, violet on the right.

It renders on its own layer, so the lantern at your eyes doesn't blow it out; a soft fill on the emote camera lights it. No crosshair while the camera's out.

**Wear a hat:** click an owned hat on the Hat Rack (Cosmetics) to wear it (WEARING tag, gold border); click again to take it off. It shows on your fighter when you emote (Tony's beanie comes off for it). It's cosmetic only: every owned hat's boost already counts. Saved as `worn_hat`.

**Enemy labels (2026-10-17):** the Armor number is gone from enemy name tags; the gear on the body says it. The damage-reduction line stays.

## Save codes, the crowning, dancing shop cards, a smoother Arena [Built 2026-10-25]

- **Save codes** (Settings → Save data, title screen only): **Copy save code** puts your save on the clipboard as text ("FN1:" + the save file gzipped in base64, about 700 characters) and shows it to copy by hand too. **Load a save code** takes a pasted one (two clicks, like erasing), checks it's a real code from this version, keeps the replaced save as `save_before_code.json`, loads it and reloads the title (`GameState.save_code` / `load_save_code`).
- **The crowning** (`ending.gd`): the first time you beat the Coffin King, the arena goes dark and gold flecks fall. Your fighter dances on a stage wearing the Coffin Crown. Three bells, then the announcer: "THE COFFIN KING IS DOWN!", "Ladies, gentlemen and gentle corpses...", "Your new champion of the Dead League:", your fighter's name. Then "THE COFFIN CROWN IS YOURS" and a credits roll (the game, the fighters you have, the five contenders, built with). Click or press anything to skip to the champion card (clicks in the first 1.5s are still the fight's punches); Continue goes on to the results. Champions can watch it again from the Dead League menu.
- **The Coffin Crown:** a hat that's won, never dropped (`Hats.TROPHIES`): an open gold ring with six coffin-shaped points set with violet gems and a skull at the front. +5% damage, +5% max knuckle HP. Worn as soon as you win it. Champions from before it existed get it when camp loads. "Legendary" checks that meant the four Yonkers (the Legend achievement, "Does nothing. Yet.", the popup's Yonker count) now check `Hats.LEGENDARIES` so the crown isn't one.
- **Emote cards dance:** Soul Shop emote cards play your fighter doing that dance in your hat (`EmotePreview`, also the stage in Cosmetics → Emotes). The shop's subtitle moved up beside its title so two rows of cards still fit.
- **A smoother Arena from the Ghost Division:** a player with a better build than the Ghost Division's par barely got 10-20 knockouts there, because two monsters could attack at once from that division on, veterans jumped to 45%, and elites to 8%, all at the same step.
  - One monster attacks at a time through the Ghost Division; in the Plague Division a second joins once the bar is half full; two in the Crown Division (`world._max_attackers`). The Crypt matches: one through floor 6, two from floor 7.
  - Veterans by tier: 0 / 15 / 30 / 45 / 65% (was 0 / 25 / 45 / 65 / 85%), 80% past tier 5 (was 90%).

## Higher-detail hands [Built 2026-10-25]

The first-person hands (`fists.gd`) are built at about twice the resolution (voxels 0.0045 m, were 0.0085), so you can see the detail:
- **Wraps show every turn** (`Fists._wrap`): tape and cloth spiral up the arm one strip-width a turn, each turn shaded from its overlapping edge to its tucked edge, with a thin seam between turns. Used by every fighter's tape, the Answer's blue wraps (every fourth turn navy) and the Blur's purple ones.
- **Fingers:** slimmer (0.0162 m wide), so there's a gap between them; a crease at every joint; nails on bare fingertips.
- **Clean materials:** the random per-voxel speckle is a third of what it was; the light does the shading instead. Baked voxels are darker in creases and underneath and lighter on edges and tops (`Fists._shade`).
- **The light** on the hands sits off to the side and a little behind (it was straight overhead and washed out white tape).
- **The Mauler's glove:** smooth leather with fine cracks instead of blotches.

**Built once a session:** each fighter's hands (per skin and side) are built the first time, then reused (`Fists._cache`), and the next fight's are built behind the loading screen (`Fists.warm`, from `Loading.go`). To keep the first build quick: tapers are painted as 3-voxel shells with their hidden cores kept as rectangles (`_fill_shell`, `_cores`), colors are worked out only for voxels that show (`_color_of`), only the outside of the Mauler's glove goes on its bones, and the cube meshes are filled from one buffer (`_cubes`). A first build is about 0.3-0.5 s on desktop; every pair after is a few milliseconds.

## Skins [Built 2026-10-25]

A restyle for each fighter, after the reference art in `art/alternate_skins/` (`skins.gd`). Each is the fighter's own outfit in another palette, on the third-person body and the first-person hands alike:

| Fighter | Skin | Look |
|---|---|---|
| The Mauler | Obsidian Furnace | Orange trim and sash, molten splotches on the trunks, obsidian gloves with lava cracks, gray tape, orange laces and soles |
| The Answer | White Noise | White hoodie and pants with black piping and lightning, black belt, black / white / cyan wraps, white gloves |
| The Blur | Hyperlight | Cyan piping and pant slashes, magenta sash, magenta / cyan / white wraps |
| The Stray | Rooftop Ghost | Navy gi, orange headband, scarf, belt and ankle wraps, teal gloves |
| Tony | Sunday Best | Maroon tracksuit, cream stripes, gold zip, green beanie |
| The Catalyst | Verdant Sigil | Dark green robe and hakama trimmed gold, glowing green key pattern on the wraps, gold boot straps |

- **How it works:** every color a skin can change is a named part of the fighter's palette (`Skins.BASE`: vest, trim, sash, glove, wraps, shoes...). A skin overrides the parts it changes (`Skins.LOOKS`), and can set "glow" (the hands' color when the ultimate is ready). `PlayerBody` and `Fists` paint from the palette, and bodies are cached per fighter and skin.
- **Getting them:** one in each Soul Shop restock, 20 Souls (`SoulShop.SKIN_SLOTS`, `Skins.PRICE`), only for fighters you have.
- **Wearing them:** Cosmetics → Skins. Saved per fighter (`GameState.skins_owned`, `skin_picks`; `skin()` / `equip_skin()`). The Emotes stage, the crowning and your fights all show the skin you wear.
- **Later:** parody skins of anime characters.

## Level-ups: the card draw and attributes [Built 2026-10-25]

Replaces the skill webs and the four stats. Why: every skill got bought eventually (33 points, maxed by level 34), so two players with the same fighter ended up identical; most skills and stats were number bumps that the coin web and gear already give; Looting was a trap; and a level-up gave nothing to try.

### The card draw (replaces the skill web)
- **Each fighter has their own deck of 40 cards** (20 different cards):
  - **20 commons:** 5 cards, 4 copies each. Each copy you draw ranks it up (I-IV).
  - **10 rares:** 5 cards, 2 copies each (ranks I-II).
  - **5 epics:** one copy each.
  - **5 legendaries:** one copy each, and each joins the deck only when its Dead League seal breaks (one per contender), so every contender win adds a new possibility. The fighter must also be at the par level for that seal (`Progression.PAR_LEVEL`: 9, 14, 19, 24, 29; `GameState.card_seals()`), so a new fighter in a late save doesn't draw every legendary at level 1.
- **Every level-up draws 3 different cards; you keep 1.** The other two go back in the deck. Draws are even across the copies left, so commons come up most; legendaries count double once they're in. By the Coffin King's par (level 29) you've kept about 28 of the 40, so no two runs of a fighter end up with the same hand.
- **No copies of other systems.** A card never gives what a Sigil power (burn, freeze, lightning, heal on kill) does, or copies a coin-web or gear special or an attribute perk. Commons can give plain stats (damage, knuckle HP, speed). Everything else builds on the fighter's own kit: their moves, passive, ultimate and signature mechanic (the Mauler's super armor, the Answer's counters, the Blur's combo, the Stray's movement, Tony's taunts, the Catalyst's spells).
- **The decks** are in `CARD_DECKS.md` (generated from `cards.gd`): 5 commons, 5 rares, an epic for each of the fighter's 3 passives and 2 ultimates (so a hand pulls you toward a loadout), and a legendary per seal (Ultimate Surge is every deck's Southpaw legendary).
- **Tags** (Counter, Dodge, Combo, Power, Ultimate, Movement) show what a card plays into. Possibly later: set bonuses for collecting several of one tag.
- **Old seal skills:** the capstones and ultimate nodes the skill webs kept behind seals become cards (mostly the legendaries).
- **When you draw:** level-ups mid-fight don't interrupt ("LEVEL UP!  +1 CARD"). Camp opens the draw on arrival when cards are waiting, and the Deck tab and header show how many. The draw screen flips 3 cards face up and you pick one (a common ranking up shows what it does now and next). Unspent draws wait. Past about level 40 there are more draws than cards; the extra draws wait (and don't show) until a swap, redraft or seal gives them something to draw.
- **The Deck page** (where Skills was): drawn cards face up with rank pips, rarest first, then the rest face down by rarity; legendaries still behind a seal stay hidden. The count reads "11 of 37 cards drawn". Click a card for what it does now and at its next rank.
- **Costs (Souls):**
  - Reroll a draw (3 new cards, different ones where the deck allows): 1, then one more each time on the same draw.
  - Swap a card (give back one rank for a fresh draw, without that card on the table): 2 common, 3 rare, 5 epic, 8 legendary. Only with no draw waiting.
  - Redraft (every card back, a draw for each): 15.
- **Loadout stays separate:** passives and ultimates still unlock by level. **Passive power** now comes from level: a point every 4 levels (up to 9), for whichever passive is equipped, default ones included (e.g. -0.3s Perfect Counter cooldown, +0.2x shockwave damage a point). The epic cards each upgrade one passive or ultimate.

### Attributes (replace the four stats)
**3 points a level** across five attributes, **30 points max in each**. Every point gives a small steady bonus, and 10, 20 and 30 points each unlock a perk. At the Coffin King's par (level 29) you have 84 points, enough to max two attributes and go partway in a third, or spread out for more perks, but never everything (maxing all five takes 150 points, level 51).

| Attribute | Every point | 10: | 20: | 30: |
|---|---|---|---|---|
| **Power** | +1% damage | **Heavy Hands:** staggers you cause last 30% longer | **Follow Through:** a punch that knocks a monster out carries half its leftover damage to the nearest monster within 3m | **Knockout Blow:** every 6th punch you land in a combo hits for double and staggers ("KNOCKOUT BLOW!") |
| **Grit** | +1.5% max knuckle HP | **Iron Knuckles:** punches cost 20% less knuckle HP | **Granite Chin:** after you're hit, the next hit within 2s deals half (no beatdowns) | **Get Up:** once a bout, a knockout blow leaves you at 15% knuckle HP instead, untouchable for 2s |
| **Speed** | +0.6% punch speed, +0.4% move speed | **Quick Feet:** dodges and dashes recover 20% faster | **Tempo:** each punch landed in a combo makes the next 2% faster, up to +20% (resets when the combo drops) | **Blur Step:** a clean dodge makes you 30% faster, moving and punching, for 2s |
| **Technique** | +0.4% dodge window, +0.005s counter window (within the caps) | **Read the Tell:** attack tells flash 0.08s earlier | **Clean Break:** a clean dodge makes the attacker stumble for 0.5s | **Precision:** a counter thrown within 0.5s of a clean dodge deals double |
| **Fortune** | +2% coins, +1% XP | **Pickpocket:** elites and champions burst with 3x their coins | **Soul Collector:** bosses drop +1 Soul | **Hat Trick:** monsters wear hats twice as often |

- **Fortune is the tradeoff:** no fighting power, but faster progress (more coins, Souls and hats, and hats are permanent boosts).
- **Resetting attributes** costs coins: 1.5 per point spent x the pay where this fighter's level fights (`Progression.level_position`, never past your climb), minimum 25. A level-7 fighter with 18 points pays about 140; a new fighter in a late save no longer pays Crown prices.
- **Notes:** Get Up is once per bout and has no stun, unlike the Crypt's Long Count gear (once a floor, stuns everything). Technique's per-point bonus and perks count toward the dodge (+25%) and counter (+0.5s) caps like everything else.

### Balance
- **POWER rates cards and perks** (`PowerRating.CARDS`: offense and defense per unit of each card effect, with how often it comes into play baked in; `EVERY` for "every Nth" cards; `PERKS`).
- **Par assumes a typical hand** (`Cards.typical_hand`: the picks spread over the deck by how often each card comes up) and attribute points split evenly over Power, Grit, Speed and Technique. Power and Grit go straight into par's damage and knuckle HP; Speed, Technique, perks, passive power and the hand become one level factor on both (`Progression.level_factor`, averaged over every fighter's deck): x1.25 at the Bellman, x2.44 at the Coffin King. A Fortune build is knowingly a bit under par.
- **What changed for enemies:** the defense stat is gone, so par EHP is about half what it was early on (enemies hit about half as hard in the first two divisions, the same by the Coffin King); par damage is about 20% lower at the Bellman and about 60% higher at the Coffin King, so late monsters have more HP to match the cards.
- **Checks** (`balance_regression`): every fighter at par rates 0.90-1.05 of the contender they face, and every fighter's typical hand is worth about the same (x1.51-1.64 POWER at the Coffin King). `card_runtime_regression.tscn` gives every fighter every card and perk and runs real hits, dodges, punches, powers and both ultimates.

### Old saves
- Every level gained comes back as a draw, and its stat points as attribute points (level 12: 11 draws, 33 points). Camp explains it once (`SKILL_VERSION` 3).

### How it's built
- `cards.gd` (the decks and draws), `attributes.gd`, `card_play.gd` (a node on the player: every card and perk in a fight, called from a handful of hooks), `card_draw.gd` (the draw screen), `card_tile.gd`, `deck_page.gd`.
- Cards are effects (`GameState.get_effect` adds the fighter's cards at their ranks and the attribute points); perks are `GameState.perk(id)`.
- Effects that change a passive or ultimate live with it in `player.gd` and `ult.gd`. Enemies gained `delay` (hold still without a stagger), `scare`, a time slow for every monster, and `tell_time()` (Read the Tell). The Catalyst's cards hear every power go off (`Powers.listener`).
- Jumps past a monster (Phantom Step, Vault) land short of any wall on the way, and stay put if the monster has its back to one (`Player.teleport_spot`), so they never leave the ring or a Crypt room.
- Follow-up counters (Two Answers, Free Flow) go to the other hand: a one-two, never the same hand twice (that would break the combo anyway).
- Phantom Step only answers thrown attacks (teleporting off a melee dodge was disorienting); its epic, Ghost Walk, makes it recharge twice as fast and stuns the thrower for 1s.
- Every scroll box is a `KeptScroll`: spending a point, buying or equipping keeps your place instead of jumping back to the top.

## Multiplayer: the Versus ladder and co-op [Planned 2026-10-25]

Not built yet. Versus comes first (it's cheaper, fits the game, and its networking carries over to co-op).

### Versus
- **Separate fields, one graveyard:** each player fights monsters on their own field, side by side, split by a see-through barrier (a ghostly fence or glowing seal line). Each machine runs only its own fight, so dodges and counters feel exactly like single player and lag never touches combat.
- **Sending:** a monster you KO climbs out of a grave on your opponent's side, with an "INCOMING: Brute" warning about 2s ahead. Elites send elites, champions send champions. To consider: your KOs cancel what's incoming before anything extra goes over (Tetris style).
- **First one down loses.**
- **You see each other:** the opponent's sculpted body (`PlayerBody`, with their hat) is synced about 20 times a second (position, facing). Emotes play in full for them to see, and emoting mid-fight still leaves you open. Optionally their monsters show too, purely as visuals.
- **Real builds:** players fight with their own upgrades and gear (not normalized).
- **No pauses in Versus:** the hat popup, tutorials and level-up cards stay off.

### The ladder (like Clash Royale)
- **Arena points** decide matchmaking, so getting stronger climbs you into better arenas against stronger players.
- **Arenas:** graveyard-themed fields, each bigger and nastier. Each has a floor you can't drop below once reached, and a reward for reaching it (Souls, hats, cosmetics).
- **Points swing by POWER:** the stronger player's expected chance to win is Pa² / (Pa² + Pb²). The winner gains (and the loser drops) 60 × (1 - the winner's expected chance), rounded:

| Matchup | Strong player's win chance | Strong wins | Weak wins |
|---|---|---|---|
| Even | 50% | +30 / -30 | +30 / -30 |
| 2x POWER | 80% | +12 / -12 | +48 / -48 |
| 4x POWER | 94% | +4 / -4 | +56 / -56 |

  Beating someone much weaker barely moves either of you; beating someone stronger pushes you far.

### Co-op
- **One shared Arena field** for both players, with their power balanced against the field: monsters scale to the field and to how many are fighting.
- **Revives:** a downed player crawls with a bleed-out timer while the partner holds interact to pick them up; both down ends the run.

### What it takes
- **Fight animations for the body:** guard, walk and run, jab, cross, hooks, uppercut, slip, roll, back step, getting hit, going down. The body only knows dances now. Versus needs these to show the opponent, and co-op reuses them.
- **Messages for Versus:** sends, HP, downed, body position and emotes. All small, and they tolerate lag.
- **A server:** matchmaking, arena points and a leaderboard, plus a relay so browsers can connect (browsers can't connect to each other directly; desktop builds can). It needs a hosting account (a free tier at first).
- **Identity:** an anonymous ID and a display name kept in browser storage; no full accounts.
- **Cheating:** builds live in each player's save and fights run on their own machine, so a determined cheater can edit a save. The server can reject absurd POWER, but full protection would mean running fights on the server.
- **Bots for empty queues:** an opponent whose KOs are paced by its POWER against the field, with a body that moves and emotes now and then. They fill in after a short wait and may pay fewer points.
- **Co-op specifically:** monsters choose between two targets and stay in sync between machines (the host runs them); each player's own machine decides whether their dodge worked; the world can't pause or slow down for one player (hit-stop and slow-mo become local).

### Phases (rough, in working sessions)
1. **Versus prototype** (3-4): two windows on one PC, real builds, side-by-side fields, the opponent's body and emotes, sending, win and loss.
2. **Ladder** (3-4, plus hosting): server, matchmaking, points, arenas with floors and rewards, leaderboard, web play with room codes.
3. **Bots** (about 1).
4. **Co-op prototype** (4-6); shipping co-op takes weeks.

## Launch readiness [In progress, 2026-10-15]

Checked: every main scene (title, camp, Arena, Crypt, training, Dead League menu and arena) runs 400 frames headless with no script errors, and the web build loads with no console errors (38 MB wasm + 15 MB pck; itch serves them compressed).

Done:
- **Auto-pause:** clicking or tabbing away mid-fight opens the pause menu (`Hud._notification`), so nothing beats you up while you're gone.
- **Credits** on the title menu (`credits.gd`): made by, built with Godot and the Anton font, and the license notices the engine (MIT, plus its third-party components) and the font (OFL) require.

- **Versions and releases (2026-10-16):** the version lives in `project.godot` (`config/version`, now 0.9.0) and shows in the title screen's corner. Every change goes to GitHub Pages as the dev build (`deploy_pages.sh`, the `Web` preset, "DEV BUILD" in the corner). itch only gets a build on release: `bash release.sh <version>` exports the `Web Release` preset (the `release` feature tag hides DEV), pushes it to itch with that version, then commits and tags `v<version>` on GitHub.

Still open:
- Real sound effects and music (placeholders now; the Sound Lab is ready to audition them).
- Painted upgrade and skill icons (`art/icons/ICON_PROMPTS.md`).
- ~~An ending for beating the Coffin King~~ Done 2026-10-25 (the crowning, below).
- ~~Save backup~~ Done 2026-10-25 (save codes, below).
- A full playthrough on the new balance.

## Current build (as of 2026-10-15)

Godot 4.5.1 project in `punch-craft/`, exported for the web to `builds/web` and pushed to itch (isaiahd0221/fright-night:html5).

**Flow:** boot splash, then the Title (`title.gd`: the ring at midnight, class picker with demo reel, Settings, tutorial offer), then Camp (`camp.gd`: Upgrades, Skills, Armory and Stats pages, Arena / Crypt pickers, Dead League). Every scene change goes through the loading screen (`loading.gd`).

**Modes:**
- **Underworld Arena** (`world.gd`): division bouts, purse × style grade.
- **The Crypt** (`dungeon.gd`): floors, chests, gilding altars, stairs.
- **The Dead League** (`dead_league_menu.gd`, `dead_league_arena.gd`, `dead_league_boss.gd`, `dead_league_rules.gd`, `vs_intro.gd`): five contenders, three rounds, seals.
- **Training** (`training.gd`, `dummy.gd`): the coach-card tutorial and free practice.

**Systems:**
- `game_state.gd`: saves, progression, gear, migration.
- `progression.gd`: the Climb (par builds, scaling, pay).
- `power_rating.gd`: POWER.
- `items.gd`: loot, affixes, reroll.
- `controls.gd`: control schemes.
- `settings.gd` / `settings_panel.gd`.
- `ult.gd`: ultimates.
- `powers.gd`.

**Fighting:**
- `player.gd`: movement, punches, dodges, counters, the knockout fall.
- `fists.gd`.
- `enemy.gd` / `boxer.gd`: shared AI, turns, finisher launches.
- One script per enemy type.

**Look and juice:**
- `look.gd`: block materials, fire, batching.
- `scenery.gd`: graves, fence, crypt, sky, mist.
- `post_fx.gd`, `time_fx.gd`, `hit_fx.gd`, `damage_popup.gd`.
- `sfx.gd`: synthesized placeholder sounds, until real audio arrives.

**UI:**
- `hud.gd`: top row, ultimate gauge, results cards, pause.
- `ult_gauge.gd`, `game_dialog.gd`, `ui_theme.gd`: the shared theme and card.
- `icons.gd` / `icon_view.gd`, `skill_tree_view.gd`, `resource_chip.gd`, `icon_label.gd`.

**Art:**
- `art/dead_league/`: key art, contender portraits, locked shadows, portrait prompts.
- `art/fighter_*.jpg`.
- `splash.png`, `icon.png`.

**Tests:** `balance_regression.tscn` and `dead_league_regression.tscn` (run headless with `FRIGHT_NIGHT_SAVE` / `FRIGHT_NIGHT_SETTINGS` pointing at test files).

**Climb balance check:** run `balance_report.gd` (headless, test save) for par per tier, what each seal ring adds, and every class's POWER against each contender. After the 2026-10-15 revamp every class rates 0.94-1.13 of its contender at par, and `balance_regression` keeps it there.

The old fist models and scenes (`fist.tscn`, `sketchfab_scene.tscn`, the `.glb` fists and their textures, about 93 MB) were moved out of the project to `../unused_assets/`.

## Audit polish (2026-10-26)

- Soul Shop emote and skin cards: taller stages (124 px), so the dancer reads.
- Hat Rack thumbnails rendered for Fast Quills, Pocket Trainer Cap, Straw Hat and Rebel Cap.
- The Answer's Perfect Counter trait: "Counter for x2.5."
- New ability tip: "Equip it in your Loadout. Its cards join your deck."
- Loadout and Hand Idle cards: the equipped one is lit in the fighter's colour with a gold rim; the rest are grey-rimmed and dimmed (Tony's gold tint made them all look equipped).
- Deck and Attributes tabs wear a pulsing count badge (like Daily's READY) when draws or points are waiting.
- The Mauler's mitts sit a little lower (`Fists.SIT`) so they don't fill the view.
- Dead effects removed (nothing granted them since the skill webs went): wise_up, fugget_cut/heal, hustle, body_bonus, liver_shot, double_jab, the super-armor set, power_amp, spell_chance/damage, burst_*, perfect_cooldown_cut, counter_free_bonus, boss_ko_bonus, shockwave_*, opener_bonus, finisher_threshold, pound_radius/stun. `ult_power` stays as the ultimates' empower hook.

## Balance pass (2026-10-27)

- **Brimstone Shield:** Brimstone Wall now adds 1 hit (was double). A boss's punch takes 2 hits off the shield.
- **No stun-locks:** a run of punch staggers holds a monster at most 1s (`Enemy.STAGGER_CHAIN_MAX`), then punches can't stagger it for 1s (`STAGGER_GRACE`). Single staggers are unchanged (0.5s). Bosses keep their poise. The Blur's Stun Lock card is gone.
- **The Mauler's AoE, cut hard:** Haymaker Swing hits the arc for 20% / 35% of the hook (was 50% / 100%); Avalanche deals a quarter of base damage and only staggers (no knockdown); Wrecking Ball bowls for 1.1x base (+0.2x a passive point; was 2.0x / 0.3x), Strike! keeps them down 1.3s (was 2s); Blood Feud's crowd stun is 0.3s; Mob Magnet +2-5% a monster, up to 3.
- **The Blur's new cards:** Keen Eye (common, +3-12% crit chance) and Vital Points (common, +15-60% crit damage) replace Through and Through and Endurance; Light Hands (rare: jabs and crosses 30% free; rank II adds hooks) replaces Stun Lock. Cards a save had of the removed ones come back as draws.
- **Crypt gear gives no elemental powers** except the Quaking boots' landing shockwave and Venomous gloves. Burning gloves became +damage% gloves, Storm charms +ultimate gain charms, frost-slip boots are gone; old ones in a save turn into those on load (`Items.retire_powers`). The landing shockwave has a 4s cooldown.
- **Contenders:** Sister Southpaw's pivot takes 0.55s (was 0.24s) and gives 0.35s to turn. The Plague Doctor hops back 3.5m before his Adrenaline Shot. The Headless specials come every 6.5s (was 8.5s) and only 35% are charges; from round 2 it catches its skull and throws it straight back (once in round 2, twice in round 3).
- **Power web:** the four powers moved to the corners of the upgrade web with their own branches (see the Sigil nodes section).

## Rigged bosses (2026-10-28)

The five Dead League contenders and the three Crypt floor bosses (Grave Champion, Bone Colossus, Lich King) stand on a real skeleton: the playground Character Lab's 29-joint rig and its procedural clips, ported into the game as `BossRig` (`boss_rig.gd`).

- **Look:** still the game's simple blocks, just more of them and modeled after each portrait. They sit on the bones, not on a fighter's PlayerBody sculpt.
  - **Bellman:** stone ball joints with molten rings and a gold bell.
  - **Headless:** an open ribcage, blue ghost-fire, the floating skull and a ragged navy skirt.
  - **Sister Southpaw:** habit, veil, white band, gold chain and wrapped fists.
  - **Plague Doctor:** a long hooded coat, beak mask and a belt of vials.
  - **Coffin King:** a crowned skull, ermine collar, ribcage under gold chains, gold gloves and greaves.
  - **Grave Champion:** stitched grey hide, horns, a champion's belt and purple gloves.
  - **Bone Colossus:** mismatched bones, the core in an open ribcage, skulls on the shoulders, shackles and a tombstone loincloth.
  - **Lich King:** a robe and cape, crown, amulet and a tall orb staff.
- **Movement:** real hips, knees, shoulders and elbows. Footwork drives the walk, strafe and run cycles from velocity. Skirts and coat tails ride the thighs, and capes and sashes sway.
- **Style:** each body has its own guard and idle: the Bellman and the Champion stand heavy, Southpaw is tight with a southpaw stance, the Headless floats, the Plague Doctor hunches, the King stands proud and the Colossus lumbers.
- **Punches:** each windup holds a load pose, then the lab's punch clip starts so it lands on the strike (`Boss.PUNCH_LEAD` / `PUNCH_PEAK`).
- **Boss clips:** slam, sweep (the Colossus), slips, flinches away from the hit, staggers and dazes, crouch / airborne / land for leaps, brace for charges, cast, the Headless's skull toss, the Plague Doctor's needle, and the Lich King raising his staff for each cast. They go limp when knocked out.
- **AI:** unchanged (timing, tells, hitboxes, specials). The AI keeps bare arm pivots for its timing. Its "forearms" are the rig's hands, so tell lights, glove glow and Crypt gear ride on the fists, and hats sit on the head bone.
- **Title screen:** the contender preview drives the same rig.
- **Bosses wear no armor:** the Grave Champion, Bone Colossus and Lich King show only their own bodies, and the contenders never had any. Armored spawns and Crypt gear still give them their armor and HP, but nothing is drawn on them (gear style "bare"), so the Colossus core still pierces its armor.

## The Endless powers (2026-10-28)

Four more powers, one past each spoke of the upgrade web: **Quake north, Gale east, Iron south, Doom west**. Each is a diamond: a Sigil, three branches, and a capstone where they meet. The four elements keep the corners. The corners moved two cells farther out each way (each element's Sigil at (5, 5) from the center, its capstone at (8, 8)), so all eight sit around the core with space between.

**Unlocks:** each Sigil opens when you **win that division's endless bout** (bout 3, 50 knockouts) for the first time: Gravedigger opens Quake, Bone opens Gale, Ghost opens Iron, Plague opens Doom (`"endless"` on the node, `GameState.endless_won`). Saves that already won them have them open. The win's feed says "X UNSEALED". Sealed Sigils read "SEALED - win the GRAVEDIGGER ENDLESS". Their branch steps follow the seal rings like the elements' (each step one ring later, the capstone in the Crown ring).

**One power at a time:** any fighter selects one of the eight. The Catalyst's Dual Sigil can pick any of them, and Prism now runs **four** at base level (not all eight). Elemental Fists still rolls only the four elements.

| Power | Base | Branches | Capstone |
|---|---|---|---|
| **Quake** (Earthbreaker) | Landing from a jump (0.3s+ in the air) sends a shockwave around you: 0.8x base damage, staggers, knockback, 3m. 4s recharge. Quaking boots then add 1m of reach instead of their own pound. | **Force:** Heavy Landing, Bedrock (more damage), Seismic (knocks monsters down). **Reach:** Wide Stance (+0.75m), Fault Line (also cracks 6m forward in a line). **Rhythm:** Drumbeat (4% a level a landed punch stomps, 1s apart), Short Fuse (-0.75s recharge), Tremor (stuns 1s). | **Aftershock:** the ground stays cracked 3s and slows monsters in it 40%. |
| **Gale** (Windcaller) | A clean dodge gives 2 charges, any other dodge 1 (hold 3). Every punch thrown with a charge spends one and fires an air burst straight ahead from that fist: 50% of the punch, 8m, through everything in its line. | **Force:** Gust, Gale Force (more damage), Buffet (bursts stagger). **Reservoir:** Deep Lungs (+1 charge, to 5), Tailwind (dodges give one more). **Shape:** Long Wind (+3m), Crosswind (hooks fire a fan of three), Updraft (uppercut bursts knock monsters off their feet). | **Cyclone:** spending your last charge blows everything within 3.5m back. |
| **Iron** (Forgeborn) | Plates, up to 3: every 5 landed punches and every clean dodge forges one. Each plate cuts damage taken 8%; a hit breaks one (a boss's hit two). | **Plating:** Plating (+1 plate), Tempered (+0.5% a plate a level), Riveted (boss hits break one). **Forge:** Forge (one punch sooner a level), Anvil (any dodge forges). **Spikes:** Spikes (a breaking plate staggers the attacker), Barbs (and hits it for 0.5x base a level), Shrapnel (and everything within 2.5m). | **Unbreakable:** with every plate up, a knockout blow leaves 1 knuckle HP (once a minute). Max cut: 4 plates x 9% = 36%. |
| **Doom** (Death Mark) | Set-up heavies and counters mark the monster for 3s (a glowing skull over it). When the mark runs out, 30% of everything it took meanwhile hits it again, through armor. | **Dread:** Dread, Death Knell (a bigger share), Reckoning (the burst staggers, bosses too). **Long Shadow:** Long Shadow (+1s a level), Dead Weight (marked monsters deal 25 / 30 / 35% less, a faint purple glow). **Hex:** Hex, Evil Eye (any punch can mark), Pall (a mark also lands on the nearest other monster). | **Reaper:** a Doom burst that knocks a monster out passes the mark to the nearest one. |

- **HUD:** a power chip over the passive chip shows Quake's recharge (READY), Gale charges and Iron plates (`PowerPlay.status`).
- **Code:** `power_play.gd` (Gale charges, Iron plates, Quake landings and stomps), `air_burst.gd`, `Powers.ground_pound` (with Quake's reach, knockdowns, Fault Line, Aftershock), `Powers.doom_mark` / `doom_burst`, `Enemy.doom`.
- **Colors:** Quake sandstone, Gale mint, Iron steel, Doom dark purple.
- **Balance:** par ignores them (they hold no damage, knuckle or defense nodes; they are optional side power). POWER weighs them (`power_rating.gd`), and the Catalyst's amplifying covers their numbers (not Iron's plates).
- **Tests:** `balance_regression` (seals, Prism's four), `card_runtime_regression` (each power in a real fight).

## Seal rings: the upgrade web laid out by seal (2026-10-28)

**Layout:** the core upgrade web is radial. Every node sits on the ring of the seal that opens it (ring 1 open from the start, ring 2 with the Bellman, up to ring 6 with the Coffin King), ring r at r + 0.5 cells out, drawn as dashed circles that brighten once their seal breaks. The four spokes run straight out (damage east, defense south, knuckle HP west, coins north); side branches sit on their ring beside their spoke, so a branch steps outward one ring per seal. The eight powers sit outside the rings (elements in the corners, Endless powers past the spoke ends). Fighter skill webs keep their grid.

**Branches (merges):** Dirty Shot merged into Lucky Shot (5 levels of +5% crit; a save's Dirty Shot levels join it). Healing between waves is one chain off the knuckle HP spoke (Cornerman, Ice Bath, Second Wind), XP one chain (Sparring Partner, Film Study), graze reduction one chain off defense (Thick Skull, Rope-a-Dope). Jump Rope and Bob and Weave sit with defense, Speed Bag with damage, the speed nodes with coins. The Trophies are gone from the web: they live in the center node (below).

**Round numbers** (per level, 5 levels; coins 3):

| Spoke | Tiers 1 to 6 | Full spoke |
|---|---|---|
| Damage | 1, 1, 2, 3, 4, 6 | 85 |
| Knuckle HP | 5, 10, 15, 20, 30, 40 | 600 |
| Defense | 0.5, 1, 1, 2, 2, 3 | 47.5 (each point is about +10% effective knuckle HP) |
| Coins | 5%, 5%, 5%, 10%, 10%, 15% | 150% |

Side nodes: Haymaker 10%, Rib Shot 15%, crit 5% a level, Jump Rope 0.05s, Snap Wraps 5%. Trophies: Bell 2 damage / 10 HP, Helm 2 / 15 / 1 defense, Veil 3 / 20 / 2, Censer 4 / 30 / 2, Crown 5 / 40 / 3.

**Prices** round to two figures at every level (`GameState.price_at` / `nice_price`): 80, 100, 120, 150... never 102 or 153. Spokes start at 80 / 400 / 1,600 / 8,000 / 60,000 / 300,000 by ring (defense 1.5x, coins 100 / 500 / 2,000 / 10,000 / 75,000 / 380,000), x1.22 a level; side nodes 130 / 550 / 2,000 / 9,400 / 36,000, x1.3; Trophies 900 / 3,500 / 15,000 / 110,000 / 800,000; capstones 500,000.

**Balance:** about the same as before: 2.0 / 3.3 / 3.2 / 2.3 / 3.0 good bouts to reach par by tier (was 2.0 / 3.1 / 2.9 / 2.6 / 3.1), class POWER unchanged. The bouts-to-par check leaves out the Endless powers (optional; par ignores them).

**Old saves:** upgrade web version 8. Bought levels are kept (same ids); any level that got cheaper refunds the difference (`V7_PRICES`).

**The center node grows with every contender (2026-10-28):** Taped Up stands for the Trophies. It starts at one level; each contender beaten raises its level cap by their Trophy (the Bellman's Bell +3, Headless Helm +3, Southpaw's Veil +3, Plague Censer +3, the Coffin Crown +5: 18 levels in all). It shows and buys the first stage that isn't maxed, taking that Trophy's name, icon and numbers (Bell 2 damage / 10 HP a level up to Crown 5 / 40 / 3 defense), so its icon changes as you climb: wraps, bell, helm, medal, censer, crown. Each stage needs the last maxed. The Trophy nodes keep their ids (saves keep them) and are drawn through the center (`GameState.CENTER_STAGES`, `center_stage`, `center_levels`, `shown_node`).

**All eight powers 9 cells out:** the Endless powers' Sigils sit 9 cells out on the axes and the elements' 9 cells out on the diagonals, so all eight ring the core at the same distance with room for their names.

**Links follow the rings (2026-10-28):** a link between two nodes on the same seal ring curves along that ring; every other link runs straight out from the center, so nothing cuts across on a slant (`SkillTreeView._link_path`). Side branches are small spokes: the first node steps off its spoke along the ring, the rest run straight outward at that angle. Branches that start on a later ring sit nearer their spoke, so no ring arc passes through another node.

**Even rings (2026-10-28):** every seal ring is evenly spaced: 8 nodes on rings 1 and 4 (45 degrees apart), 12 on rings 2 and 3 (30 apart), 16 on rings 5 and 6 (22.5 apart). Every side node sits on the ring it always had (its seal and price unchanged) and hangs off its spoke by an arc along the ring; no link runs on a slant.

| Ring | Side nodes (clockwise from damage) |
|---|---|
| 1 | Jump Rope, Cornerman, Twinkle Toes, Sparring Partner |
| 2 | Haymaker, Bob and Weave, **Head Movement**, Ice Bath, Chin Check, Cemetery Sprint, Snap Wraps, Speed Bag |
| 3 | Lucky Shot, Thick Skull, **Rolling Guard**, Second Wind, Calloused, Crowd Pleaser, Film Study, Counterpuncher |
| 4 | Glass Breaker, Rope-a-Dope, **Iron Lungs**, Can Opener |
| 5 | in-between stat nodes, plus Bigger They Fall, **Unflinching**, Prize Fighter, Lead Tape |
| 6 | in-between stat nodes, plus **Granite Chin**, **Grave Wind**, **King's Purse**, **Old Master** |

New upgrades (bold) fill the slots: Head Movement (+0.05s dodge window, 2 levels), Rolling Guard (+0.1s counter window, 2), Iron Lungs (wave heal, 2), Unflinching (-15% flinch, 2), Granite Chin (-10% graze, 2), Grave Wind (wave heal, 3), King's Purse (+25% wave bonus, 2), Old Master (+15% XP, 3).

**In-between nodes on rings 5 and 6:** halfway from each spoke to the diagonals, two per spoke a ring, each half its spoke's stat for 2 levels at half the spoke's price (ring 5: Knuckle Dusters, Heavy Hands +2 damage; Iron Jaw, Stone Wall +1 defense; Scar Tissue, Old Wounds +15 knuckle HP; Tip Jar, Back Pay +5% coins. Ring 6: Coffin Nails, Death Grip +3; Crypt Door, Vault Guard +1.5; Grave Skin, Deathless +20; Gold Teeth, Royal Treasury +5%). The diagonal node on the spoke's side of each ring-5 and ring-6 quadrant chains through it.

Haymaker absorbs Rib Shot (5 levels of +15% set-up heavies) and Counterpuncher absorbs Return Fire (5 levels of +30% counters); saves' levels in the absorbed nodes join them. Lead Tape (the web's only one-level node) is a square like the rest. Bouts to reach par: 2.0 / 3.7 / 3.3 / 2.3 / 3.5 (the ring-5 in-betweens make the Coffin King's par a bit higher).

**Power diamonds:** all eight powers use the same diamond (Sigil, three branches of 3, 2 and 3 nodes, the capstone at the far tip), 1.3 cells a step. Every diamond points straight out from the core: the Endless powers along their axis, the elements toward their corner (9 cells out on the diagonals). Each power's name sits between its Sigil and the core.

## Won hats and Intense Yelling (2026-10-28)

**Power hats (epic, won by maxing every node of a power; each makes that power 10% stronger):** Hot Plumber Hat (Fire: burst and burn), Air Force Flattop (Gale: air bursts), Electric Mouse Ears (Storm: lightning damage), Armored Faceplate (Iron: each plate cuts 10% more), Snow Queen Tiara (Frost: slow and Brittle), Evil Doctor Mask (Doom: the stored share), Drawn-On Hairline (Blood: heals), Earth Warrior Headband (Quake: shockwave damage). The boost lands on that power's own numbers (`GameState.HAT_BOOSTS`, `_hat_boost`).

**Legendaries (won, never dropped):**
- **Golden Fast Guy Fleece Cap:** max every power. Every power 10% stronger (stacks with their hats).
- **Bald Hero Cap:** one punch for 10,000+ damage (2026-10-30: was 250 base damage or one punch for 15x base, which an early perfect counter cleared in the first minute). +10% damage, +25% crit damage.
- **Speedster Cowl:** +30% move speed and +30% punch speed. +8% move speed, +6% punch speed.
- **Strong Guy Wig (White)** (was a dropped epic): max your dodge window (+25%), counter window (+0.5s) and combo time (+1s, a new cap on gear's combo time). Raises all three caps 5% and stretches all three windows 5%.

All of these are `Hats.TROPHIES` (never on monsters). `Hats.check_awards` hands out what a build qualifies for, with the hat popup: after buying an upgrade and whenever camp refreshes; the big punch is checked as it lands. The Bald Hero Cap, the Drawn-On Hairline (marker-black top and sides, a triangle widow's peak, square sunglasses) and the Air Force Flattop (a short flared flat top, the sides bare) take the fighter's own hair off (`"bald"`: PlayerBody's hair is split into top and low parts; a bald hat hides both).

**Intense Yelling (emote, from the Over Nine Thousand achievement: reach 9,001 POWER):** a wide power-up squat, fists down, head back, shaking. A golden aura grows the longer it's held (`PowerUpFx`, full at 9s); from 3s rocks tear off the ground and float up; from 6s lightning strikes around you. The first time it's held a full minute, it all cuts out and a poop drops: the Pushed Too Hard achievement and the **Overexerted** emote (the strain with no aura, the poop, the slump of relief; `PoopFx`). Both emotes are achievement-only (the Soul Shop never sells them).

## The plumber quest (2026-10-28)

A secret quest line off the Overexerted poop.

1. **The toilet room [Built]:** once you have Overexerted, each Crypt floor has a 1% chance (`Dungeon.TOILET_CHANCE`) of a side room with nothing in it but a toilet under a bare bulb. Poops dropped within 1.8 m go in (`PoopFx._toilet_near`); the water rises and browns, and the third clogs it. The doors seal and the **Angry Plumber** comes for you: a zombie champion (Brutal, Hulking) at Crown-arena strength (Arena division 5, bout 1, or the floor's own if deeper), in overalls and the **Fat Plumber Cap** (red, a wrench patch; +0.5 defense, +3% damage). Plumbers only go down to an uppercut, so the cap always comes off. The toilet can be clogged again.
2. **The other caps [Built]:** owning the Fat Plumber Cap is the only key. Then 4% of wraiths spawn in overalls and the **Tall Plumber Cap** (green, a plunger patch; +4% move speed, +3% punch speed), ghoul brawlers in the **Very Tall "Plumber" Cap** (purple, a drop patch; +3% dodge window, +2% move speed) and bruisers in the **Very Fat "Plumber" Cap** (yellow, a coin patch; +3% damage, +3% knuckle HP), each only while you're missing it (`Hats.plumber_for`, `EnemyGear.overalls`).
3. **Family Business [Built]:** all five plumber caps (with the Hot Plumber Hat) earn the **Plumber Jump** emote (a crouch, then straight up, one fist at the sky, one arm down, a knee tucked) and Tony's **Plumber Overalls** skin (red flannel shirt, work denim bib and straps with brass rivets, his own hand tape, dark work boots). Both are earn-only (`Achievements.EARN_ONLY`, `Skins.EARN_ONLY`).
4. **The secret ending [Built]:** beat the Coffin King as Tony in the overalls and the Fat Plumber Cap (`SecretEnding.qualifies`). After any crowning: Tony jumps (YAHOO!) and shuffles, swings the Coffin King round by the ankles and throws him out of the building ("GET LOST, YOU MOOK!"), a little brown-capped mushroom man with a grey moustache hops in ("Ayo! Ya princess? Wrong castle, pal."), Tony says "Get the #%^* outta here!" and uppercuts him into orbit. **True Ending?** (an achievement with no dance). Rewatch from the Dead League menu.
5. **True Coffin King [Built]:** the secret boss, to rescue Princess Plum. The League menu shows a TRUE COFFIN KING button once you have True Ending? (`GameState.true_king_bout`, the same arena). Scaled to a near-maxed build (`Progression.true_par`: 90% of every power level in all six rings at the top par level, about 1.7x the Coffin King's par damage and 2.6x his effective HP), five rounds. In each of the first four, at half HP he hops out over the ropes and tags in the next contender (the Bellman, the Headless, Sister Southpaw, the Plague Doctor), at round-3 strength with his damage and 60% of his HP (`DeadLeagueBoss.empower`). When they fall he hops back in at the HP he left with. Round 5 he goes **Insano** (`go_insano`): combos of six to eight punches, super armor through every punch of them, 15% quicker tells, a crimson aura. The ring burns too (`InsanoFloor`): every 3 to 4.5 seconds half of it (a side, two opposite corners, the edges or the middle) glows for 1.3s, then burns for 2.6s (a third of his punch every 0.4s you stand in it). The win: "THE TRUE KING FALLS / PRINCESS PLUM IS FREE" and the **Thank You, Tony!** achievement. The first win plays **the rescue** (`PrincessRescue`): your fighter breaks the gold chains on a standing coffin, Princess Plum (a plum gown with a gold hem, dark hair up, a gold circlet with a plum leaf) steps out and isn't impressed ("Took you long enough." "Traffic."; in the overalls: "...Are those overalls?" "Long story. There was a toilet."), and walks herself home. Rewatch from the League menu.

## Parody, not copies (2026-10-28)

The jokes nod at famous characters; they never copy a mark. Not legal advice, just how we keep the risk down:
- **No logos, emblems or letters** that stand for a character (the plumber caps carry tool patches: flame, wrench, plunger, drop, coin), no slogans ("Gotta punch 'em all" is gone), no names.
- **No exact costumes.** Mix generic pieces of the type instead: Tony's overalls are real work clothes (flannel, brass rivets, boots, his own tape), not the red-shirt, yellow-button, white-glove set. The mushroom man is a brown bolete with a moustache and a green waistcoat, not a white cap with red spots. Princess Plum is her own design.
- **No famous lines word for word**: paraphrase into our own voice ("Ya princess? Wrong castle, pal.").
- Ideas, poses, moves and colors on their own are fine: the jump, the swing throw, red and green caps.

**Nintendo pass (done):** plumber cap letters → tool patches; the Hot Plumber Hat's M → a flame; Electric Mouse Ears → **Bootleg Mouse Ears** (a knock-off: brown tips, a cheap plastic band, a little bolt; "Not from the official store."); Pocket Trainer Cap → **Bootleg Trainer Cap** (the white and red cap, a green leaf patch where the league logo was; "Catch 'em? Punch 'em." instead of the slogan). Parodies should still read as parodies: a knock-off of the look, minus the exact marks; the overalls, the mushroom man and the princess line as above. Hat Rack thumbnails re-rendered (the won hats have thumbnails now too).

**Still to review (other companies, the user's call):** Fast Guy Fleece Cap and the golden one ("seven shiny rocks"; Sega), Air Force Flattop (Capcom), Armored Faceplate (Marvel), Evil Doctor Mask (Marvel), Snow Queen Tiara and "the cold never bothered her" (Disney), Strong Guy Wigs and Over Nine Thousand (Dragon Ball), Straw Hat (One Piece), Rebellious Guy Hat ("Good grief"; JoJo), Bald Hero Cap ("Ok."; One Punch Man), Speedster Cowl (DC), Earth Warrior Headband (Nickelodeon), the Yonker caps (a navy cap with a white Y; baseball).

## Power cooldowns and louder procs (2026-10-28)

Powers that a punch sets off now have a **cooldown on top of their chance** (`PowerPlay.COOLDOWNS`), so they land as moments instead of a constant fizz: Fire 1.5s, Frost 3s, Storm 1.5s, Blood 2s, Doom 4s. A big hit still skips the chance but not the cooldown. Gale (charges from dodges), Iron (a plate every 5 hits) and Quake (its own 4s landing and 1s stomp) were already self-limiting. The Catalyst's cards set powers off regardless (that's the card).

**Making them apparent:** every power that goes off shouts its word over the target in its color (IGNITE!, FREEZE!, CHAIN!, DRAIN!, DOOMED!) with a ring at its feet (`Powers._callout`); the screen edges flash the power's color and the HUD power chip pops. The chip now lists every running power with READY or its countdown.

**Follow-up (2026-10-28):**
- **Doom** went off only once on a monster you kept hitting: a proc on a marked monster reset its timer to full, so steady hits (4s cooldown, marks up to 5s) kept it from ever bursting. Now a proc on a marked monster **detonates** the mark (`Enemy.detonate_doom`) and starts a fresh one.
- **Iron plates float**: one plate per plate you have, circling you low and wide (so in first person they ride the bottom of the view), bobbing, with a soft iron rim; they burst off as they break (`PowerPlay._show_plates`).
- **Burning and frozen monsters look it**: flames and embers rise off a burning body with a flickering orange light; a frozen one wears an icy blue sheen with ice drifting down (`Enemy._status_particles`, `_set_frozen_look`). Both fade when the status ends or the monster drops.
- **Blood drains**: red drops pull out of the target and fly into you, then a red pulse at your feet (`Powers.blood_drain`).
- **Power tiles, bottom right** (`PowerTiles`, replacing the bottom-left chip): one tile per selected power with its icon, glowing and breathing in its color while it can go off, dim while it recovers; READY or the countdown under it, and pips for Gale's charges and Iron's plates. A tile pops and the screen edges flash when its power goes off.
- Character Lab (playground): after a knockout the avatar now gets back up once you're revived (it waited for a punch or jump).
- **No stun-locks, part 2:** the Blur could still lock monsters: the 5th-hit shockwave stuns for 1.5s, and stuns skipped the punch-stagger cap, so a fast Blur refreshed it before it ran out. Now once a stun wears off a monster shakes off new stuns for 2s (`Enemy.STUN_GRACE`; bosses keep their poise). Covers every stun: shockwave, lightning, Quake, cards.

## Boss punches you can read (2026-10-28)

The rigged bosses' punches were small and snapped (a slight load pose through the windup, then a short clip started right before the hit, from rest), so they were hard to read and the tell glow lit an arm that wasn't visibly wound. Now every punch is one motion driven straight from the fight's timing (`BossRig.set_swing`, `Boss._drive_rig`): a big coil through the windup (a jab chambered at the chin, a cross pulled way back with the shoulder turned away, a hook looped out wide, an uppercut dipping low with the knees bent; slams and sweeps raise and wind), fully loaded and trembling by the time the glove flashes, the swing in the last 0.12-0.22s so it connects exactly as the hit lands, an overswing through the strike, then a settle back to the guard. One punch eases into the next in a combo. The tell lights ride the fists, so the glow is on the wound-up glove and travels with the swing. The Headless's skull floats just over the neck flame (it sat down in the chest).

## Solid buildings and fences; the Headless's head (2026-10-28)

- **Collision:** fences (every `Scenery.fence` run: the graveyard ring, the Carnival's fairground fence, camp and the Dead League backdrop), crypts and mausoleums (`Scenery.crypt`), the Carnival's tents and carousel, and the Ossuary's skull pillars are solid now (`Scenery.solid`). Small props (graves, rocks, crates, bone piles) stay walk-through so nobody snags on clutter. Crypts lost the cross on the gable (house rule: no religious symbols) for a stone urn.
- **The Headless's skull** sank into its chest in a real fight: its bob used a resting height filled in a deferred step that hadn't run yet (0, the neck joint). The height is set when the skull is built now; it floats just over the neck flame.
- **Playground:** PASSIVE and ULTIMATE pickers for the fighter (any of them, whatever the level; the ring reloads to start it fresh), and the HUD's power tiles are wired up there too.
- **Later contenders read slower:** with the big swings, the Plague Doctor and the Coffin King were almost impossible to react to. Every windup of theirs gets a flat +0.06s (Plague Doctor) / +0.075s (Coffin King; first tried at double, too slow) on top of their scaling (`DeadLeagueBoss.WINDUP_PAD`, `Boxer.windup_pad`), spent in the coil and hold; the flash-to-hit time is unchanged. The True Coffin King and his tag-in Plague Doctor get it too.

## Roadmap: the user's to-do list (2026-10-28)

A planning list, not a work order: nothing here gets built until the user picks it.

1. **The Catalyst's runes [Planned]:** runes around him by passive: one big rune for the single power, two medium for two powers, four for Prism's four. Each glows its power's color.
2. **Flame Burst ultimate [Planned]:** a very dramatic, big AoE explosion that sends regular enemies flying.
3. **Tony's family [Planned]:** better fighting rigs and skull-cracking hits. Fix Tony's bald spot.
4. **Emotes [In progress]:** the pipeline is built (Emote pipeline, 2026-10-30); next, redo every emote from the user's sources and add new ones.
5. **No stun-locks, anywhere [Planned]:** audit that no fighter, power or card can stun-lock bosses or monsters (stuns, staggers, freezes, knockdowns, card effects), with tests.
6. **Balance check per fighter [Planned].**
7. **Playground [Planned]:** easier controls, a skin picker, and set upgrade tiers to test at different power levels.
8. **The Tower and Rebirth [Planned]:** see "The Tower and Rebirth (plan, 2026-10-29)" below. It replaces the old "Elite" prestige idea.
9. **Multiplayer [Planned]:** the Versus prototype (Phase 1 of the plan above). A first draft is parked on the `versus-prototype-wip` branch (Net autoload over WebSockets, a camp lobby, the graveyard split by a seal line, KOs sent across, first down loses); not reviewed, tested or merged.
10. **New looks [Planned]:** updated KO screens, the camp background and the title screen.

## Roadmap: priority order from the 10/30-11/4 playtest [Planned, 2026-11-01]

Notes from the user's playtest week, put in order. Nothing here is built yet. More characters still to test (the Blur was played first).

1. **Controls patch [Built 2026-11-02]:** see "Controls patch (2026-11-02)" below.
   - Controller binding and unbinding is wonky: jab and cross threw hooks until the save was deleted (stale bindings or modifier state). Intended: Square = jab, Triangle = cross; hold LT + Square / Triangle = left / right hook; hold RT + Square / Triangle = left / right upper.
   - Shift + Q / Shift + E roll as the default scheme (check what it is now); add Shift + S as a backstep ("pro gamer mode"); a roll dodges projectiles.
   - Alternating hands quickly gives mostly jabs (punch input and timing).
2. **Balance fixes** (see "Rebalance plan" below): combo drill rewards, boss power targets, a defense curve (before the new gear), combo multiplier, Grave Champion's punch speed, Shield bearers, card toggles, power upgrade costs, soul shop free refresh, hat and toilet spawn rates, the Stray's stomp chain, and per-character gold and power upgrades (own milestone: it changes the save).
3. **Bug fixes:** the boss room spawn bug (maybe a toilet room: test with `Dungeon.force_toilet` over many floors), the Yonkers description, save codes too long to type by hand (copy and paste works in game; pasting outside the game is untested).
4. **Crypt revamp** (see "Crypt revamp plan" below), in order: room furniture, the gear system, drop odds / store cards / salvage, mimics and elite mimics, the toilet and merchant tie-in, item models, then re-run the balance.
5. **Character dialogue and the ultimate aura [Planned, announced]:** every fighter gets their own dialogue (when the lines play and what they say are still to be decided). When the ultimate is ready the fighter shows their aura, like the one in the trailer when they power up in third person while emoting (`EmoteFx` aura). Both are teased in the announcement for the coming week.
6. **Later / on hold:** a mobile build (see "Mobile build" below), boss patterns and windup padding (after the power balance is tested; windup padding is now by tier for every boss, see "Boss pacing and the power shift" (2026-11-03)), a 6th set (Haunt, for the Catalyst), the super crit power, the boss soft damage cap.
7. **Marketing:** devlogs always include screenshots (the user waived them for the v0.9.19 devlog).

## Controls patch (2026-11-02)
- **Controller heavies:** hold LT with Square / Triangle (X / Y) for a left / right hook, RT for a left / right uppercut (`Player._punch_type_for`). The triggers no longer punch on their own. Why: on a controller the punch type still read the keyboard's Shift + click rule, where Sprint is the hook modifier, and Sprint is the left stick click, so holding it while running turned every jab and cross into a hook. Keyboard modifiers never count on a controller now. Hints read "LT + X / Y" ("L2 + Square / Triangle"), and the combo drills ask for the hand on a controller too (`Controls.hand_heavies`).
- **Shift + Q / E rolls are the default** Pro Gamer Mode scheme (`Settings.DEFAULTS.dodge_mode`); settings still on the old default (Space + direction) move over once (`controls_version` 2). **Shift + S back steps** in that scheme (changed from Shift + D the same day), alongside double-tap S; the S press doesn't walk you back.
- **Rolls dodge projectiles:** arrows and fireballs (bolts, skull shots) can be rolled under as well as slipped (`Player.ANSWERS`).
- **Mashing alternates:** the punch buffer holds one press per hand; when the cooldown ends, the other hand from the last punch goes first. Before, one slot kept only the latest press, so fast alternating often threw the same hand twice.
- Checked in `balance_regression` (keys, hints, defaults, projectile answers) and `card_runtime_regression` (Shift + S, controller heavies, the buffer).
- **Tutorial fixes (same day):** rolling under an arrow counts as a slip in SLIP THE ARROWS (it only counted for ROLL steps, so rolled arrows never filled the goal); and a fight step whose monsters are all down before the other goals are met (the skeleton knocked out before its two slips, the brawler before three dodges) brings in another set after a second ("ANOTHER ONE!") instead of stranding the step with nothing left to dodge.
- **Jab after cross:** a jab thrown right after a cross (combo still alive) hits x1.3 (`Player.JAB_AFTER_CROSS`, the cross's own multiplier); any other jab (after a jab, a hook, or with the combo gone) stays x1.0. So cross, jab, cross, jab beats jab spam. Alternating straights deal about 13% more than before; repeated jabs are unchanged.
- **Punches can't kill you:** the knuckle cost of a landed punch is capped so it can wear you down to 1 HP but never break your knuckles. Only enemy hits (and other damage) can.
- **Combo rules (2026-11-02, `Player.combo_move`):** every landed punch is compared to the one before it and does one of three things. Jab and cross are both "straight".
  - **Grows** (+1): a counter (always); the first punch; the first punch on a different enemy (even with the same hand, so one-shotting enemies in a row keeps growing it; the next punch on that enemy follows the rules below); the other hand throwing a different kind of punch (straight, hook or uppercut); the other hand throwing the same kind **once** (jab, cross; left hook, right hook; left uppercut, right uppercut); the second jab of a double jab.
  - **Holds** (refreshes the timer, nothing added): the other hand throwing that same kind a **third time or more** (jab, cross, jab; left hook, right hook, left hook); the third jab.
  - **Loses** (back to 0, and that punch starts a fresh combo at 1): the same hand again, other than the double jab; a fourth jab. Getting hit and letting the combo timer run out still lose it too.
  - A slip or roll that worked refreshes the combo timer to a full window and lets the same hand throw without losing the combo (it then counts as the other hand would). A missed one no longer does either.
  - Why: you could uppercut forever once a jab started a combo, even on the same side, and alternate hooks forever. Examples that grow every punch: jab, cross, hook, right-hand uppercut, or jab, hook, hook. The old 4-straight limit is gone; Unbroken still makes every punch grow.
  - Hooks and uppercuts still need the damage set-up (after a jab or cross, a set-up hook or uppercut, or a slip or roll to that side), which is separate from the combo count. A same-hand hook after a jab is set up for damage, but loses the combo.
  - **Fixed 2026-11-03:** the first punch on a new enemy now grows the combo (see Grows above). Old note: the first punch on a new enemy only holds the combo. A strong fighter who one-shots enemies never gets a second punch on the same enemy, so every punch is a "first punch on a new enemy" and the combo may never grow. Watch for it in playtests; a fix could let a kill, a counter or a different kind of punch still grow it.
  - Tutorial COMBOS drills stay jab, cross, hook and jab, cross, hook, uppercut (each punch still grows the combo under these rules), and Pad Work builds only combos that grow with every punch (hands alternate, no kind of punch three times in a row, one double jab, hooks and uppercuts set up).
- **Cross matches the jab:** the cross had a slower windup (0.11 s) and a longer cooldown (0.34 s) than the jab (0.09 s, 0.28 s), which also made its animation slower. Both straights use the jab's timing now. The cross still hits for x1.3, so mashing jab / cross deals about 11% more damage per second than before; watch it in the power balance.

## Windups, arm placement and no clipping [Built 2026-11-03]

**Rule (2026-11-03): no part of a monster's body or its gear (a shield, a weapon, a pauldron) passes through another part of its own body, in any pose.**

- **Windups read by their waist turn:** jabs and crosses barely turn the waist, hooks turn it a lot with the arm out to the side and bent. Slams and uppercuts are unchanged in shape.
  - **Boss rig** (`BossRig.SWINGS`, contenders, the Grave Champion, the Colossus): the cross wound up with about 70 degrees of chest, spine and pelvis twist (almost a hook's); now about 20, elbow tucked. The jab's twist is about a third of what it was.
  - **Voxel boxers** (`Boxer.TORSO_POSES`): jab twist 0.14 to 0.06, cross 0.35 to 0.12, hooks 0.44 to 0.62.
- **Arms in front of the body:**
  - The boxers' guard carries the arms forward (`Boxer.GUARD_REACH`), and the loaded straights, the uppercut windup and the hook, haymaker, staff, slash and thrust swings were moved so the forearm, glove and weapon stay out of the chest and hips. Before, about 40% of a brawler's forearm sat inside its chest in every pose.
  - The Grave Bruiser (veteran zombie) and the Bone Crusher had their shoulders inside their torsos: shoulders now sit outside and a little forward (`_build_arms`' `shoulder_forward`), their shoulder pads moved out with them.
  - The Bellman: slimmer stone flanks and back plate, his pauldrons ride his upper arms (raised for a slam, the arms went through them), and a slightly higher guard.
  - The rig's sweep swings round in front of the chest; the uppercut windup crouches and leans a little less (the off hand dipped into the hips).
- **Shieldbearers:** the tower shield hangs upright, centered in front of the body (it hung off one side), and the sword arm waits low at the side instead of in a guard in front of the shield. Jabs, crosses and uppercuts into the shield deal 25% (`Shieldbearer.SHIELD_CHIP`) with a SHIELD tag and keep the combo going (they used to be stopped dead and break it). Hooks wrap round for full damage; counters and a staggered shieldbearer take full damage.
- **Off the ropes:** a contender's Ghost Charge that reaches the ropes either rebounds 180 degrees back across the ring (OFF THE ROPES!, a new lane shows; at most once a charge) or ends dazed, 50/50 (`Boxer.RING_REBOUND_CHANCE`, only in the Dead League ring).
- **How it was checked:** a dev probe posed every enemy and boss at each windup, contact and follow-through, and tested every forearm, glove and held-item vertex against the rest of the body's boxes. All boxers came in under 15% overlap; the one rig case left is the Bellman's off hand brushing his hip (16%) in the uppercut windup.

## Defense rework: the armor formula [Built 2026-11-03]

**Why:** defense was 10 / (10 + defense) of every hit, and every enemy's damage was scaled to par's effective HP (knuckles x (10 + defense) / 10), which includes par's defense. Par's defense cancelled out: you took 20% of a Coffin King hit, but the hit was about 5x bigger for it. Upgrades read "65% damage taken" while enemies hit 4x harder.

- **The formula** (`GameState.armor_reduction`, `mitigate`, the Path of Exile armor formula): a hit is cut by defense / (defense + 3 x hit), at most 90%, and deals at least 1. Small hits are cut a lot, big ones a little: 100 defense takes 62% off a 20 hit, 10% off a 300 hit. Applied after Glass Jaw's extra and Grit's cut; Ward soaks after it.
- **Defense x10 everywhere:** the upgrade web (Mouthguard 5 a level ... Iron Coffin 30; Trophies 10-30; Iron Jaw, Stone Wall 10; Crypt Door, Vault Guard 15), the Mauler's class defense (30), Wraps' defense affix (15, +5 a floor), the Blessing of Stone (20), hats (Bucket and Fat Plumber Cap 5, Grim Reaper's Hood 10). Kept gear in old saves is scaled once on load (`defense_scale`).
- **Grit adds defense:** +1 defense a point (with +1.5% max knuckle HP). Par counts it.
- **Effective HP** (`Progression.effective_hp`): knuckles over the share of a typical hit that gets through, a typical hit being 12% of the effective HP (`GameState.TYPICAL_HIT`, a zombie's 6 on a fresh 50). Enemies are still built from par's effective HP, but par's armor now blocks about 28-39% of a typical hit at every tier, so it's 1.4-1.6x knuckles instead of up to 5x. POWER's defense side uses the same effective HP. Camp's sheet shows "Typical hit taken" (2026-11-04: now just "Defense", the stat itself).
- **POWER's scale moved** with it (par: 395 / 984 / 2,211 / 4,104 / 7,840 at tiers 1-5), so the contender targets are the plan's x2.3 a tier again from the Bellman's 500: **500 / 1,150 / 2,645 / 6,084 / 13,993**. Arena divisions build up to them as before.
- **Bosses on one scale:** Grave Champions and Crypt floor bosses were built from their scenes' 500-650 HP while contenders use 52-134, so they took 300-700 punches. They're now built from contender-sized units (`PowerRating.ARENA_CHAMPION_UNIT` 40 HP / 4.6 damage; `CRYPT_BOSS_UNITS` 60-75 HP / 5-6 damage). The first night's Champion keeps 80% HP (was 30% of the old 500).
  - **Grave Champions** take half their bout's recommendation (`CHAMPION_SHARE`); the bout's monsters are scaled to the other half.
  - **Crypt floor bosses** are as strong as the contender who opened their floors (500 / 1,150 / 2,645 / 6,084 / 13,993); a floor recommends its rooms on top (floors 1-2 about 600).
  - **Floor 10's boss** is 2.3x the Coffin King (32,184), the climb's real peak; floors 9-10 recommend about 26,000-47,000. The endless floors grow from it.
- **At par** (raw punches, before combo and heavy multipliers; hits = how many of the boss's hits knock you out):

| Fight | Punches | Hits |
|---|---|---|
| Bellman r1 / r3 | 33 / 44 | 8.7 / 7.1 |
| Headless | 37 / 50 | 8.2 / 6.6 |
| Southpaw | 48 / 64 | 6.7 / 5.5 |
| Plague Doctor | 77 / 103 | 4.2 / 3.5 |
| Coffin King | 120 / 160 | 2.8 / 2.4 |
| Grave Champions (bout 3) | 30-54 | 5.6-7.7 |
| Crypt floor bosses 1-9 | 39-61 | 4.4-7.9 |
| Floor 10 (vs Coffin King par) | 129 | 1.8 |

## Boss pacing and the power shift [Built 2026-11-03]

Prerequisites for the Crypt revamp, and the first Rebalance plan items.

- **Boss windup padding by tier** (`Progression.boss_windup_pad`, `Enemy.windup_pad`): every boss windup gets +0.075 s at tier 1, then 0.005 s less a tier.
  - Tier 1: the Bellman and the Gravedigger Arena's Grave Champion (0.075).
  - Tier 2: the Headless, the Bone Arena, Crypt floors 1-2 (0.07). Tier 3: Southpaw, the Ghost Arena, floors 3-4 (0.065). And so on: the Coffin King and the Crown Arena 0.055, floors 9-10 and the endless floors 0.05 (`Progression.crypt_boss_tier`: Crypt floor bosses run a tier ahead of their floors).
  - It replaces `DeadLeagueBoss.WINDUP_PAD` (0 / 0 / 0 / 0.06 / 0.075). The Lich King adds it to his cast time.
- **Crypt floors open with the seals** (`Progression.crypt_floor_open`): the Bellman opens floors 1-2, the Headless 3-4, Southpaw 5-6, the Plague Doctor 7-8, the Coffin King 9-10. Before, a pair opened with its tier, so the Bellman opened floors 1-4. A run can't descend into a sealed floor: the stairs say "FLOOR N IS SEALED: BEAT ..." and only lead out.
- **Endless floors and checkpoints** (`Progression.crypt_checkpoints`): beating floor 10 opens the endless floors. The camp Crypt picker shows an ENDLESS card that starts on floor 11, or on a checkpoint: floors 15, 20, 25, 30 ... once reached. A checkpoint start is as tough as reaching that floor.
- **Card odds by level** (`Cards.rarity_weight`): rare, epic and legendary cards' draw weight is scaled by fighter level. At level 1: rare x0.5, epic x0.3, legendary x0.3. They reach x1 (the old odds) at level 30, and rise to rare x1.15, epic and legendary x1.3 at level 50. Commons stay x1.
- **Loadout-locked cards:** a card that upgrades a passive or ultimate (`upgrades`) isn't drawn, and doesn't show in the deck, until the fighter has unlocked that ability (`Cards.available`).
- **The power shift** (`PowerRating.contender_shift`, `crypt_boss_shift`): contenders sit at the Rebalance plan's POWER targets (850, later 500 / 1,950 / 4,500 / 10,300 / 23,800) instead of their par's own rating. Crypt floor bosses sit at their tier's target (1,105, later 650 / 2,760 / 6,900 / 17,300 / 43,200, floors 1-2 to 9-10; the endless floors grow on top).
  - A boss's HP and damage both take the shift, so its POWER moves by exactly that much.
  - Shifts at first build: contenders x2.36 / x1.88 / x1.64 / x1.70 / x1.62. Crypt floor bosses about x8 on floor 1, x5.8 on floor 2, x4.6 on floor 10 (they were built from the Crypt's gentle ramp).
  - A par build now rates about 0.4-0.6 of the contender. The regression checks par against the contender before the shift. Test in play before deciding on caps or pattern changes.
  - Not shifted yet: the Arena's Grave Champions, the True Coffin King.
- **Second pass (same day, too steep):** the Bellman's target 850 -> 500 and Crypt floors 1-2 1,105 -> 650. Contenders now show their target exactly (class-neutral, like the Arena and Crypt recommendations); `contender_unshifted` is the old class-rated par.
- **Arena recommendations count the whole bar** (`PowerRating.arena_power`): you fight every spawn in a row and in groups, so a bout recommends sum(spawn POWER) / 35 (`ARENA_GROUP`) + the Grave Champion's.
  - A spawn's POWER is what it's built from (`climb_power`) times its weight against a plain zombie: sqrt(HP x damage) of its kind, veterans by the tier's share, the bar's growth, armor chance (x1.4), elites (x1.6) and champions (x2.3).
  - Gravedigger now builds 114 / 419 / 541 (bout 1 keeps the soft first-night rules). Later divisions: Bone 1,239-1,891, Ghost 3,774-5,579, Plague 10,834-14,846, Crown 25,834-36,837. From the Ghost Division on, the third bout recommends more than that division's contender.
- **Third pass (same day): divisions build up to their contender; the Crypt counts its rooms.**
  - **Arena** (`PowerRating.arena_shift`): from the Bone Division on, bout 1 recommends the contender you just beat and bout 3 this division's, geometric between: Bone 500 / 987 / 1,950, Ghost 1,950 / 2,962 / 4,500, Plague 4,500 / 6,808 / 10,300, Crown 10,300 / 15,657 / 23,800. The bout's monsters and Grave Champion take the shift on HP and damage (x0.40-1.03), the endless bout its third bout's. The Gravedigger keeps 114 / 419 / 541.
  - **Crypt** (`crypt_power`): a floor recommends its four fight rooms (3 + depth + a monster a floor each, one elite) as one group (sum / 35), plus its boss. A pair recommends 1.3x the contender who opens it (`CRYPT_OVER_CONTENDER`): 650 / 2,535 / 5,850 / 13,390 / 30,940. The floor boss gets what the rooms leave, at least 30% (`crypt_boss_power`: 547 / 1,920 / 3,336 / 5,523 / 11,518). This replaces the plan's x2.5-a-tier Crypt boss targets. The endless floors grow both (floor 11 recommends about 54,600, floor 15 about 80,000).
- **Pad Work pays less:** it takes twice the score for the same pay (`DRILL_GOOD_SCORE.pads` 1,700 -> 3,400) and tops out at half a bout (`DRILL_CAP.pads` 0.5). It used to have no cap. That's about 580 coins at most before your first Arena win, about 1,300 at Gravedigger bout 3.
- **Recommended POWER on every pick** (`PowerRating.arena_power`, `crypt_power`, camp's `_power_lines`): the Arena division and bout cards and the Crypt floor and checkpoint cards show REC. POWER, your POWER and the Dead League's verdict word and colors (OUTMATCHED ... OVERPOWERED).
  - An Arena bout recommends what its monsters and Grave Champion are built from. A division card shows your next unbeaten bout's.
  - A Crypt pair recommends its floor boss's target (650 for floors 1-2). It doesn't count the floor's rooms of monsters yet. The endless floors grow it like the monsters.

## Rebalance plan [Planned, 2026-11-01]

**What the playtest found (as the Blur):** the Bellman falls over (the daily combo drills pay a few thousand coins, which fills ring 1 and gives starting levels); the Headless needs a few Arena rounds and a little Crypt to be OVERPOWERED; Sister Southpaw is actually tough, but only if you forget HP and defense; the Plague Doctor is beaten with upgrades worth over 3x his power; the Coffin King was beaten right after the Plague Doctor with no upgrades while rated UNDERPOWERED. Bosses die too fast and a little defense makes their hits barely hurt. The Crypt starts hard and gets very easy after the third main boss. Late game the combo multiplier (cap x4) is reached within 3 hits, and the Blur mostly ran away and punched (alternating uppers or hooks). Other findings: the model assumes a 6-hit average combo, the Crypt ramps a quarter tier a floor while gear grows about x1.5 a floor, and defense (EHP = knuckles x (10 + defense) / 10) is linear, so stacked gear defense would be huge.

**Boss power targets** (POWER, geometric between tiers):
- Dead League, x2.3 per tier: Bellman 850, Headless 1,950, Southpaw 4,500, Plague Doctor 10,300, Coffin King 23,800.
- Crypt bosses start at 1.3x the Bellman, then x2.5 per tier: tiers 1-5 are 1,105 / 2,760 / 6,900 / 17,300 / 43,200. The floor 10 boss is harder than the Coffin King and is one of the future seals.
- Endless floors continue at the same ratio (now x1.25 per tier, which would go flat). The Coffin King's defeat opens a new, very strong ring of upgrades.
- Target fight length, whole fight on one HP bar: 60-90 s, the Coffin King about 2 minutes.
- **Test the power increase first.** Only then decide on caps or pattern changes.
- **Shelved:** a soft per-hit damage cap on bosses (hits over the cap deal cap + (damage - cap) / 3; higher caps for counters x2, perfect counters x3, Doom burst x4, ultimates x5; caps of 1.5 / 1.2 / 1.0 / 0.95 / 0.75% of max HP). Revisit only if bosses still die too fast.

**Other balance items:**
- **Combo drills:** daily first-clear reward matches the other minigames, about 200-500 gold before the Bellman, scaling with tier after.
- **Defense curve** before the new gear. *[Built 2026-11-03: see "Defense rework: the armor formula".]*
- **Combo multiplier:** lower the gain per hit, add a way to raise the cap (a gear stat), and spamming hooks shouldn't keep the combo going.
- **Grave Champion's punch** is too fast to dodge.
- **Shield bearers and similar:** take 10-20% damage from punches other than hooks; a real blocking animation.
- **Card toggles:** disable a card's effect (auto-teleport, AoE, knockback); selecting a card to disable it is fine.
- **Power upgrade costs** based on where they are unlocked.
- **Dead League readiness warning (mini tutorial + dialogue):** the first time the Dead League opens, a freeze-frame mini tutorial (`tutorial.gd`, once per save) spotlights the POWER vs POWER tug-of-war bar. It says that you are probably not ready yet, and to come back after you've bought upgrades to get stronger. The fight button still works:
  - First tap: "seriously you might want to get stronger first".
  - Tap again: "alright but don't say I didn't warn you!", then the Bellman fight starts.
  - Win: "wow that was impressive", and the achievement **Impress the Dev**.
  - Lose: "told ya so".
  - The lines show on the VS screen (`vs_intro.gd`) when the player goes straight back to the fight right after the Dead League tutorial.
  - It also shows any time the player tries to fight while severely underpowered (the OUTMATCHED verdict, POWER under 0.7 of the contender's), not just right after the tutorial.
- **Soul shop:** a 10-20 minute timer that grants one free refresh click (capped at one) instead of refreshing.
- **Spawn rates:** hats more common; toilet rooms more common (now 1% a floor after the "overexerted" emote).
- **The Stray's stomp:** a visible jump multiplier for chaining jumps, more damage per chained stomp; 8 jumps gives the 1up achievement and unlocks the plumber jump emote. Its upgrade widens the range (forgiveness for landing slightly off, not hitting several enemies) and improves the chain multiplier.
- **Per-character progression:** each character gets its own gold and power upgrades. Global: hats, emotes, skins, soul coins, idle animations.
- **Model gaps to fix:** rate the combo multiplier as sustained (cap reached in about 3 hits), hit-and-run through enemy melee turns, and auto powers (teleport, AoE, knockback). Raise the Crypt's per-floor ramp to match gear growth (about x1.5 POWER a floor).
- Re-run `balance_report` and the bots against every contender and floor after each change.

## Crypt revamp plan [Planned 2026-11-01; built 2026-11-04]

**Goals:** a cleaner, more polished Crypt; real items with sets and looks; better salvage; mimics that are fun to fight.

**Room furniture and layout [Built 2026-11-04]:**
- Before (`Dungeon._decorate`, `_decor_spot`) props go at random spots anywhere in the room, avoiding only layout blocks and the center, and the wall coffin sits at a random place on the left wall, so it can block a door.
- New: keep-clear lanes 3 m wide from each door to the center and between doors; props only in zones (walls, corners, alcoves); coffins in tidy rows or stacks on the side walls; a cap on props per room; chains and banners stay overhead.
- Per room type: the start room has a clear approach and one landmark; fight rooms have symmetric coffin rows and a clean center; chest rooms are vaults with the chest on a pedestal; the merchant has stalls and a rug; the boss room has a dais and a clear arena; the toilet room stays bare, one bulb.
- Props stay decorative (no collision). Stone stays neutral; each tier's color (red, blue, purple, green, yellow) appears only in accents: banners, candle and torch flames, and their light. Coffins are scenery.
- **As built:** `Dungeon._plan_props` gives every room its lanes (3 m, door to middle and door to door), a clear middle for fight and boss rooms (half the shorter side), the spots its torches and set piece take, and a budget of small prop groups (one per 36 m², at most 9; a third of that in the start room, half in vaults, the merchant's and the shrine's). `_zone_spot` only places props along the walls, in the corners and beside blocks, and hazards (toxic puddles, fire vents) stay off the lanes too, so doorways are safe. Fight rooms get upright coffins (shouldered, brass cross) in the bays between the wall pillars of every wall without a door, the corner bays left to the torches; the Catacombs keep their skull niches instead. A banner hangs either side of every door. Start room: the gilding altar on the wall facing the door between two candle stands under two banners. Vault: the chest on a gold-banded pedestal facing the door, candle stands either side, iron grates over the bays, coin heaps in the corners (a mimic there steps down toward you). Merchant: he keeps shop against the wall facing the door, a rug before his table, a stall on each side wall (crates, a barrel, sacks under an awning in the tier's color). Boss room: a dais against the wall facing the door with a throne, two braziers and two banners, coffins on the side walls; the chest, stairs and altar come up around the middle after the fight. Shrine: a ring of candles open toward the door. The tier looks use the same zones (half-sunk coffins along the walls, mushrooms in two greens, sarcophagi along the walls and a dark, gold-trimmed carpet down the way in). The stone and fog are neutral greys; the tier's seal holder's color (red, blue, purple, green, gold) is in the banners, the flames and their light.

**Gear system [Built 2026-11-04] (`Gear`, `gear.gd`)** (replaces the random affixes; these 20 pieces are the only Crypt items):
- 5 sets of 4 pieces (Gloves, Wraps, Boots, Charm), 5 rarities each. Stats add up across worn pieces, so players can mix sets for a stat. Only the 4-piece set bonus exists; it uses the lowest-rarity piece.
- **Rarity:** every piece has 5 stats unlocked in order: common 1, uncommon 1-2, rare 1-3, epic 1-4, legendary 1-5. Rarity never boosts a number. Stat 5 is a signature effect (SIG) that does not scale with level.
- **Levels:** a drop's level is between (floor - 1) x 3 + 1 and floor x 3 (floor 1: 1-3, floor 10: 28-30); past floor 10 both bounds rise 1 a floor. Value = base x growth^(level - 1). Past level 30 the growth portion halves at 31, and again at 35, 40, 45...; stats top out near 2x their level-30 value. Gear levels up in the store, to the highest floor beaten (+1 a floor past 10).
- **Stat scaling per piece, level 1 to 30** (approximate; the stat's base x growth per level):

| Stat | Base | Growth | Level 30 |
|---|---|---|---|
| damage | +3 | x1.15 | +173 |
| damage_percent | +6% | x1.093 | +80% |
| crit_chance (total cap 100%) | +3% | x1.088 | +35% |
| heavy_bonus | +6% | x1.076 | +50% |
| head_bonus | +8% | x1.091 | +100% |
| counter_bonus | +8% | x1.078 | +70% |
| boss_damage | +8% | x1.078 | +70% |
| finisher_bonus (damage to low-HP enemies) | +8% | x1.091 | +100% |
| armor_pierce | +4% | x1.072 | +30% |
| punch_speed | +3% | x1.068 | +20% |
| max_knuckles | +15 | x1.13 | +519 (tune later) |
| defense (x10 scale, armor formula, 2026-11-03) | +10 | x1.098 | +150 |
| heal_on_kill | +1 | x1.109 | +20 |
| graze_reduction, flinch_reduction | +4% | x1.072 | +30% |
| free_punch_chance | +2% | x1.072 | +15% |
| move_speed, sprint_bonus | +5% | x1.083 | +50% |
| jump_bonus | +4% | x1.072 | +30% (jump height lessened, fall speed up: separate change) |
| dodge_window | +0.01s | x1.04 | +0.03s |
| counter_window | +0.02s | x1.03 | +0.05s |
| combo_window | +0.05s | x1.05 | +0.20s |
| combo_step | +0.01 | x1.05 | +0.04 |
| combo_cap (new) | +0.05 | x1.083 | +0.5 (four pieces = +2) |
| coin_bonus, xp_bonus | +6% | x1.091 | +75% |
| ult_gain | +3% | x1.076 | +25% |

- **Sets** (stats listed in unlock order, then the SIG; set bonus is common / uncommon / rare / epic / legendary):

| Set (color, style) | Piece: stats | SIG |
|---|---|---|
| **Deadweight** (red; tank, heavy) | Knuckles: heavy_bonus, damage, armor_pierce, flinch_reduction | Shatter |
| | Bindings: max_knuckles, defense, graze_reduction, flinch_reduction | Thorns |
| | Treads: max_knuckles, defense, move_speed, sprint_bonus | Grit |
| | Anchor: heal_on_kill, max_knuckles, defense, coin_bonus | Iron Will |
| Bonus: take 3 / 5 / 7 / 10 / 14% less damage | | |
| **Drowned** (blue; dodge and counter, "be water") | Fists: counter_bonus, damage, crit_chance, head_bonus | Champion's Hands |
| | Wraps: defense, graze_reduction, heal_on_kill, max_knuckles | Slipknot Wraps |
| | Steps: dodge_window, counter_window, move_speed, sprint_bonus | Clean Read |
| | Pearl: combo_window, xp_bonus, finisher_bonus, combo_cap | Rhythm |
| Bonus: clean dodge counters do +5 / 8 / 12 / 16 / 20% more | | |
| **Grandmaster's** (purple; speed, combos, Wing Chun) | Hands: punch_speed, damage_percent, crit_chance, combo_cap | Lunging Jab |
| | Wraps: free_punch_chance, combo_cap, max_knuckles, flinch_reduction | Mid-Roll Counter |
| | Slippers: move_speed, sprint_bonus, dodge_window, combo_cap | Double Jab |
| | Seal: combo_step, combo_window, combo_cap, xp_bonus | Frenzy |
| Bonus: +3 / 5 / 8 / 12 / 16% punch speed | | |
| **Iron Mike's** (yellow; finishers, bosses) | Gloves: finisher_bonus, boss_damage, damage_percent, armor_pierce | Bone Breaker |
| | Wraps: max_knuckles, defense, boss_damage, heal_on_kill | The Long Count |
| | Boots: move_speed, counter_window, jump_bonus, sprint_bonus | Gravewalker |
| | Belt: finisher_bonus, boss_damage, ult_gain, xp_bonus | Executioner |
| Bonus: +5 / 8 / 12 / 16 / 20% damage to elites and bosses | | |
| **Dead Money** (green; greed, utility) | Rings: head_bonus, crit_chance, damage, coin_bonus | Gold Fever |
| | Wraps: max_knuckles, heal_on_kill, coin_bonus, defense | Loaded Dice |
| | Loafers: sprint_bonus, move_speed, jump_bonus, xp_bonus | Silver Tongue |
| | Coin: coin_bonus, xp_bonus, combo_window, ult_gain | Haggler |
| Bonus: +10 / 15 / 20 / 30 / 40% coins and XP | | |

  Items are named "(set) (piece)": Deadweight Knuckles / Bindings / Treads / Anchor, Drowned Fists / Wraps / Steps / Pearl, Grandmaster's Hands / Wraps / Slippers / Seal, Iron Mike's Gloves / Wraps / Boots / Belt, Dead Money Rings / Wraps / Loafers / Coin. Cards show set progress under the name ("Iron Mike's 2/4"). A 6th set, **Haunt** (powers and ultimates, for the Catalyst), is on hold.
- **Signatures** (fixed; the old specials and legendaries, edited):
  - **Shatter:** counters burst for 50% damage within 2.5 m. **Thorns:** attackers take 150% of the knuckle damage they dealt (was 100%). **Grit:** below 30% knuckles, take 30% less. **Iron Will:** the first hit in each room is blocked.
  - **Champion's Hands:** counters throw a free follow-up punch. **Slipknot Wraps:** 50% chance a graze counts as a basic dodge (no clean dodge, Rhythm or Gravewalker credit). **Clean Read:** clean dodges heal 4% of max knuckles. **Rhythm:** each dodge adds +0.15 combo multiplier, up to +1; the HUD reads "COMBO MULT: X +1" with the +1 in its own color.
  - **Lunging Jab:** dash into a jab for +60%. **Mid-Roll Counter:** a punch thrown while rolling counts as a counter without using up your counter window, so you can still counter normally right after. **Double Jab:** the first jab on each enemy hits twice (once per enemy, no reset). **Frenzy:** every 10th hit in a combo lands twice.
  - **Bone Breaker:** hook counters ignore 50% of armor. **The Long Count:** survive a knockout at 1 HP and stun everything for 3 s; once per floor, once per Arena bout, once total in the Dead League. **Gravewalker:** dodging an attack gives 25% damage reduction for 2 s. **Executioner:** counters finish non-boss enemies under 25% HP.
  - **Gold Fever:** damage + log10(gold held) x 5% (100 gold = +10%, 100,000,000 = +40%; 0 gold = 0). **Loaded Dice:** chests can be rerolled 3 times a floor (not the merchant's wares). **Silver Tongue:** silver drops +25%. **Haggler:** your ultimate spends 10% less meter; with Sister Southpaw's card it stacks to 35%.
- **Damage reduction cap:** set bonuses and effects that reduce damage taken (Deadweight's bonus, Grit, Gravewalker...) share one 75% cap. Armor and the defense stat are separate; Iron Will (a blocked hit) is outside it.
- **Defense under the armor formula (revised 2026-11-03):** the defense stat now cuts each hit by defense / (defense + 3 x hit), capped at 90%, at least 1 damage. So defense gear is the crowd stat: Deadweight and the Wraps pieces carrying defense matter most in Crypt rooms and Arena bars, little against a boss haymaker. Their numbers are on the x10 scale (a level-30 piece's +150 is about a third of tier-5 par's 426). Deadweight's flat "take less damage" bonus stays the boss-fight answer (it applies to every hit, after armor, inside the 75% cap). The par build counts gear defense the same way, so stacking it moves POWER through effective HP, not a separate number.
- **Cursed chests are replaced by elite mimics;** the old risk specials (Glass Jaw, Last Stand, Blood Price) go away with the random item system. Existing gear in saves migrates to the nearest set piece by slot. Legendary becomes a normal rarity on every piece, so the boss and elite chest legendary rules change.

**Drop odds [Built 2026-11-04]** (tiers are 2 floors each, tier 6 is endless; chance by tier T1..T6):

| Rarity | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---|---|---|---|---|---|
| Common | 70 | 60 | 45 | 25 | 10 | 0 |
| Uncommon | 20 | 25 | 30 | 30 | 20 | 10 |
| Rare | 6 | 8 | 15 | 25 | 40 | 50 |
| Epic | 3 | 5 | 6 | 12 | 20 | 25 |
| Legendary | 1 | 2 | 4 | 8 | 10 | 15 |

- Chests use this base pool. Elite mimics and boss chests roll it and then go up one rarity (legendary stays): T1 becomes 0 / 70 / 20 / 6 / 4, T6 becomes 0 / 0 / 10 / 50 / 40.
- **The merchant** rolls three base-pool chests when the floor loads; those are his wares, plus the healer's kit.
- Item level is rolled in the floor's range.

**Economy [Built 2026-11-04]:**
- **Silver:** salvage gives 2 / 5 / 8 / 12 / 20 by rarity (not floor); merchant buy is 5x that: 10 / 25 / 40 / 60 / 100.
- **Gold:** gilded items sell outside the Crypt for 3.31 x level^3 x rarity^1.5 gold (rarity 1-5), about 1,000,000 for a level-30 legendary and about 89,000 for a level-30 common; past level 30 it slows (+5% of the level-30 price per level). Tune the exponents with the economy.
- **Soul coins:** store buy price is half the merchant price: 5 / 13 / 20 / 30 / 50. Leveling gear costs level / 2 soul coins per level (rounded up, minimum 1); level 1 to 30 is about 240. That is meant to be expensive: the point is to keep finding new gear and use different pieces.
- **Equipping:** interact with your old item to salvage it, keep it (if gilded) or equip it again. The store page shows real item cards.

**As built (2026-11-04):**
- **Numbers:** `Gear.STATS` is the table above. Three stats use the game's own units: dodge_window is a share of the dodge window (+3% at level 1, about +9% at 30, under the 25% cap), counter_window and combo_window are seconds. A piece's effects are rebuilt from (set, slot, rarity, level) whenever its level changes; flat stats round to 0.1, the rest to 0.001.
- **Set bonus:** `GameState.get_effect` adds the 4-piece bonus (`Gear.set_bonus`) at the lowest rarity of the four. Deadweight's cut, Grit and Gravewalker share the 75% cap (`Gear.MAX_DAMAGE_REDUCTION`), applied after armor (a hit still costs at least 1). Cards show "Set n/4" and the 4-piece line (gold once it's on), counting the piece as if worn.
- **Signatures as built:** Bone Breaker: hook counters ignore 50% of the armor left after armor pierce. Slipknot: 50% chance a wrong (grazing) defense counts as a plain dodge, with a counter but no clean dodge, Rhythm or Gravewalker. Gravewalker: a dodge cuts damage taken by 25% for 2 s. The Long Count: back every Crypt floor and every Arena bout, once a Dead League fight. Rhythm: the combo line reads "7 HITS  x1.90 +0.45", the Rhythm part in seafoam. Mid-Roll Counter, Double Jab, Frenzy, Gold Fever, Loaded Dice (a Reroll button on the YOU FOUND card), Silver Tongue and Haggler (the ultimate keeps 10% of its meter; with Ultimate Surge, 35%) are as written. Shatter, Thorns (150%), Grit, Iron Will, Champion's Hands, Clean Read, Lunging Jab and Executioner keep their code from the old specials, with the numbers above.
- **Drops:** chests roll `Gear.roll` (a random set, the floor tier's odds, a level in the floor's range); boss and elite chests go one rarity up. Cursed chests stay until elite mimics replace them: a top-of-range level, one rarity up. The merchant's wares are base-pool pieces priced in silver.
- **Your old item:** a find you swap out floats beside you, turning in its rarity's light. Interacting shows "YOUR OLD WRAPS" with Wear again, Salvage (silver), and Keep (gilded: it goes to your Armory now) or Leave it. A gilded find left lying on a floor still goes home when you go down, leave or get knocked out. Gear you brought in stays in your Armory either way.
- **Camp:** the Armory card has Level up (Souls; "Max level for now" at the cap from the deepest floor beaten) and Sell (gold); Reforge, Reroll and Salvage are gone. The Soul shop's gear is a random set and slot at 5 / 13 / 20 / 30 / 50 Souls by rarity, its level in the deepest beaten floor's range.
- **Old saves:** every kept item becomes the nearest set piece: its slot, the set its stats lean to (`ItemModels.set_for`), its rarity (cursed becomes epic, an unknown one rare) and level floor x 3 - 1.
- **Balance:** par's gear is real gear now: rare Deadweight Knuckles (damage) and Bindings (knuckles, defense) at the middle level of the deepest Crypt floor open when facing each contender (floor 2 for the Headless up to floor 8 for the Coffin King; true par at level 29). Par POWER is 395 / 1,026 / 2,525 / 5,252 / 11,490 against the unchanged targets of 500 / 1,150 / 2,645 / 6,084 / 13,993. The True Coffin King's maxed-build tuning (`TRUE_MAXED`) is measured with the maxed fighter in true par's gear, so his HP and damage follow geared players. A full legendary level-30 set roughly triples a maxed fighter's POWER; the balance re-run looks at that.

**Mimics and elite mimics [Built 2026-11-04]:**
- Mimics are less common, invincible while closed, and periodically open to show a mouth with a boxer tongue that throws a punch combo like other enemies; open, it's vulnerable but deadly.
- Elite mimics replace cursed chests: a mimic reskin with champion effects and stats. Interacting shows "this is obviously a mimic, but a strong one..." with two choices: challenge it anyway, or back away. Beating it drops a max-level item for that floor, rolled from the one-rarity-up pool.
- **As built:** mimics are rarer (12% of chest-room chests, 8% of dropped ones). A woken mimic stands up shut: punches clang off ("SHUT TIGHT", the combo breaks like a shield), and so do powers and Thorns. Every 2-3 s it claims a turn, closes in and opens: the lid swings up and back and a tongue in a red boxing glove throws a 2-3 punch combo (jab, cross, hooks, uppercut) with the boxers' timings, tell flash and glove glow in the dodge's color, read and dodged the same way. Open it takes hits; after the combo it gapes for about a second (two if you dodged the whole combo; a counter cuts the combo short and leaves it gaping), then snaps shut. The tongue's root sits above the rim, so it never passes through the chest. Cursed chests (purple chains, teeth at the seam, purple eyes) ask "A CHAINED CHEST: This is obviously a mimic, but a strong one..." with Challenge it / Back away (`HUD.show_choice`). Challenged, the room seals and an elite mimic stands up: a champion (two traits, champion health, aura and pay), gold corners and purple chains, 4-punch combos, shut 30% less. Beaten, it leaves a golden prize chest: a top-of-the-floor level piece, one rarity up. Chest lids now swing up and back when opened (they used to sink into the chest).

**Toilet and merchant tie-in [Built 2026-11-04]:** a toilet spawns in the merchant room 10% of the time, even before the player has the poop emote (today the toilet room needs the "overexerted" emote and is 1% a floor); clog it and the merchant calls the plumber; once you beat the plumber he says "just go, I'll take care of it myself." Toilet rooms overall should also be more common. The player can go into the toilet room any time.
- **Ask about the toilet:** when a merchant spawned with a toilet, talking to him shows an extra button to ask about it. The player says "why do you have a toilet... undead people can't poop." The merchant groans ("ughhhhhhhh... groooooannn"). Then the player says "oh yeah, he's undead."
- **With the Fancy Bluetooth Headpiece on:** the merchant instead says "I just need some time for myself, ya know?" and the player says "the merchant is so real for that."
- **New hat, Fancy Bluetooth Headpiece** (a scouter): "checks power levels and can translate anything!" It has no stat boost. Wearing it shows the POWER level of the enemy you are looking at, and it changes the merchant's toilet answer above.
- **Clogging needs the poop emote:** the toilet can appear before the emote is unlocked, but the player can only clog it once they unlock the (secret) poop emote. Seeing a toilet and wondering "why", then finding the emote and wanting to try it, is the joke.
- **As built:** toilet rooms come 5% a floor, emote or not, and 10% of merchants keep a toilet by the back wall beside them. With one, his shop has an "Ask about the toilet" button: YOU "Why do you have a toilet... undead people can't poop." / MERCHANT "Ughhhhhhhh... groooooannn." / YOU "Oh yeah, he's undead." (subtitles, 2.6 s apart). Wearing the Fancy Bluetooth Headpiece: MERCHANT (TRANSLATED) "I just need some time for myself, ya know?" / YOU "The merchant is so real for that." Clog his toilet (three poops) and he yells "PLUMBERRRRRRR!": the room seals and the Angry Plumber comes (same fight as the toilet room's: uppercut him down). Any beaten plumber says "Just go, I'll take care of it myself."; the one the merchant called leaves the **Fancy Bluetooth Headpiece** the first time (a won hat, never dropped, no stats). Its model is a scouter: a white ear piece with a gold band and a blue light on the left ear, an arm round to a glowing green lens over the left eye. Worn, a readout under the crosshair shows the POWER of the monster you're looking at and your verdict ("POWER 105 · OVERPOWERED", in the verdict's color): a monster reads `PowerRating.monster_power`, its HP and hit against a fresh zombie's (which reads a fresh fighter's 100); contenders and Crypt floor bosses read their POWER targets. The hat card now turns a hat about the middle of its blocks, and a small hat can ask to be shown bigger.

**Item models [Built 2026-11-04] (`ItemModels`, `item_models.gd`):** every piece has its own model, built the way hats are (`Hats._b` blocks in the block material), rounded with stacked, crossed blocks. Each set has its color and one signature per piece:

| Set | Gloves | Wraps | Boots | Charm |
|---|---|---|---|---|
| Deadweight (red) | Knuckles: red glove, riveted iron knuckle plate, iron cuff edge | Bindings: dark red leather roll in iron chain links | Treads: heavy red boot, iron toe cap, tread sole, iron strap | Anchor: iron anchor, red rope round the shank |
| Drowned (blue) | Fists: blue glove, seafoam wave stripe, barnacles | Wraps: blue roll, seafoam bands, seaweed, a pearl bead | Steps: low blue boot, seafoam cross straps, white sole | Pearl: open clam shell with a pearl |
| Grandmaster's (purple) | Hands: fingerless glove, ivory fingertips, gold diamond, gold wrist band | Wraps: purple silk, gold stripes, gold tassel | Slippers: kung fu slippers, black sole, gold trim | Seal: jade stamp, gold lion, gold glyph |
| Iron Mike's (yellow) | Gloves: yellow, black cuff, red band, white laces | Wraps: white tape, yellow band, red tape end | Boots: tall yellow boxing boots, white laces, red top stripe | Belt: championship belt, gold plate, red gem |
| Dead Money (green) | Rings: gold four-ring knuckle duster, green gems | Wraps: green roll, paper bill band, gold money clip | Loafers: green loafers, gold penny strap | Coin: big gold coin with a green $ on both faces |

- Gloves stand on their cuff, fist up, the thumb against the side of the fist from the palm by the wrist to its tip at the top front corner, a dark gap in the web. Every wrap has its loose end looping up out of the top.
- Rarity recolors the same model: common dull and dingy, uncommon muted, rare full color, epic and legendary saturated. Epic has small purple sparkles, legendary more, bigger gold ones (their own particles, so the color stays purple and gold).
- Until the gear system gives items a set, an item wears the model of the set its stats and special lean to (`ItemModels.set_for`, from the set tables above), so it always looks the same.

**Item cards [Built 2026-11-04] (`ItemCard`, `item_card.gd`):** Crypt drops ("YOU FOUND"), the gilding altar, the merchant and the camp shop's gear show the item's model turning in a little 3D window (lit like the hat popup), its name in its rarity color, what it is, and its stats colored against what's worn. The card's color and effects climb with rarity: common a thin grey frame; uncommon a green frame, a faint glow and a soft light under the item; rare a blue frame, a glow and slow light rays; epic a thick purple frame, a pulsing glow, brighter rays and purple sparkles over the window; legendary a thick gold frame, a strong pulse, bright fast rays, gold sparkles and a light sweep across the card every few seconds. The cards keep animating while a drop pauses the Crypt.

**Balance re-run [Done 2026-11-04]** (`balance_report.gd` prints the gear sections; it runs again, its autoload calls fixed):
- **Par and the contender targets are unchanged.** At par (upgrades, attributes, typical cards, par's rare gloves and wraps) the berserker sits at 1.02 / 1.14 / 1.24 / 1.12 / 1.08 of the five contenders' POWER, the counter master (lowest) at 0.71 to 0.90.
- **Gear's reach:** a typical kit (a random set per slot at the rarity you'd usually keep by then: uncommon, rare, rare, epic; the deepest open floor's middle level) puts the berserker at 0.95 / 1.12 / 1.25 / 1.57x par facing the Headless, Southpaw, Plague Doctor and Coffin King (1.08 to 1.70x the contender). Its damage, knuckles and defense are about what par already counts; the edge is its percent stats (damage %, crit, heavy / head / finisher / boss damage...), which reach +20-50% a piece by level 23. A full best set at the floor's top level reaches 1.3 to 2.7x the contender. Kept as the Crypt's reward; the POWER readouts count your gear, so a geared fighter reads READY or OVERPOWERED. If the late climb is too easy with gear, the two knobs are: count the typical kit (percent stats too) in par and raise the tier-3+ contender targets with it, or slow the percent stats' growth.
- **The True Coffin King** is tuned to a maxed fighter in an endgame kit (epic level-30 pieces from four sets, no set bonus: `Progression.endgame_kit`): about 60% more HP and 4% more damage than when measured in par's two rare pieces.
- **Gold and Souls:** a gilded piece at the floor's middle level sells for 40k (common) to 450k (legendary) on floor 8, against ring 5's 5.4M; 81k to 903k on floor 10, against ring 6's 25.9M. Gilding's silver cost (Souls removed later the same day) limits how many come home, so the plan's formula stays. Leveling a piece from 1 to 30 is about 240 Souls, as planned.

**Polish after the revamp (2026-11-04):**
- **Gilding is silver only** (no Souls).
- **Panels never lose their buttons:** the merchant's, the altar's and the YOU FOUND row of item cards scrolls when it's taller than the screen leaves room for, Buy / Gild sit above each card, and Esc closes the merchant and the altar (and backs out of a question).
- **The merchant's table** shows his wares as their real models, turning slowly, each with a little light in its rarity's color. Item cards show the model a touch smaller.
- **The Headless boxes for real:** a high guard, both gloves up by the neck stump where his face would be, elbows in; a true stance (left foot forward, the right back and turned out 45 degrees, knees bent, hips bladed, abs crunched). `BossRig` profile keys stagger, turnout, blade, crunch and high_guard (only his shape uses them); his punches, toss and charge come out of that guard.

**Open work:** none; the revamp is built (item models, item and store cards, the gear system with save migration, drop odds, salvage, the economy, room furniture, mimics, the toilet and merchant tie-in, and the balance re-run, 2026-11-04).

## Camp pass 2: rail, Fighter page, hidden modes [Built 2026-11-05, mobile 0.1.32]

**Built (the user picked the Ring, asked for the fighter zoomed out so no node covers his head):** `attribute_ring.gd` (`AttributeRing`): the live voxel fighter (EmotePreview at distance 7.0) in the middle, five glowing nodes round an ellipse with name, `n / 30` pill and three perk dots (10 / 20 / 30, lit when earned); tap a node for its perks and a Spend button in the detail panel, tap the fighter for the stats sheet. `camp.gd`: Fighter = ATTRIBUTES | DECK switch (the Deck page lives inside it; the Fighter rail badge counts attribute points plus card draws, the DECK switch the draws), Loadout / Change fighter / Reset along the top; rail without Deck, buttons share the height equally, Bounties named again, new icons; "Camp" text gone; Crypt and Dead League cards are hidden until unlocked and pulse in when they unlock (the padlock dialog is gone). Dailies stay on Home. Captures: `--scene=res://camp.tscn,NAME,PAGE,TAB,ATTRIBUTE`, `CAPTURE_POINTS=N`.

The user's notes after seeing Home + Play on mobile: they like it, but the Attributes page "looks like a Godot ui game", the rail buttons need even spacing and nicer icons, the "Camp" text goes, Crypt and Dead League stay hidden until unlocked, and the upgrade web's transparent look should carry onto the fighter screens.

**1. The rail**
- **Fighter = Deck + Attributes** (+ Loadout, Change fighter). Deck leaves the rail. Inside Fighter a switch at the top: ATTRIBUTES | DECK. The Fighter button's badge adds card draws and attribute points.
- **Bounties:** the Goals button goes back to the name Bounties (open question: should Dailies also live there? Today they sit under Training on Home).
- **Even spacing:** buttons share the rail's height equally (expand-fill), so Gear and Bounties appearing or hiding re-spreads them instead of leaving gaps. About 7 buttons: Home, Fighter, Upgrades, Gear (once unlocked), Style, Shop, Bounties (once unlocked).
- **Icons:** new drawn set in `Icons` at 40 px, two-tone like the rest, one per page: Home = campfire flame, Fighter = glove, Upgrades = the sigil web, Gear = helmet over chestplate, Style = hat, Shop = soul bag, Bounties = wanted poster. Selected one lights gold with a soft glow.

**2. Header and Home**
- Remove the "Camp" text under FRIGHT NIGHT; the title is centred on its own.
- **Crypt and Dead League cards are hidden until unlocked** (Crypt: Bellman's seal; Dead League: first Arena bout won), instead of greyed. At first Home shows just the Arena card, big and tall, plus Training and Daily. When one unlocks, its card slides in with a pulse (the existing Crypt reveal and Dead League tip fire as before). This replaces the padlock and "prove your worth" dialog, which go away.

**3. The Fighter page in the upgrade web's style**
What the user likes: the Upgrades page's near-transparent canvas (backdrop and fire show through), thin lines, glowing round nodes, a detail panel on the right. Fighter becomes the same kind of screen:
- **Attributes:** a ring like the upgrade web. Your fighter stands in the centre (their real voxel body, as in the Soul Shop previews), the attributes are glowing nodes round them showing their point count, each with three small satellite nodes for the 10 / 20 / 30 perks that light up as you reach them. Tap a node to select it, a + in the detail panel (or tap again) spends a point. The detail panel on the right shows the attribute, what each point does, the three perks in full, and the Reset button.
- **Deck:** same canvas: the cards in a transparent grid, each a rarity-framed tile, selected one shown large in the detail panel (as today), Draw and Redraft along the top.
- **Your fighter sheet** (jab damage, knuckle HP and so on) moves into the detail panel when nothing is selected, so it's still one tap away.
- Panels over the canvas become see-through with a thin gold edge, like the Upgrades canvas; the heavy bordered cards go.

**4. Order of work (each approved before the next)**
1. Mock the Fighter page (attribute ring and deck) on the options page, from a screenshot of the camp, for approval.
2. Rail: Fighter merge, even spacing, new icons, rename. Header "Camp" removed. Hidden cards. (Small; can ship first.)
3. Fighter page rebuild, playground first.
4. Phone check at 844x390 and touch: tap node, tap +, drag to scroll the deck.

## Camp layout: Home + Play [Built 2026-11-05, mobile 0.1.31 only]

After four skin tries (taped glove, stitched, spooky signs, polished) didn't land, the fix was the layout: the 14 equal buttons in one row became a rail down the left (Home, Fighter, Upgrades, Deck, Gear, Style, Shop, Goals; `Camp.RAIL_NAMES`, icons from Icons) and a Home view: the camp fire in the open space (the backdrop camera now aims right of the fire, `CampBackdrop.LOOK_AT`) and the ways to play as picture cards on the right (`_mode_card`: Arena with division, bout and pips; Crypt; Dead League with the next contender and seals; locked ones greyed with why), Training and Daily under them. Menu became a settings gear in the header. Fighter (the Attributes page) carries the Loadout and Change fighter buttons. Card art: `art/ui/mode_*.jpg`, game screenshots. Tips open the page they point into. Mock-ups: the Fright Night Camp Layouts artifact.

## New-player onboarding [Built 2026-11-05]

- **The tutorial pays nothing** (it used to pay for your first upgrade with an "Enough for your first upgrade" line).
- **After the tutorial (or skipping it):** camp's ARENA tip on the Arena button: "To make money, you need to duke it out with the undead!" (Its button was never wired before, so this tip had never shown.)
- **After your first Arena fight (won or knocked out):** the YOUR FIRST UPGRADE tip on the Buy button. Short of the cheapest upgrade, camp tops your coins up to it first and the tip opens with "Oh, you're broke? Fine, I'll spare some change."
- **The Dead League is locked until you win an Arena bout:** greyed with a padlock; pressing it says "Beat your first Arena bout to prove your worth." Once open, its tip says "You proved your worth: the Dead League is open." then explains the contenders and seals. Older saves with a bout won or a seal broken are open.
- `dead_league_visual_capture.tscn -- --onboard=arena|broke|won|locked` renders each stage on the test save.

## Places and UI update plan [Planned, 2026-11-04]

The arenas, the Dead League backdrop and the menus have barely changed since the start. This update gives every place more detail and solid props, gives each Dead League boss its own stage with a crowd, puts the fighters around the camp fire, and replaces the stock Godot widgets with a custom UI kit.

**Rule for every step: mobile parity.** The mobile build is the same project (Web Mobile preset), so every change reaches it, but each change ships with its touch fixes: drag-to-scroll on every list and card row, ~48 px tap targets, long-press for hover info, touch wording, phone aspect (844x390). Every new scene holds 30 fps on a phone without heating it (see the performance budget). When a batch is released, the mobile page gets it too (`release_mobile.sh`).

### 1. Groundwork: prop kit, solids, steering, performance budget
- **Prop kit** in `scenery.gd`: new pieces shared by the arenas and stages (big gravestones, obelisks, statues, mausoleum rows, bone pillars, pews, tent poles, gold piles, banners, chandeliers). Each piece built through `_box_batch` (one MultiMesh per material) instead of one MeshInstance per box.
- **Solid vs. walk-through:** large props (big gravestones, trees, statues, pillars, crypts, tents) get a `Scenery.solid` box or cylinder matching the trunk or base, not the canopy. Small graves, grass, bones and rubble stay walk-through. (Today the graveyard's props have no collision at all, `world.gd` `_build_decorations`.)
- **Enemies around solids:** enemies `move_and_slide`, so they would snag. Add steering: a short ray toward the target; if it hits a solid, slide along the side nearer the target, and after ~1 s try the other side. Ranged enemies need line of sight to fire, so props become cover.
- **Layout rule (organized, not scattered):** three rings per arena: a clear fighting floor (spawns and the boss's spot always clear), a middle ring of solid props in planned clusters with lanes between them, and an outer backdrop with no collision. Props come from a per-arena layout list, not random scatter, so each place reads as a place.
- **Performance budget (phones, web profile):** shadows off; at most ~6 dynamic lights (the rest are emissive flames with no light); under ~250 draw calls in a fight; web particle counts; `visibility_range_end` on backdrop detail; camp grass cut on mobile (4000 to ~800). Measure each scene with `bench_probe` / `web_bench` before and after, and on a real phone.

### 2. Arena revamp (the five divisions)
Same 45 m fields and themes (`Themes.ARENA`; `world.gd` for the graveyard, `arena_scenery.gd` for the rest), rebuilt to the layout rule:
- **The Graveyard:** stone paths, family plots with low walls, two mausoleums, big angel gravestones and dead oaks as solid cover, an iron gate, lantern posts along the paths.
- **The Ossuary Pit:** a sunken pit with tiered bone walls, bone pillars and skull stacks as cover, blue-flame braziers, a bone throne on the far side.
- **The Drowned Pier:** plank docks over dark water, piles, moored boats, crates and nets as cover, fog lamps.
- **The Plague Carnival:** a midway of rotting stalls and small tents, a broken carousel in the middle ring, the toxic vats (existing hazard), sickly green string lights.
- **The Coffin King's Colosseum:** sand floor, broken columns and statues as cover, tiered stands in the backdrop, banners, fire bowls (existing hazard).

**The Gravedigger Division [Built 2026-11-04, to test]:** `graveyard_scenery.gd` (`GraveyardScenery.build`, called by `world.gd` for the graveyard theme and by the playground's place picker). Layout: a clear plaza (9.5 m) ringed by a flagstone path; four paths out at the diagonals (the north-east one ends at a gate in the fence) with lantern posts and rows of graves facing them; each quadrant has a block-man statue near the plaza (weeping angels replaced 2026-11-04: they read as a mess at night), two family plots, two big dead oaks, an obelisk and a mausoleum (two on phones), with lone graves through the middle ring and smaller oaks at the edge. Lights: four lanterns lit everywhere, two more on desktop (old: eight torches with shadows).
- **Solid to monsters too:** angels, obelisks, oaks and mausoleums are on `Scenery.PROP_LAYER` (16) as well as `Scenery.LAYER`; every walking enemy masks it (`Enemy._ready`). `Enemy._avoid_props` looks 1.6 m ahead ten times a second and walks along the prop's side (the side nearer its heading); the old stuck-detour stays as a backup. Spawns and the Grave Champion's spot keep clear of props (`World._clear_of_props`). Arrows stick in props, so they're cover. Fences and the other divisions' buildings still block only you.
- **Checked:** `dead_league_visual_capture.tscn -- --steer` puts a zombie behind each prop with you in front: 16/16 reach you in 1.4-1.7 s without passing through. Balance, Dead League and card regressions pass. Phone profile, same views: 28-41 draw calls (old graveyard 151-566), about the same triangles. `-- --world=X,Y,Z,YAW,PITCH,NAME` renders the Arena from a free camera and prints its cost.

**The other four divisions [Built 2026-11-04, to test]:** `arena_scenery.gd` rewritten to the same plan (plaza, paths, planned solid cover, walk-through clutter, the division's wall), batched by PropKit; `build()` now returns `{lights, solids}`, and the world keeps hazards (toxic puddles, fire vents) 2.8 m clear of props.
- **Ossuary Pit:** six bone-paved causeways; skull pillars with blue fire round the plaza; six walls of stacked skulls; three giant ribcages; bone heaps; the skull-studded bone wall. Lights: the pillars (4 phone / 6 desktop).
- **Drowned Pier:** a compass rose in the plaza; four plank boardwalks with ghost lanterns; per quarter bollards, two crate stacks, a fishing shack with a lit window, an overturned rowboat, a net rack and a mast stump; barrels and rope; pilings and rope round the edge; the sunken ships.
- **Plague Carnival:** four trampled midways under bulb strings, lined with striped game booths (8 on phones, 16 on desktop); a high striker by the plaza; the broken carousel and three striped tents; oil-drum fires; hay and barrels; the fence and the dead Ferris wheel.
- **Colosseum:** a red ring and the King's crown in the sand; eight columns (three broken) round the plaza; four statues of the King; four gold braziers; weapon racks; lava cracks; crown banners; the arcade walls and stands of the dead.
- **Steering:** monsters now pick one way round a prop and keep to it until clear (long walls and booths made them dither). `--steer=DIVISION`: every prop in all five divisions passes (89 props): around it to your side within a few seconds, never inside its shape.
- Phone profile from the middle: 19-45 draw calls at eye level, 20-92 from a raised corner.
- **Rejected:** the distant outside of each division's Dead League venue on the horizon (tried, the user didn't like how it looked).

### 3. Dead League stages and crowds
`dead_league_arena.gd` builds the same graveyard for every bout (`_build_graveyard`). Replace it with a stage per boss (`dead_league_stages.gd`, picked by `DeadLeagueRules.boss(index).id`). The ring, ropes, posts, spotlight and ring walls stay; the surroundings and lighting change.
- **The Bellman: the Crypt hall.** Grey stone vaults (the Crypt revamp's tier-1 look, red banners), a huge bell hanging over the ring, candles. Crowd: zombies, skeletons, Hulks.
- **The Headless: the Bone Pit.** Cold blue light, bone pillars and skull walls like the Ossuary, blue braziers. Crowd: many skeleton kinds (skeletons, snipers, shieldbearers, bulwarks, mages, possessed armor).
- **Sister Southpaw: the Gothic Chapel.** Pews as the stands, tall stained-glass windows (emissive panes, no real light), organ pipes, candles, an altar behind her corner. Crowd: wraiths, banshees, priests, liches.
- **The Plague Doctor: the Plague Tent.** Inside a rotting big top in the Carnival's green, striped canvas and a centre pole, hanging lanterns, bubbling vats. Crowd: ghouls and the bigger zombies (brawlers, bruisers, Hulks).
- **The Coffin King: the Gold Hall.** A rich castle throne room: gold everywhere, a red carpet to an empty throne, chandeliers, treasure piles, gilded coffins. Crowd: Grave Champions and Bone Crushers.
- **The True League** uses each boss's stage; a tag-in keeps the current stage.
- **The crowd never fights:** static copies of enemy models, not enemies (no AI, no `Enemy` script, outside the ring walls behind a barrier). One baked body per enemy kind, instanced. A shared cheap loop (bob, sway, raised arms), a cheer on a knockdown, big hit or round end, a groan when you go down. About 12 on mobile / web and 30 on desktop; the far rows are flat silhouettes.

**Bellman stage and the crowd [Built 2026-11-04, to test]:** `dead_league_stages.gd` (`DeadLeagueStages.build`, falls back to the old graveyard for contenders without a stage yet), `crowd.gd` (`Crowd`), `prop_kit.gd` (`PropKit`: boxes batched per shared material). The Crypt hall: brick vaults with ribs and pillars, red and gold banners, a gate glowing with fire behind the Bellman with the portcullis up, coffins beside it, a bronze bell over the gate that swings each round (round 2 on also rings), three-tier stands on three sides plus two behind you, a low wall with candles, a red runner up the aisle, four braziers. Lights: gate + 4 braziers + spotlight on desktop, 2 braziers on the web. Crowd: zombies, skeletons, Hulks (top tier only), 40 on desktop / 22 on the web, the real voxel bodies everywhere (the user: keep the monsters). Each kind is baked once into one mesh per pose; they cheer at round starts, counters, round wins, the K.O., and when you go down. Measured: 145 draw calls (old graveyard 226 web / 1387 desktop), ~600k triangles on the web profile. `dead_league_visual_capture.tscn -- --stage=BOSS,YAW,PITCH` renders a stage without the contender and prints its cost.

**All five stages [Built 2026-11-04, to test]:** shared pieces in `DeadLeagueStages` (`_room`, `_ringside`: stands, striped-or-plain low wall, candles, runner, corner braziers / vats / gold braziers and their lights; `_crowd`) and PropKit (skulls, stained glass, treasure, chandeliers, pews, vats).
- **The Headless, the Bone Pit:** open sky, cold blue light; bone-brick walls with a skull frieze, skull columns with blue fire, rib arches over the aisle, racks of collected heads, a giant skull with glowing eyes over the gate. Crowd: skeletons, Bone Snipers, Shieldbearers, Bulwarks (top tier).
- **Sister Southpaw, the Gothic Chapel:** 15 m pointed vaults, stained glass down both sides, a rose window over an altar with organ pipes, pews for stands. Crowd: wraiths, banshees, Grave Priests, Bone Liches.
- **The Plague Doctor, the Plague Tent:** a striped green and purple big top (canvas cone roof, pennants, rigging, a trapeze), green lanterns, sludge vats at the corners, a striped ring wall, a curtain behind him. Crowd: Ghoul Brawlers, Runners, Sprinters, Pit Fighters, Bruisers and Hulks (top tier).
- **The Coffin King, the Gold Hall:** red walls, gold pillars and trim, marble with gold inlay, moonlit windows with red curtains, chandeliers, an empty throne on a dais between gilded coffins, a crown banner, treasure heaps. Crowd: Grave Champions and Bone Crushers (scaled down). The True Coffin King fights here too.
- Phone profile: 156-175 draw calls per stage (old graveyard 226).

### 4. The camp fire cast
The camp backdrop (`camp_backdrop.gd`: fire, tent, dummy, Crypt door) stays; the log seats become the cast, using the fighters' third-person bodies (`FighterBody`, matching their voxel refs) in looping poses:
- **The Mauler (Berserker):** on a big stump, eating a hunk of meat (bite, chew, gesture with it).
- **The Answer (Counter Master):** cross-legged on the ground, calm, nodding.
- **The Blur (Combo Master):** lounging on one elbow, the odd yawn.
- **The Stray (Free Runner):** sitting, one leg always bouncing, looking around.
- **Tony (once found):** next to the Mauler with a deli sandwich.
- **The Catalyst (once bought):** sitting apart with a big tome, glowing motes rising from the pages.
- **Talking:** one speaker at a time gestures while the others turn their heads to them; it moves on every few seconds. No text or sound for now.
- Animate only while the backdrop is visible (it already pauses under menus, `_skip`).

**Built 2026-11-04, to test:** `camp_cast.gd` (`CampCast`, added by `CampBackdrop`). Real FighterBody bodies in their skins (only the fighter you play wears your hat), posed by Emotes clips written in code (sitting, cross-legged, lounging, bouncing, reading), props on their hands (a drumstick, a deli sub, a glowing tome with rising motes) and seats (a big stump with an axe in it, a crate, a rock). Talking: a speaker every 3.5-5.5 s (not the Catalyst, who reads); the speaker nods and gestures with a free arm, the others turn their heads to them. Tony joins once `tony_unlocked`, the Catalyst once bought. Cost (phone profile): the camp went from 164 to about 325 draw calls and 75k to 409k triangles with all six; the camp already renders every other frame on phones, and its grass is cut to 1500 blades there. `dead_league_visual_capture.tscn -- --backdrop[=X,Y,Z,LX,LY,LZ,NAME]` renders the camp backdrop (and prints its cost).

- **Fixes (same day):** the camp's two logs now lie round the fire instead of pointing at it (the Stray's legs and the Blur's back went through them); the Stray sits on the front edge of his log; the Blur lounges further round (330 degrees) against the other log, thighs raised so his legs stay above the floor; Tony moved beside the Answer, out from behind the flames; the food (meat, sub) is aimed at the mouth as the hand comes up and slides back so its tip stops at the lips (it went through the Mauler's face). `CAMP_CAST_FREEZE=<seconds>` holds every pose for checking stills.

### 5. Custom UI kit
Replace the stock Godot look (flat StyleBoxes in `ui_theme.gd`) with our own kit, used everywhere:
- **Pieces:** buttons (normal / hover / pressed / disabled, a press squish and sound), panels and frames, cards framed by rarity and tier, tabs, sliders, toggles, scroll areas (no scrollbar on touch), outlined headers and numbers, tooltips (long-press on touch), dialogs, toasts.
- **How:** textured nine-patch StyleBoxes (generated in code or small images) in the shared `Theme`, so every screen picks them up, plus a few custom controls where a theme can't do it (squish, glow, card frames). Anton stays the display face.
- **Style first:** three mock-ups on one page (as with the touch look), the user picks one. Ideas: the taped glove (leather, stitching and tape, matching the touch buttons); carved stone and bone with gold; a fight poster (paper, ink, stamps).
- **Screens in order:** title, camp hub, upgrade web, Armory and item cards, Soul Shop, Dead League menu and VS intro, pause and settings, results, HUD.
- **Testing:** a UI Gallery in the playground showing every piece in every state at desktop and phone sizes.

### Build order
1. Groundwork (prop kit, solids, steering, budget).
2. Dead League stages and crowds, one boss at a time (the Bellman first).
3. Arena revamp, one division at a time (the Graveyard first), checking enemy pathing and balance.
4. The camp fire cast.
5. UI mock-ups, pick, the kit, then the screens.
Each piece goes in the playground for the user to test (desktop and `?touch`) before release.

## Mobile build [Idea, planned 2026-11-02]

A possible phone / tablet version. Nothing is built. It comes after the current roadmap (controls, balance, Crypt revamp), and the touch scheme should be tested in the playground first.

**Touch controls (the user's design):**
- Landscape. A virtual joystick on each side: left moves, right looks. Buttons for dash and back step, and a toggle for sprint (sprint doesn't change punches).
- Punching: the screen is split into a left half and a right half. Each half is one hand.
  - **Tap:** a straight on that side (left tap = jab, right tap = cross).
  - **Swipe toward the midline:** a hook from that side.
  - **Swipe up:** an uppercut on that side.
  - **Swipe away from the midline:** a slip on that side.
  - **Swipe down:** a roll on that side.
  - Example: jab, cross, left hook, right roll, right uppercut = tap left, tap right, swipe in on the left, swipe down on the right, swipe up on the right.
- Upgrade web and menus: tap and drag to pan, pinch to zoom, double tap to buy. Buttons are easy to tap; the UI needs a readability pass for small screens.
- Later: in-app purchases for cosmetics.

**The biggest design risk: two thumbs.** Holding the move stick, the look stick and punching on both halves is more than two thumbs can do (and the dash, back step, sprint, jump and ultimate buttons need a thumb too). Options to test, easiest first:
1. **Lock-on camera** (aim assist): the view follows the nearest enemy, so the right stick isn't needed and the right thumb punches. Free look stays as an option. Pairs with a short auto-step toward the target when punching.
2. **Move stick as a floating stick** that releases when a punch starts, so one thumb can move and then punch, like a fighting game.
3. **Stick zones only in the bottom corners** with the punch gestures on the rest of each half, so a stick thumb and a punch thumb don't fight over the same area.
- **Decision (2026-11-02): option 1, lock-on.** It gets built and tested after the Crypt revamp. Give the sticks a swap for left-handed play.

**Lock-on camera plan:**
- **Today's aim:** the camera is mouse or stick look (`Player._stick_look`: yaw turns the body, pitch tilts the camera), and a punch lands on whatever the straight ray hits, 2.5 m ahead (`PUNCH_REACH`, 3.2 m with Long Reach). That is too fiddly on a touch screen. `_land_punch` already takes a `forced` target (Temporal Break uses it), so a lock-on punch can pass the locked enemy.
- **Two modes, switched by the situation:**
  - **Combat** (an enemy within about 12 m, or a fight room / Arena / Dead League bout is active): the view locks on, there is no look stick, and both halves of the screen are punch zones.
  - **Exploring** (no enemies near): the right stick appears for free look and the punch zones go away.
- **Who gets locked:** the enemy currently taking its turn (the one throwing punches; `Enemy.take_turn` / `has_turn`) first, otherwise the nearest enemy in front of you within about 10 m. When the target dies, the next one locks automatically after a short beat. The lock drops if the target is more than about 14 m away or out of sight for a second or two.
- **Switching targets:** automatic by default, plus a small button near the right thumb that cycles through enemies by hand. Tapping an enemy is not an option, because taps are punches.
- **Camera motion:** the body turns toward the target (smoothed, about 500 degrees a second, with a small dead zone so it doesn't twitch), and the pitch eases to the target's aim point. Aim points are per enemy: the head by default, the glowing core for the Bone Colossus (its core takes double damage), the middle for flying Wraiths. Offer a "Lock-on strength" setting (off / soft / hard) and a "Reticle" setting (a ring and health bar on the locked enemy).
- **Punches:** while locked, a punch passes the locked enemy as `forced` if it is within reach plus a small margin and within about 35 degrees of your facing; otherwise it whiffs as today. Optional short auto-step toward the target (up to about 0.6 m) when it's just out of reach.
- **Movement:** with the view locked, the move stick strafes around the target, so rolls and slips orbit it the way they do now. Sprinting off in the open turns the view toward your movement, and the lock drops when you break away.
- **What doesn't change:** combo rules, set-ups, counters, damage, the Temporal Break, and bosses' tells. Arrow slips still work (a ranged enemy locks when it is the nearest or the attacker).
- **Decisions (2026-11-02):**
  - **Three lock-on levels to test**, aiming for a blend of soft and hard (starting numbers, all to be tuned):
    - **Soft:** a gentle pull toward the target that eases off whenever you steer yourself (about 200 degrees a second; punches land within 25 degrees of facing; no auto-step).
    - **Blend (the likely default):** the body turns toward the target on its own, smoothed (about 500 degrees a second; 35 degrees; a short auto-step, about 0.4 m).
    - **Hard:** snaps to the target and holds it (about 900 degrees a second; 45 degrees; auto-step about 0.6 m).
  - **Target cycling:** test both auto (the attacker, then the nearest) and manual (the cycle button), and compare them.
  - **Desktop and controller:** lock-on ships there as an option too, with the same three levels.
  - **Timing:** none of this starts until the Crypt revamp and its balance patches are done.
- **Build and test order:**
  1. **Desktop prototype first, in the playground:** a lock-on toggle key and a controller button, so it can be tuned with a mouse before any touch layer exists. It may also be worth shipping on desktop and controller as an option.
  2. **Touch layer:** the sticks, buttons and punch gestures on top of it.
  3. **Real-phone test:** judge it on how many punches land, how comfortable the camera is (no jitter or nausea), and 30 fps.
  4. **Edge cases:** a big boss at close range, a flying Wraith, several enemies at once, a sniper at range, the Arena's wave spawns, and the Dead League's tag-in fights.

**Lock-on [Built, 2026-11-04, mobile 0.1.3]:** `lock_on.gd` (`LockOn`, a child of Player). Setting `lock_on`: auto (blend on touch, off elsewhere), off, soft, blend, hard, with the numbers from the plan above. Picks the attacker, else the nearest in front (keeps its target unless another scores 30% better); a kill picks the next after 0.35 s. Turns the body and pitch toward `Enemy.aim_point()` (Colossus: its core). `_land_punch` falls back to the locked enemy when the ray misses (`punch_target`: in reach + 0.5 m and inside the level's arc; blend/hard step in up to 0.4 / 0.6 m). Reticle ring + HP bar. Touch: the look stick is hidden while locked, and a LOCK button (top row) cycles targets, then returns to auto. Desktop: F cycles (and gives a temporary blend lock with the setting off). No controller button yet (all buttons are taken). Built straight in the game rather than the playground first, because the mobile page needed it.
- Touch fixes (same day): stick zones are smaller and lower, a quick flick from a stick zone still throws the punch, RUN stays on until tapped again, menus get taps sent straight to the viewport (no engine touch-to-mouse flip), the emote wheel needs only 38 px of drag, and full screen on the web retries on every tap until the browser allows it.

**Touch layout v2 [Built, 2026-11-04, mobile 0.1.4]:** buttons and sticks take your fighter's colour (`GameState.fighter_color()`). Right side: ULT and JUMP stacked over a bottom row of big squares, DASH (up arrow) at the edge, RUN (double up arrow, a toggle) beside it, BACK (down arrow) beyond; USE on the left above the move stick; LOCK / MAP / EMOTE / pause along the top. MAP only shows where it does something (the Crypt map; in Practice it's NEXT, which steps the dummy level and skips the tutorial). A punch finger glows in your colour with a fading trail. Menus: dragging scrolls any list under the finger (even over cards; sliders still drag), two fingers pinch-zoom the upgrade web (mouse wheel), one finger pans it.

**Touch tweaks [Built, 2026-11-04, mobile 0.1.5]:** the look stick stays while locked on, greyed and marked UP / DOWN (the lock owns the sideways turn; the stick adds a vertical bias, +-0.6 rad, `LockOn.pitch_bias`). ULT is a 12-point star that glows and pulses when the ultimate is ready; JUMP is a square; LOCK sits next to EMOTE.

**Touch layout v3 [Built, 2026-11-05, mobile 0.1.10, to try]:** one row of three on each side above the sticks. Left, left to right: BACK, DASH, JUMP. Right, left to right: ULT, USE, RUN. Swiping down with both thumbs at once is the back step (a single down swipe waits 0.07 s to see if the other thumb joins, then rolls). Hand idle previews zoomed in (fov 48).

**Touch look: taped glove [Built, 2026-11-05, mobile 0.1.15]:** picked from three mock-ups (A taped glove, B glass rings, C graveyard). Buttons are dark leather tinted with the fighter's colour, with stitched edges and a crooked strip of athletic tape carrying the label; icons, stitching and stick caps use the fighter's colour at full saturation. Small top buttons are tape discs ringed in the colour; ULT is a stitched leather star with a tape rim and a charge ring; sticks are leather discs with a stitched ring and a coloured cap. Held buttons fill with the colour. B and C are kept as options in the mock-up page if we want to revisit.

**Touch HUD [Built, 2026-11-05, mobile 0.1.16]:** the passive chip and power tiles sit under the ultimate bar (chosen over under the health bar, which stays available as `?hud=health`), clear of the stick corners. Stick zones never throw a punch or dodge: no flicks from a stick, and a second finger in a stick zone does nothing.

**Touch layout v4: fewer buttons [Built, 2026-11-05, mobile 0.1.26]:** the buttons covered a big chunk of the screen and the tutorial. DASH, BACK, USE and the ULT button are gone:
- **Dash:** both thumbs swipe up at once ("Double swipe up"); **back step:** both down ("Double swipe down"). A single up swipe waits 0.07 s to see if the other thumb joins, then throws the uppercut (as the down swipe already did for the roll).
- **Use:** hold a finger still in a punch zone for 0.45 s: a ring fills round it, USE shows, and interact stays pressed until it lifts.
- **Ultimate:** the HUD's ultimate gauge is the button (the user's call, 2026-11-05; a separate badge was tried first): tap anywhere on it (`TouchUi._ult_rect`, the gauge's `ult_gauge` group). Charged, it blazes with a big pulsing aura, the name reads "INFERNO UPPERCUT   TAP!" and the diamond says TAP.
- **RUN and JUMP:** squares on the inner side of the move and look sticks, level with them (mirrored left-handed).
- **Telling the player:** every hint, the tutorial's back step, the pause menu's Controls tab and the controls line name the gestures ("Double swipe up", "Double swipe down", "Hold", "Tap the ULT bar"); the tutorial on touch gets a DASH step right after MOVE (`Training.STEPS_TOUCH`: 2 two-thumb up swipes; RUN and JUMP are buttons, so the user dropped a step for them), counted from the new `Player.performed` signal (jump, forward_dash, back steps and the other defenses, dodge or not). The back step keeps its own steps (BACK STEP, TAKE TURNS). A TOUCH MOVES banner was tried and dropped. The practice coach card no longer shifts right for the old button column.

**Touch layer v1 [Built, 2026-11-04, before lock-on]:** `touch_ui.gd` (autoload `TouchUi`), live only while a fight runs (a Player that is active, the game not paused; menus use normal touch-as-mouse). It sends the same actions as keys and pads, plus `Player.touch_punch(hand, type)`, `touch_dodge(side, kind)` and `touch_move(move)`.
- Floating sticks in the bottom corners (left moves, right looks, no lock-on yet). The rest of each half is that hand's punch zone: tap = jab / cross, swipe in = hook, up = uppercut, away = slip, down = roll (Junior Mode picks the dodge for both). A swipe fires at 46 px, a tap on release.
- Buttons: left column USE, BACK (back step), RUN (sprint toggle, drops when the stick is released); right column ULT, JUMP, DASH; MAP, EMOTE, pause (II) at the top right.
- Turned on by the `mobile` export feature (the Web Mobile preset), `--touch` on the command line, or `?touch` in a web address (`?touchmouse` also turns mouse drags into touches, for testing on a desktop). On, it also sets the window to expand its aspect (phones are wider than 16:9) and skips the mouse capture.
- Pipeline: preset "Web Mobile" (ETC2 / ASTC textures, portrait warning, no touch scroll) and `release_mobile.sh <version>` push to itch `isaiahd0221/fright-night-mobile` (restricted page, `html5` channel); `--export` only exports to builds/mobile.
- **Touch wording [Built, 2026-11-04]:** `Controls.touch()` (the touch layer is on) makes every hint name the buttons and gestures: `key_name` / `text` / `fill` / `rows` / `summary` / `cue_hint` give "Tap left", "Swipe in", "Swipe up", "Swipe out", "Swipe down", RUN, BACK, DASH, JUMP, ULT, USE, MAP, EMOTE. So the tutorial's keycaps, the Pad Work chips, the dodge cues over enemies, the pause menu's Controls tab, "ULT" on the ultimate badge and the camp tips all follow it. Touch counts as a hand-picking scheme (`hand_heavies`), so drills judge the hand. In the tutorial, MAP skips it and cycles the dummy level (like the controller); the coach card moves right to clear the left buttons.
- **Emote wheel [Built]:** hold EMOTE, drag a finger in a direction to point the wheel, let go to dance (a quick tap repeats the last dance). `TouchUi.wheel_vec` feeds `Player._steer_wheel`; the wheel itself shows in the middle of the screen. Only one dance was unlocked in the test, so picking between several by drag is untested.
- **Settings [Built]:** on touch the Controls tab shows field of view, mode, button size, button opacity, look speed, a left-handed layout (sticks and button columns mirror) and invert look; the key / controller / binding rows are hidden.
- Still to do: camp / Armory / store layouts at phone size (cramped at 844x390), long-press tooltips (taps already show the info panels), a real-phone test, then lock-on.

**Controls details to decide:**
- **Buttons that aren't in the plan yet:** jump, ultimate, interact (chests, stairs; context-sensitive), emote (hold for the wheel), pause, and the Crypt map.
- **Gesture reading:** a tap fires on release (short and barely moved); a swipe fires as soon as it passes a small distance, without waiting for the finger to lift. Up / down / in / away use ±45 degree cones. Weenie Hut Junior Mode is a good default on mobile: a swipe away picks the right dodge for you.
- **Rules stay the same:** the combo rules, set-ups and counters work as they do on a controller, because the gesture names the hand and the punch directly. Add a direct "throw this punch with this hand" entry on `Player`, and a `Controls` touch mode, so the touch layer sends the same actions as keys and pads.
- **Aim:** the punch ray needs magnetism toward the nearest enemy in front, since thumbs aim worse than a mouse.
- **No hover:** tooltips become long-press; the emote wheel, the Dead League bar and card details need tap versions.
- **Customization:** button size, opacity and position; sensitivity; left-handed layout.

**UI readability pass:** bigger text and tap targets (about 48 dp minimum), safe areas for notches, HUD kept clear of the thumbs, and touch hints in place of keyboard names. The camp's upgrade web, the Armory, the store and the Settings panel all need touch layouts.

**Platform and performance:**
- A browser build on phones is a quick way to test but weak: audio unlock, no easy orientation lock, and the existing web performance work (render scale, no shadows) is the floor. A native Android build is the better target; iOS needs a Mac, an Apple developer account and Xcode.
- Target a steady 30 fps first. Reuse the web profile (shadows and post effects off) and `render_scale` auto.
- Saves: cloud save or an easier backup than the long save codes.

**Monetization (later):**
- Sell cosmetics only: skins, hats, emote packs, idle animations. Never power: not soul coins, gear or upgrades.
- Hats drop at random in the game, so don't sell random hat packs (it looks like a loot box, and the stores restrict those).
- Stores take 15-30%. They need a privacy policy, a data-safety form and an age rating (boxing, undead, toilet humor).
- The parody content (the plumber caps, Yonkers, fighter-pun names) needs a review against store IP rules before submitting.

**Plan (phases):**
1. **Decide:** the thumb layout (lock-on chosen), target platform (Android first?), and landscape only.
2. **Touch prototype in the playground:** gestures, sticks and buttons; test in the browser's mobile view, then on a real phone through the dev build.
3. **Touch UI pass:** menus, camp, upgrade web gestures, readability.
4. **Performance and native export** (Android), then a closed test with a few players.
5. **Store prep:** privacy, ratings, parody review, a store page.
6. **Cosmetic purchases:** after launch, once players are in.

## Patchwork (2026-10-28)
- **Upgrade web zoom:** out to 0.2x (was 0.5x) and in to 2x; it opens fitted down to 0.35x, and each wheel step is 15%. The "UPGRADES OWNED x / y" counter has room for three-digit counts.
- **Tony's bald spot:** his buzz cut was thinner than a voxel (1.2 cm vs 1.6 cm), so the flat back of his skull showed through, ringed by hair; it's 2 cm now, and it stays on under hats (only bald hats take it).
- **Drawn-On Hairline:** painted on, so it's head-sized now (hats are built 1.4x to read): the sides, back, peak and square glasses sit right on the head.
  - 2026-10-31, hats on monsters: the seat is now the highest head-sized block on the middle line, not the biggest. A skeleton in a chest plate wore its hat on the plate (on its neck), and the mage and pyromancer on their hat brims at face level. A caster's own hat goes under a collected one and comes back when it pops off. The GIMME THAT popup centers each hat on its blocks, so masks and the pumpkins aren't cut off under the window.
  - 2026-10-31: on the large-cube bodies it was inside the skull (it was fit like a wig, smaller than the skull's cubes), and so was the Bald Hero Cap's shine. Painted-on hats now have their own fit (`FighterBody.paint_fit`), measured from the skull's outer cubes: the paint just over them, the sunglasses over the eyes and out in front of the raised brow and nose, their arms over the ears.
- **No stun-locks, from anything [Built]:** the audit found four doors to holding a monster (punch staggers, `stun`, `knock_down`, `delay`/`scare`) with separate or no limits, so they chained (a Blur went stun, punch-stagger, stun: free about 1s in 3.5s; knockdowns and card delays had no limit at all). Now one rule covers them all (`Enemy.CONTROL_MAX`): every hold counts as control; a monster is held at most 2s at a stretch (punch staggers alone 1s), and once free it shrugs off all control for 2s (`CONTROL_GRACE`; 2026-10-29: it was as long as the hold, at least 1s, which let tiny repeated stuns chain), so it's never held more than about half the time. A knockdown during the grace just shoves it back. Ultimates force through the grace (not past 2s). Bosses keep their poise, which now covers delays too. Tested by hammering a zombie every frame for 30s with each hold and all of them mixed (held 51-53%), and a Dead League boss (30%).
- **The Catalyst's runes [Built]:** one rune per power his passive runs (`CatalystRunes`, on the camera), floating in a small arc above his hands in its power's color: Attunement one big rune, Dual Sigil two medium, Prism four small. Each turns slowly and burns bright while its power can go off, dim while it recovers.
- **Flame Burst [Built]:** a real explosion now. Radius 9 m (was 6); a swelling fireball, a shockwave racing across the ground, a ring of flame pillars, embers, smoke and chunks of ground thrown out, a flash that lights the whole place, a hitstop and a hard shake. Regular monsters it doesn't knock out are blasted up and away (about 3-4.5 m up, 5-6 m out) and land down; the ones it knocks out get the full fling. Bosses just take the hit.
- **Playground:** a skin picker up top; upgrade tiers to test at (Fresh, Tier 1-5 par builds, Maxed; POWER about 120 / 350 / 860 / 2,400 / 4,700 / 10,800 / 58,000); foldable sections; a full-height panel; hotkeys G god mode, K spawn, C clear, F freeze, U fill ultimate.
- **Web performance (2026-10-28):** the in-browser bench (`?bench`) showed camp at 1 fps with 7,000-10,000 draw calls, nearly all the upgrade web. It drew every background dot (3,000+, more zoomed out), every dash of every unbought link, each seal ring as 36 arcs, each "?" as 10 arcs, each node's halo as 4 circles and each owned link as two polylines. Now: the dot grid is one tiled texture, dashes and rings go out as batches (`draw_multiline`), halos are one soft texture, owned links are batched by color. Camp: about 590 draw calls on a fresh save, 2,900 maxed (was 10,200). The Dead League built its boss when the VS card ended (a 0.2s hitch on desktop, over 1s in browsers): it's built behind the card now (and the True Coffin King's tag-ins up front); worst frame 232 ms to 70 ms. Burning and frozen monsters carry no light in browsers. The web also redrew everything every frame for its sparks: now the links, rings and labels draw only when the web changes (`_links`), the sparks, turning "?" dashes and purchase pulses draw on their own light layer (`_fx`, one batch each), and only nodes that actually move (pulsing, turning runes, the maxed shine) redraw on their own. Camp uncapped on desktop with the web renderer: 43 fps to about 90-115.

## Time stops, and lighter effects (2026-10-29)
- **Control grace:** a monster shrugs off all control for a flat 2s after any hold (`Enemy.CONTROL_GRACE`), however short the hold; boss poise is 4.5s (was 3s). Hammer test: monsters held 53%, bosses 25%.
- **Temporal Break [Built]:** no more button prompts. Time stops with a pale wave sweeping out and the world draining to cold grey (bright glows keep their color); you move and punch what you aim at (or the nearest frozen monster in reach). Each punch's damage is held, with its flash frozen in the air, until time resumes: then a white flash, the wave rushes back, every spark bursts and each monster takes all its held damage at once ("TIME BREAK"). Armor counts per punch. The other hand from your last punch buys back 0.25s (half the old prompt refund, now x0.8 each time); that hand glows (the Blur's spinning ring), and "ALTERNATE HANDS" shows for the first few. Why: monsters killed mid-stop died frozen, and in the Dead League a boss killed mid-stop lingered into the next round beside the new contender. Checked in `card_runtime_regression`.
- **The Family, lighter:** the goons share their materials and meshes, carry no light in browsers, look for a new target 4 times a second through the enemy group (they scanned every node in the level every frame once nothing was left to hit), and their punches add no burst or sound of their own beyond the hit's (3-6 goons at a punch each 0.55s).
- **Effects compile behind the loading screen (`FxWarmup`):** with no shader cache (as in every browser visit), each effect's first appearance compiled its shaders mid-fight: 70-170 ms stalls on a desktop for an ultimate or power's first use, far worse in a browser. Fights (arena, Crypt, Dead League) now play every shared effect once, tiny, behind the loading screen or VS card, plus the fighter's own ultimate's (the Family's goons, Flame Burst's blast). Desktop with no shader cache: Ground Pound's first use 95 to 43 ms, Quake 121 to 53, Flame Burst 133 to 70, Inferno 96 to 35, Frost 83 to 33, Doom 71 to 24.
- **The Family, spaced out and reskinned:** brawling goons keep 0.9m apart (each steps half out of any overlap) and step out of monsters (`Enemy.body_radius()` plus 0.35m; reach counts from a big monster's edge); they used to pile into one spot, through each other and their target. Their hits show plain numbers (no "FAMILY" caption). They (and Cousin Vinnie) now wear the Ghoul Brawler's build in ghostly green: trunks, title belt, boxer arms with wrapped fists, and a banded fedora. They fight like Ghoul Brawlers, only faster: guard up, the Brawler's combos (jabs, crosses, hooks, uppercuts) with its arm poses and torso twist, still a punch every 0.55s on average.
- **Unbroken, fixed:** it promised the combo can't drop, but only the combo timer and the same-hand rule respected it: getting hit, a slipped punch and a shield still reset the combo to 0. Now nothing drops it while it lasts (`Player._set_combo` ignores drops); a knockout or a new bout still clears it. Checked in `card_runtime_regression`.
- **Temporal Break, diminishing returns:** a fast player could keep time stopped. Each refund is x0.8 of the last (was x0.9: about 1.25s bought back at most, was 2.5s), refunds never push the clock past where it started, and a Temporal Break used within 30s of the last one's end lasts 25% less, stacking down to half (its call-out shows "-25%"). Checked in `card_runtime_regression`: 60 alternating punches leave under 2.4s on a 1s clock, and one right after the last is shorter.
- **Browser bench:** `?bench=fx` fires each ultimate and power in a crowd and prints frame numbers for each (a hidden browser tab throttles the game to about 1 fps, so it has to be on screen).

## Endless pay and the Stray's dash punches (2026-10-29)
- **Endless runs paid more every wave and floor:**
  - **Arena:** each wave moved pay 0.25 of a tier up the climb (about 35% more a wave, 1.35^20 by wave 20), while monsters toughened only about 3% a wave.
  - **Crypt:** past floor 10, pay climbed a tier every two floors (about 2.25x a floor), and the monsters ramped from your own starting bracket.
  - A level-1 fighter with good gear and a big coin web went dozens of waves deep and came out with 12.8M coins and 37 levels.
- **Pay is flat now:**
  - Every knockout in an endless bout (every division's) pays what bout 3 pays, and the purse is score x that pay.
  - Endless Crypt floors pay what floor 10 pays: coins, XP, Souls, and drill pay from your deepest floor.
  - There are no diminishing returns.
- **Monsters keep growing** (`Progression.endless_growth`, HP and damage):
  - **Arena:** +7% a wave, and the rate rises 2% every 5 waves. Wave 1 to 2 is +7%, wave 5 to 6 +9%, wave 10 to 11 +11% (about 7x by wave 21).
  - **Crypt:** +7% a floor past floor 10, and the rate rises 2% every 2 floors. Floor 11 to 12 is +7%, floor 12 to 13 +9%.
  - **Where the Crypt starts:** endless floors build on the top bracket's floor 10, whatever bracket the run started in.
  - Checked in `balance_regression`.
- **The Stray's dash punches:**
  - **Spear Jab reach:** 3.5m, was 5m. Spear Line now adds 50% (5.25m); it used to double the reach (10m).
  - **Cooldowns:** Spear Jab 2s, Haymaker 4s; before, there were none, and chained Haymakers kept everything knocked back. On cooldown, a dash punch is a plain punch.
  - **Passive chip:** reads READY, or "L 1s  R OK" (left Spear Jab, right Haymaker).
  - Checked in `card_runtime_regression`.
- **The True Coffin King, fixed:** a burn (or any damage over time) could kill him while he hopped out to tag. That ended the round, and the tag-in that followed used the next round's contender, so the Plague Doctor never showed and the Insano round had two Coffin Kings.
  - Before tagging, his HP can't drop below half (`Enemy.hp_floor`), so one huge hit can't skip the tag-in.
  - Out of the ring he can't be hurt, and his burns, poison and doom go out (`Enemy.clear_statuses`).
  - The tag-in checks the round hasn't changed. Checked in `dead_league_regression` with a real bout.
- **The True Coffin King is built for a maxed fighter:** he was tuned for `Progression.true_par` (a level-29 build with 90% of the web). A maxed fighter (level 51, every card at full rank, every attribute, the whole web) rated 10-18x his offense and 3-4x his defense, so every round melted in seconds.
  - **The tuning:** he and his tag-ins now take a maxed fighter's offense ratio in HP and the square root of its defense ratio in damage, measured per class (`DeadLeagueBoss.TRUE_MAXED`, from `PowerRating.maxed_over_true_par`).
  - **With a maxed fighter:** HP is a third of the maxed offense ratio (`TRUE_HP_SHARE` 0.33; the full ratio was too tanky), about 3.4-6.1x, and damage 1.6-1.9x. Combo Master is x4.9 HP, the Catalyst x6.1.
  - **Fixed:** he doesn't grow with you, so you need to be near maxed to beat him.
  - `balance_regression` re-measures each class and fails if the tuning drifts more than 15%.
- **Insano, harder:**
  - HP and damage by round: 1 / 1.16 / 1.34 / 1.5 / 2.2x HP and 1 / 1.08 / 1.17 / 1.25 / 1.4x damage (`TRUE_ROUND_HP` / `TRUE_ROUND_DAMAGE`). Rounds 4 and 5 used to be round 3's.
  - Insano tells 25% quicker (was 15%), and pauses between combos 60% shorter.
  - At half HP, "NO MORE GAMES!": tells 15% quicker again and 15% faster footwork, and the burning floor comes 40% sooner with 25% less warning.
  - The floor burns every 2.2-3.4s (was 3-4.5) and warns 1.2s. It burns a flat 5 damage a second while you stand in it (`BURN_DPS`; a share of his punch was far too much).
- **Reading a busy fight:** with a maxed build, the boss stayed white and the screen filled with numbers.
  - **Floating text** (`DamagePopup`, second pass):
    - **Numbers:** every number landing within 1.8m of a live stack, within 0.5s of its last hit, adds to it, whatever its caption or color, for up to 2s. Each monster shows one growing number. (Undone 2026-10-30, after the text cleanup: every hit floats its own number again.)
    - **Callouts:** a caption ("ECHO", "SPEAR") or a word ("STUNNED") goes up at most once per 0.9s near the same spot.
    - **A cap:** at most 14 labels at once (10 in browsers); past that only big ones (K.O.!, contender calls) still pop.
  - **Particles:** every hit burst throws 55% of what it did (`HitFx.SHARE`), and no more than 160 particles go out per 0.25s (90 in browsers). Past that, bursts shrink or are skipped. Burst meshes are shared by color, glow and size (each burst used to build its own material). Burning and frozen monsters' motes are halved.
  - **Lag from the Dead Weight glow:** every monster redid every mesh's overlay every frame, checking Dead Weight through every effect each time. Now overlays change only when a flash, freeze or mark starts or ends, and the weakness is checked once per mark.
  - **Boss hit flashes:** half as bright (14% white, was 30%) and at most every 0.3s (`BOSS_FLASH_GAP`).
  - **Frozen bosses:** no blue sheen; the ice drifting off them shows it.
- **Dead Weight (Death Mark) reworked:** a Doom-marked monster deals 25 / 30 / 35% less damage (3 levels, was 1; `Powers.DEAD_WEIGHT`, applied in `Player.receive_attack`). While weakened it glows faint purple (`Enemy._rest_overlay`).
  - It used to slow marked monsters with a chill, which also gave them the frozen look, so bosses under Doom stayed pale white.
  - Reaper now needs it at level 3.
  - Checked in `card_runtime_regression`.
- **Flame Burst, harder:**
  - **Damage:** each blast does 10x your damage (was 5x; Flame Burst II goes off twice).
  - **Stun:** everything in it is stunned while the flash blinds you. Bosses are stunned for 1s even through their poise (`Enemy.stun` `through_poise`); everything else is still blasted up and knocked down 1.6s.
  - Checked in `card_runtime_regression`.
- **The tutorial, fresh and easier** (`training.gd`):
  - **The steps:** Move, Jab and Cross, Set It Up, Combos (2 drills), then the dodges for your mode, then Counter, Read the Combo, Ultimate and three fights.
    - Weenie Hut Junior Mode: one Dodge step, Q / E on any glove.
    - Pro Gamer Mode: Slip, Roll and Back Step, 2 each.
    - Clean Dodge and Fight Speed are gone.
  - **Easier:** fewer reps everywhere, and slower tells (1.4-1.6x the windup).
  - **The fights:** the dummy steps out and the ring comes down, so the monsters move as they do in the Arena: one fights while the rest circle about 3.8m out, waiting their turn. Real monsters come in 7m ahead of you.
    - Take Turns: two zombies; only one fights at a time while the other waits.
    - Slip the Arrows: a skeleton, at its usual range.
    - Dodge the Combo: a weak brawler, its tells 1.5x slower.
  - **Tutorial stats:** monsters go down in 6 punches whatever you hit for, a counter counts 1.5, and burns and the like don't hurt them (`Enemy.hits_to_ko`). Every hit you take is a sixth of your knuckle HP (`Player.fixed_hit`).
  - Checked in `card_runtime_regression`.
- **New-player onboarding** (one-time tips, `Tutorial`):
  - **The tutorial pays:** finishing it the first time pays the cheapest upgrade on the web (`GameState.cheapest_upgrade`, 60 coins: Taped Up). Skipping pays nothing; skippers learn the hard way.
  - **First camp visit:** "YOUR FIRST UPGRADE" points at the Buy button and closes when you buy. Then "THE DEAD LEAGUE": challenge the next contender whenever you like, as often as you like; beating them is how you progress (each win breaks a seal: the next Arena division, new upgrades and more).
  - **First attribute points:** one card on the Attributes tab: 3 points a level, a small boost each, and perks at 10, 20 and 30.
  - **First Crypt run:** "GILD TO KEEP", 1.5s in: finds are bound to the Crypt and crumble if you leave or go down, unless gilded with silver at an altar (each floor's first room and by each boss).
  - **The Armory tab is hidden** until you bring home your first gear (kept or worn).
  - Checked in `card_runtime_regression` (the tutorial's pay).
- **No hiding behind scenery:** monsters have no pathfinding, so since buildings went solid (2026-10-28) they piled up behind crypts, fences and the Ossuary's pillars while you hit them from the other side. One Bone Division endless run went 400+ knockouts that way.
  - Scenery collision (`Scenery.solid`) is on its own layer (`Scenery.LAYER`, layer 4): it stops you, and monsters walk straight through it.
  - Its walls reach 8m (`WALL_HEIGHT`) so nobody stands on a roof out of reach.
  - The Ossuary's giant ribcages are solid now (you could stand inside one).
  - The emote camera, the jumps past a monster and Highlight Reel's line of sight still see buildings.
  - Checked in `balance_regression`.
- **No perching:** standing on a prop (a Crypt chest, altar or table, or any scenery) for 1s shoves you off, away from its middle (`Player.PERCH_TIME` / `PERCH_SHOVE`).
  - Props are tagged `prop`: `Scenery.solid`, and the Crypt's prop bodies (`_add_solid` without a wall or floor body).
  - The check looks straight down, since standing still leaves no slide collision.
- **Blood only heals from your own knockouts:** kill heals (Blood Moon and its line, Bloodsoaked gear, the Fruit Hat) count only monsters your punch put down (`Player.kill_heal`, meta `punched_out`). Fire bursts, burns, chains and other blasts heal nothing; a Fire burst used to heal you once per monster in it.
- **Fire and Blood proc less often:** Fire's cooldown is 3s (was 1.5s) and Blood's 4s (was 2s). The Catalyst's cards respect Blood's cooldown for healing too.
- **Fighter picker hover:** hovering moved a card's pivot to its middle, which on shrunk cards (two rows) shifted the card down for good. The pivot stays put now; the card grows 3% and slides up-left by half of it, then back.
- All checked in `card_runtime_regression`.
- **Living Conduit reworked** (the Catalyst's legendary): it gave a power slot whatever the passive (Dual Sigil ran three, Attunement two), too strong. Now a power going off has a flat 10% chance to set off a random power you own. The card's effect value is the chance, so a rare or epic version would be 5%. Dual Sigil is two powers again, Attunement one.
- **Emotes show your fighter whole:** the third-person body is painted over a few frames from the start of a fight, so an emote in the first moments showed it appearing part by part. Starting an emote now finishes the painting first (`PlayerBody.finish_build`).
- **Feints:** a contender winds up a punch dark and silent (no lit glove, no blink), then, where its tell would flash, throws another instead. It's the other hand or another punch (`Boxer.FEINTS`: a jab feints into a cross or right hook, a hook into the other side or an uppercut). The real punch winds up for 0.3s, then lights up and blinks as usual.
  - **Who feints:** the Headless 12%, Sister Southpaw 18%, the Plague Doctor 15% and the Coffin King 20%, each +3% a round. The True Coffin King feints 25%, and 32% in Insano. The Bellman never does.
  - **Never:** while blind (the Plague Doctor's flash) or answering a slip.
  - Checked in `dead_league_regression`.
- **The Catalyst's floating runes are gone:** the arc of runes over his hands (`CatalystRunes`, on the camera) read as aiming reticles. The runes on his gloves still glow and flash his powers' colors.
- **Playground:**
  - Spawns can be elites or champions.
  - A True Coffin King button maxes the current fighter and starts his fight. Leaving the fight comes back to the playground: `DeadLeagueArena.leave_to` is set by the playground and is the League menu otherwise.
- **The Blur's Long Reach:** 3.2m plus 0.05m a point of passive power, up to 3.65m (was 3.8m plus 0.1m, up to 4.7m). Normal reach is 2.5m.

## The Tower and Rebirth (plan, 2026-10-29) [Planned]

The post-Coffin King game, as planned with the user. Nothing here is built yet.

### Unlocking: three seals
1. **Arena seal:** win every division's bouts, including the Crown's endless bout (50 knockouts).
2. **Crypt seal:** beat the new floor 10 boss, **Your Shadow**.
3. **Crown seal:** beat the Coffin King.

When all three are broken, the Tower opens, and so does Rebirth.

### Floor 10 boss: Your Shadow
- A dark copy of the fighter you bring, on `BossRig`.
- It's a simpler boss version of that fighter: the fighter's moves, their original passive and their ultimates. It doesn't get your cards or gear.
- Phases: plain boxing with the passive first; the ultimates come in below half HP.
- **Its time stop (if the fighter has Temporal Break):**
  - **The tell:** the Shadow winds up with its own animation, its hands glowing. The **R** prompt shows near the end of the windup, slightly before time stops, so a sharp press beats it and catches every punch.
  - **Once time stops,** every punch it throws tags you, to land when time resumes, until you press R.
  - **Press R:** you get a weakened time stop of your own. From then on you can dodge (not punch) the punches it throws; the earlier ones stay tagged.
  - **When time resumes,** every punch and dodge replays very fast, in order. A dodged punch opens a counter; a tagged one hits.
  - **With Temporal Break equipped and charged,** using it during the Shadow's stop cancels both out (your ultimate is spent).
- **Every big ultimate** gets a windup you can interrupt, or a zone you can leave.

### Rebirth
- **Who can rebirth:** a fighter at their max level, once the Tower is open.
- **What resets:** that fighter's level, cards and attributes.
- **What stays:** everything else (coin web, gear, Souls, coins, hats, skins, Tower paths).
- **Gilding:** at a rebirth you draw 5 copies from the cards you hold and gild 2. Rerolls cost Souls.
  - A common is 4 copies and a rare 2, so a fully gilded common takes 4 gildings.
  - 40 copies at 2 a rebirth is 20 rebirths to gild the deck.
- **A new life** starts with every gilded card already drawn. The level equals the number of gilded copies, with that level's attribute points.
- **Max level:** 41 in the first life (every card drawn), +2 per rebirth, up to 81 after 20 rebirths.
- **Attribute caps:** 30 + 1 per rebirth, up to 50 each, with a new perk at 40 in each attribute. Level 81 gives 240 points, about 48 in every attribute.
- **Faster lives:** the web and gear stay, so each life levels much faster. The Utility path adds XP gain on top.

### Legend
- **Earned with:** all 40 copies gilded and the fighter at max level (81).
- **Rewards:** Legend art replaces the fighter's character art, and their Legendary skin unlocks.
- **Art:** the user makes the Legend concept art and voxel refs; until then a placeholder gold-and-glow look.

### The Tower
- **100 rooms** in order, climbing out of the underworld.
- **Boss rooms:** every 5th room has a boss.
  - Rooms 25, 50, 75 and 100 have **Wardens** (big unique bosses).
  - The other 16 have **mini-bosses** (elite Tower monsters, a few designs remixed).
- **Checkpoints:** a beaten boss room becomes a checkpoint, where you choose Continue up or Leave. Camp's Tower button starts from any checkpoint you've reached.
- **Strength by floor, from the Coffin King's:** floor 1 already fights like the Crown. A fresh rebirth levels in the Arena and Crypt before pushing high.
- **Secret ending:** it moves to the top. Reaching room 100 as Tony in the Plumber Overalls and the Fat Plumber Cap plays the true secret ending.

### Rooms
- **Timer:** 1 minute per room.
- **Floor break:** at 10s left, cracks spread and tiles drop from the edges inward. At 0 the rest falls, and so do you, back to your checkpoint.
- **Knockouts** also send you back to the checkpoint.
- **Currency:** all Tower currency earned is kept, falls included.
- **Room types:**
  - **Fight:** new Tower monsters that try to stop you leaving.
  - **Obstacle course:** jumps, moving and crumbling platforms. Every course can be cleared without double jump or wall jump; those reach shortcuts and currency caches.
  - **Punch code:** circles on the wall spell a code (blue a straight, yellow a hook, red an uppercut; L or R in the middle for the hand). You punch it into a statue in the middle of the room.
  - **Pressure plates:** punch crates or coffins onto plates to open the door.
  - **Memory sequence:** a sequence lights up once; you repeat it from memory.

### Tower currency and the four paths
- **Name:** working name **Skyshards**.
- **Earned from:** room clears (more for faster ones), bosses, and caches in obstacle rooms.
- **The paths:** Agility, Power, Utility and Resilience, shared by every fighter. Their boosts work everywhere (Arena, Crypt and Tower).
- **Growth:** each stat in a path grows as boost = stat boost x log10(1 + shards sunk into the path). Every 10x more shards adds the same boost again.
- **Milestones:** sinking set totals into a path unlocks its milestones.
- **The path stats:**

| Path | Stats | Milestones |
|---|---|---|
| Agility | Move speed, jump height, punch speed, dodge / counter / combo windows | Double jump, wall jump |
| Power (proposed) | Damage, power damage, ultimate charge | to decide |
| Utility (proposed) | XP gain, coins, Souls, Skyshards, room timer seconds | to decide |
| Resilience (proposed) | Knuckle HP, damage taken, healing | to decide |

### Still to decide
- The currency's name.
- Milestone thresholds, and the Power / Utility / Resilience milestones.
- The four Wardens, the mini-bosses and the Tower monsters.
- The 40-point attribute perks.
- Whether path boosts count toward par. They're post-game power, so probably not.

### Build plan (2026-10-29)

Built on its own branch, **`tower-rebirth`**, and launched on itch in one go when it's all done. Each step ends playable and testable in the playground, and the user approves it there before the next step starts. Steps 5 and 6 can swap.

**How the branch works**
- **`main` stays live.** Bug fixes and small tweaks still go on `main` and follow the usual flow: commit, push, the Pages deploy, and itch releases when the user says release. `main` is merged into the branch after each fix, so the branch never drifts.
- **The branch** gets a commit and a push for each change, and runs all three test suites plus the new ones. It never runs `deploy_pages.sh` as is, since that would put unfinished work on the live web build.
- **A preview web build:** the branch deploys to `/next/` on the same Pages site, so the live build at the root stays untouched. Step 0 makes `deploy_pages.sh` keep the other half when it deploys.
- **Its own save:** the preview build saves to a separate file (`frightnight_next.json`), because a page on the same site shares browser storage with the live build. A save from the live build can be copied in once from a button, but never written back. The save version goes to 3 on the branch only.
- **The playground** mirrors whatever branch is checked out, so it always has the newest step.
- **Launch:** merge the branch into `main`, test the save upgrade on copies of real saves, write the devlog, then release.

**Step 0: Setup**
- Create the branch and push it.
- Make `deploy_pages.sh` take a target (`main` for the root, `next` for `/next/`) and keep the other one's files.
- Give the preview build its own save file and a "COPY LIVE SAVE" button in Settings.
- Add a **Tower & Rebirth** panel to the playground. Each later step adds its buttons there.
- A version tag on the title screen ("NEXT, step N"), so screenshots say what build they came from.

**Step 1: Three seals**
- Save fields: `tower_seals {arena, crypt, crown}`.
- **Arena seal:** set when every division's bouts are won, including the Crown's endless bout (50 knockouts). Saves that already qualify get it on load.
- **Crown seal:** set on a Coffin King win, including saves that already have one.
- **Crypt seal:** set by Step 2's Shadow. Until Step 2 is in, the playground can set it.
- A seal tracker in camp: three slots that light up, and a locked Tower door with "BREAK ALL THREE SEALS".
- **Playground:** a toggle for each seal.
- **Tests:** what sets each seal, the save upgrade, and that the door opens only with all three.

**Step 2: Your Shadow (Crypt floor 10)**
- **2a: The Shadow boxes.** A dark, glowing-eyed copy of the fighter you bring, on `BossRig`, using the same Dead League boss brain (tells, combos, feints, poise). It throws that fighter's punches and runs their original passive. It becomes floor 10's boss in place of the Lich King. Beating it breaks the Crypt seal. It's tuned to the floor 10 par build.
- **2b: The ultimates.** Below half HP it uses the fighter's two ultimates, simpler boss versions, each with a windup you can interrupt or a zone you can leave. Proposed counters, for the user to approve:

| Fighter | Ultimate | The Shadow's version | Answer |
|---|---|---|---|
| Mauler | Inferno Uppercut | Crouches, fist on fire, then leaps at you | Back step as it leaves the ground |
| Mauler | Brimstone Shield | A burning shield that explodes by what it soaked | Stop punching; back off before it bursts |
| Answer | Riposte Stance | Slips and counters every punch for a few seconds | Don't punch; wait it out |
| Answer | Flow State | Dodges everything for a while | Only counters land; bait and counter |
| Blur | Temporal Break | Time stop (below) | Press R, dodge, counter |
| Blur | Unbroken | A flurry that speeds up | Dodge the chain; the last punch leaves it open |
| Stray | Highlight Reel | Lightning dashes, each lined up first | Slip each line |
| Stray | Hype Train | A sprinting charge across the ring | Sidestep; it stumbles at the wall |
| Tony | Big Mouth | Insults you: it hits harder for a while | Play safe until it wears off |
| Tony | The Family | Three ghost goons join for 10s | Knock out the goons or outlast them |
| Catalyst | Elemental Fists | Punches glow a power's color | Each color has its own dodge |
| Catalyst | Flame Burst | Charges a ring of fire | Hit it to interrupt, or leave the ring |

- **2c: The time stop duel** (the Blur's Shadow), as planned above: glowing hands on the windup, the R prompt slightly early, tagged punches, your weakened stop (dodge but no punching), the fast replay of every punch and dodge, and Temporal Break cancelling it out.
- **Playground:** "FIGHT YOUR SHADOW" for the selected fighter, plus buttons to jump to the ultimate phase and to set off a given ultimate.
- **Tests:** a Shadow for every fighter, phase changes, each ultimate's answer works, the time stop's tagging and replay, the seal on a win, and a par-build win rate check in `balance_report`.

**Step 3: Rebirth**
- Per-fighter save fields: `rebirths`, `gilded {card: copies}`.
- **Max level** 41 + 2 per rebirth, up to 81. **Attribute caps** 30 + 1 per rebirth, up to 50.
- **The Rebirth screen:** shown at camp for a fighter at max level once the Tower is open. It says what resets (level, cards, attributes) and what stays (everything else), and has a big confirm.
- At this step a rebirth only resets. Gilding comes in Step 4.
- **Playground:** set the rebirth count and jump to max level.
- **Tests:** what resets and what stays, the caps, max level per rebirth, and par untouched.

**Step 4: Card gilding**
- **At a rebirth:** draw 5 copies from the cards you hold and gild 2. Rerolls cost Souls.
- A common holds 4 copies and a rare 2. Gilded copies show as gold pips on the card.
- **A new life** starts with every gilded card drawn. The level equals the gilded copies, with that level's attribute points.
- The Deck page shows the gilded count, e.g. "GILDED 12 / 40".
- **Playground:** "GILD ALL" and a set gilded count.
- **Tests:** copies per rarity, a new life's level and points, rerolls, and no gilding past full.

**Step 5: Legend and the 40-point perks**
- **Needs the user:** the four 40-point perks (one per attribute).
- **Legend:** earned with all 40 copies gilded at level 81. It uses a placeholder gold-and-glow look until the user's art and voxel refs arrive. Their Legendary skin waits for the skins work.
- **Playground:** "MAKE LEGEND".

**Step 6: The Tower's frame**
- A Tower scene: one room at a time, climbing (an underworld-to-sky look that brightens as you go).
- **Rooms:** a 1 minute timer per room. At 10s left the floor breaks from the edges in; at 0 you fall back to your checkpoint. Knockouts also send you back to the checkpoint.
- **Bosses and checkpoints:** a boss every 5th room. A beaten boss room is a checkpoint offering Continue or Leave, and camp's Tower button starts from any checkpoint you've reached.
- **Strength:** room 1 fights like the Coffin King's par, growing per room.
- **Skyshards:** earned from clears (more for fast ones), bosses and caches, and kept through falls.
- At this step every room is a fight with Crypt monsters, and the bosses are stand-ins.
- **Playground:** "TOWER ROOM N", and a timer toggle.
- **Tests:** the timer and floor break, the fall, checkpoints saved, scaling per room, and shards kept.

**Step 7: Room types**
- **7a, Obstacle courses:** jumps, moving and crumbling platforms. Each is clearable without double jump or wall jump; those reach shortcuts and caches. Built from hand-made room pieces.
- **7b, Punch code:** wall circles (blue straight, yellow hook, red uppercut, L or R in the middle) punched into a center statue. A wrong punch resets it, with a buzz.
- **7c, Pressure plates:** punch crates or coffins onto plates to open the door.
- **7d, Memory sequence:** a sequence lights up once and you repeat it.
- **A room mix per stretch of the Tower:** puzzles start easy and get longer codes and sequences higher up.
- **Playground:** "TOWER ROOM: type".
- **Tests:** each room's win and fail, and that every course can be cleared without double jump (a scripted path).

**Step 8: The four paths**
- **Needs the user:** the currency name, milestone thresholds, and the Power, Utility and Resilience milestones.
- **The camp Paths page:** four columns of stats. Boost = stat boost × log10(1 + shards sunk), with milestones marked.
- **Agility milestones:** double jump and wall jump, which also open the obstacle shortcuts.
- **Boosts work everywhere** but don't count toward par, so Arena, Crypt and Dead League tuning stays as it is.
- **Playground:** set the shards in each path.
- **Tests:** the log growth, milestones, boosts applied in each mode, and par untouched.

**Step 9: Tower monsters and mini-bosses**
- **Needs the user:** monster ideas and art.
- **New Tower monsters** that try to stop you leaving: they guard the door, push you to the edge and slow you. Then 16 mini-bosses, a few designs remixed.
- **Playground:** spawn buttons for each one.
- **Tests:** each monster's tells and answers, and the no-stun-lock rule for each.

**Step 10: The four Wardens (rooms 25, 50, 75, 100)**
- **Needs the user:** Warden designs and art.
- One Warden at a time, each with its own arena and rounds, built like the Dead League bosses.
- **Playground:** "FIGHT WARDEN N".

**Step 11: The secret ending moves up**
- Reaching room 100 as Tony in the Plumber Overalls and the Fat Plumber Cap plays the true secret ending. The old trigger is removed.
- Tested by a playground jump to room 100.

**Step 12: Balance and the full climb**
- `balance_report` grows a section each for rebirth pacing (time per life with the web and gear kept), Tower scaling per room against path boosts, and the Shadow's and Wardens' par checks.
- Run full climbs: a fresh save to the Tower, a few rebirths, and room 100.
- Onboarding tips for the seals, the Tower, Rebirth, gilding and the paths.

**Step 13: Launch**
- Merge into `main` and test the save upgrade on copies of real saves (the user's and the brother's).
- Run the full test suites, store shots and a trailer cut (with no Shadow of Tony and no secret ending).
- A combined devlog, then `release.sh`.

**Decisions by step:** Step 2b the ultimate counters (the table above); Step 5 the 40-point perks; Step 8 the currency name, the milestones and their thresholds; Steps 9 and 10 the monsters, mini-bosses, Wardens and their art; Step 5 the Legend art (a placeholder until then).

## In-engine art (2026-10-29)

Art rendered from the game's own models in the playground (`playground/src/character_lab/`), no painted images:
- **Dead League:** the menu's key art (all five contenders in a ring in League order, posed, glowing in their colors, monsters crowding the ring), the locked shadows (each contender's real silhouette, softened) and the five portraits (loading screen and versus splash). `league_art.tscn -- --capture`.
- **The True Coffin King's portrait** (`portrait_true.png`, Insano Style in his burning ring): a loading card that joins the rotation only once he's been beaten (the "true_king" achievement), and always shows heading into his bout.
- **Full-screen loading scenes** (`Loading.SCENES`): the four fighters on the graveyard set, and the Dead League ring; they creep in like the portraits, the words on the left.
- **Key art** for the store (`key_art.tscn`): the revamp fighters in action poses on the graveyard set (the Mauler's embers and fire ring, the Answer's lightning, the Blur's purple echo fists, the Stray's swirl), monsters among the graves, the spooky title. Banner 2172x724 and 1080x1440 portraits, in `store_assets/` (not committed).

## The fighters' new bodies (2026-10-30)

All six fighters' third-person bodies are rebuilt in large, clean cubes (`FighterBody`, `fighter_body.gd`, on PlayerBody's pivots plus ankles; prototyped in the playground 2026-10-29 and picked over tiny and medium cube sizes). Used everywhere the body shows: emotes, the Emotes stage, the princess rescue and the secret ending.
- **Sizes:** the Mauler biggest and tallest, the Catalyst big, the Blur small and lean, Tony short; the cubes are the same size in the world on everyone.
- **Rules:** flat, deliberate colors (no random speckle), no overlapping parts, one-cube trim lines, wraps painted on the forearm, a straight lead foot and a rear foot turned out.
- **Hats:** hair in zones split at the hat line; caps and crowns hide what's above it, masks and wigs all of it. The Blur and Tony swap to a short cut under a cap or crown; the Stray keeps his headband (tied round the outside of a mask).
- **Character art:** the select cards, versus panels and fighter loading cards are in-engine renders of the new bodies in signature poses (`key_art.tscn -- --select`): the Mauler's gloves knocking, the Answer reading you, the Blur's echo-fist flurry, the Stray's crouch, the Catalyst's fireball, Tony's "come on".

## Wording pass (2026-10-30)

- **Floating text:** punches no longer say their own name (no "HOOK!", "UPPERCUT!", "LUNGE!", "SPEAR JAB!"). A crit is a red number with a "!" ("152.3!"). Damage from a power, ultimate or card is just its number in that source's color (`Enemy.source_color`; Doom purple, fire orange, and so on), and damage over time drops its word too. Words stay for your own moments: counters, finishers, weak spots, SLOPPY, and the knockout lines (GOODNIGHT!).
- **Text:** taglines, contender bios, taunts, defeat lines, loading lines, skin blurbs and class traits rewritten plainer and less punny ("Ding ding, meat" is gone). Stale text fixed: the tutorial prompt (real fights now, not just a dummy), the Crypt unlock note (finds must be gilded) and the ultimates' one-liners on the title screen.

## Set-ups follow real combos (2026-10-30)

A hook or uppercut is set up (its full hit and stagger, not SLOPPY) when it comes:
- right after a jab or cross, with either hand (jab, left hook);
- right after a set-up hook or uppercut, either hand (two hooks or two uppercuts in a row);
- with the hand on the side you just slipped or rolled to, within 1.2s (slip right, right uppercut; roll left, left hook), even to open.

Head movement keeps a combo alive (a slip or roll refreshes its timer), and the same hand twice no longer breaks the combo after a set-up heavy or a slip or roll in between. So jab, cross, left hook, roll left, left hook and jab, cross, slip right, right uppercut are full combos. A hook thrown cold, and an uppercut after a cold hook, are still SLOPPY. Tested in `card_runtime_regression` (`_test_combo_setups`).

Also: the Hat Rack's Yonkers counter is gone; the words over a monster when a power goes off (IGNITE!, DOOMED!, MARKED, CHILLED...) are gone, the effects show it; unclear hat and upgrade text rewritten (the Witch's Hat, Cornerman, Chin Check, Calloused, Crowd Pleaser, Death Mark), and two hat lines that quoted a film and a song are reworded.

## Hit freezes and first-use stalls (2026-10-30)

An itch player called out "a half second pause on every hit". Two causes:
- **Hit freezes** (`TimeFx.hitstop`): every landed punch froze the game 0.03-0.19s, and the Slow motion setting didn't reach them. Now they run at half length and follow the setting (0 turns them off along with the slow-mo). On a slow computer a freeze lasts at least a frame, so they read as lag.
- **First-use stalls:** `FxWarmup` (run while the loading screen still covers a fight) now also puts a stand-in monster through a hit, a crit, a chill and a Doom mark, sets off each of your selected powers on it, and shows a knockout line, so their effects are compiled before the first punch.

**Tutorial:** the JAB AND CROSS step says punching monsters isn't good for your knuckles but has to be done, points at the knuckle HP bar (a pulsing gold frame and a "YOUR KNUCKLE HP" tag), shows each punch's cost and flashes the bar as it drops. The COMBOS step says the longer the combo, the harder you hit (counters and set-ups are already their own steps).
