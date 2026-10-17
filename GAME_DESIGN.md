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

**Default dodge scheme is now Space + A / D / S / W** (playtesters liked it best; jump is on C). Settings saved before this change switch to it once.

#### Key bindings [Built 2026-10-16]
- **Weenie Hut Junior Mode jumps with Space.** Q / E do every dodge there, so there's no dodge modifier. Dash is a double-tap of W, or its own key.
- **Every action can be rebound** in Settings → Controls → Key bindings: move, sprint (also the hook modifier), jump, jab, cross, hook, uppercut, dodge/slip left and right, and dash. Pro Gamer Mode adds the dodge modifier, roll left/right and back step. Plus ultimate, use and map. Click a key, press the new key or mouse button, and Esc cancels.
- **Conflicts swap.** Taking another action's key gives that action yours. "Reset keys" clears them all. Rebound keys show in gold.
- **The hints follow.** Every hint (HUD line, pause Controls tab, tutorial keycaps, dummy cues, Temporal Break prompts) uses `Controls.key_name`.
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
- **Prompts follow the device.** `Pad.active` flips to the controller on any button or stick and back on any key, click or mouse move. Every hint swaps live through `Controls.watch()`: tutorial keycaps (`<move>`, `<jab>`...), practice card, pause Controls tab, ultimate gauge, dummy cues, Crypt "use" prompts, Temporal Break prompts, title card. PlayStation pads get PlayStation names (detected by name or Sony's vendor id).
- **Menus: a controller cursor.** Whenever a fight isn't running, the left stick (or D-pad) moves a gold pointer. A / Cross clicks (hold to drag, e.g. panning the upgrade and skill webs; double-tap buys a node). The right stick scrolls and zooms, and B / Circle backs out. It sends real mouse events, so every screen works, the browser included.
- Fights pause on a dedicated `pause` action (Esc / Start), not `ui_cancel`, which B also sends.

#### Control schemes [Testing, 2026-10-11]

Settings → Controls has three dropdowns, so layouts can be mixed and tried before choosing the default. The code is in `controls.gd`, which rewrites the InputMap. The HUD controls line, tutorial hints, Temporal Break prompts and demo reel captions all follow the chosen scheme.

| Setting | Options |
|---|---|
| **Hooks / uppercuts** | **Hold Shift / Ctrl + click** (classic) · **Scroll wheel**: down = hook, up = uppercut · **Mouse side buttons**: front = hook, back = uppercut |
| **Rolls / back step** | **Ctrl + A / D / S** (classic) · **Space + A / D / S / W** (W dashes; jump moves to C) · **Double-tap A / D / S** · **Tab left roll / R right roll / Ctrl+S back step** (ultimate moves to T; map moves to M) |
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
- A run of plain grounded jabs/crosses grows the combo for its first **4 hits**. More straights keep the timer alive but do not raise the count or trigger combo powers until the player mixes in a set-up heavy, counter, dash jab or air punch. This keeps jab/cross useful without letting the safest two-button loop scale forever.

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
| Combo Master | **Temporal Break** | Every enemy (and projectile) freezes, the screen tints, and a ring timer starts at 3s. A punch prompt appears (JAB = LMB, CROSS = RMB, HOOK = Shift+click, UPPERCUT = Ctrl+click, with a hand). The right input lands a hit on the next frozen enemy (cycling, nearest first), adds +2 to the combo and gives back 0.5s (each refund x0.9 of the last); the clock runs 12% faster per hit. A wrong input costs 0.5s. When it ends, everything that was frozen is stunned for 1s. |
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
- **Class picker:** four cards with icon, level, description, stat changes, and the ultimate with what it does. Click a card or CHOOSE. The camp no longer has a Class tab; its **Menu** button goes back to the title.

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
     - Level-7 Counter Master (≈12 damage, 110 knuckles): floor 1 always cleared; floor 2 too steep (died on floor 2 in 2 of 3 runs). → Floors ramp gentler (progress step per floor 0.25 → 0.15, +1 enemy per room per floor instead of +2, floor HP growth 0.4 → 0.3), **clearing a fight room heals 10% max knuckles**, and floor 1's entrance has a **starter chest** (uncommon+, never a mimic or cursed). After: floors 1–2 cleared every run, runs end around the floor 3 Lich King.
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
- **Combo variety:** only the first 4 consecutive plain grounded straights grow the combo. A set-up heavy, counter, dash jab or air punch resets that straight run. Same-hand repeats still break the combo.
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
- **Ten floors**, two per tier, then endless. The camp's **Crypt** button picks a starting pair (floors 1-2, 3-4 and so on); a pair opens once its tier is reached.
- Enemies climb to 40% of the way to the tier's contender on the pair's first floor and 80% on the second.
- **Souls show on the Crypt HUD** (top right, beside silver) and count up as bosses drop them, since the altars spend them.
- **Your worn gear comes in with you.** Anything found this run is **bound** to the Crypt.
- **Gilding altar:** in every floor's first room. Gilding a find costs Souls plus silver by rarity:
  - Souls: common 1, uncommon 1, rare 2, epic 3, legendary 5, cursed 3.
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

The upgrade web has four **Sigil nodes**. Each costs coins and opens with a Dead League seal (Fire after the Bellman, Frost after the Headless, Storm after Southpaw, Blood after the Plague Doctor), and **unlocks a power**. The nodes past it are that power's upgrades, split into branches. The other parts of the web have no seals any more (heavy hitting, economy, Champion's Belt are open).

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
- **Hat Rack:** a camp tab with owned hats on pegs and missing ones as silhouettes.
- **Roster draft:**
  - Commons: Party Hat, Traffic Cone, Shower Cap, Propeller Beanie, Lampshade, Bucket.
  - Uncommons: Bowler, Chef's Toque, Viking Helmet, Pirate Tricorn.
  - Rares: Top Hat (bunny inside), Tinfoil Hat, Hard Hat.
  - Epics: Paper Crown, Witch's Hat, Grim Reaper's Hood, and the **Fruit Hat**: a towering voxel fruit basket (pineapple leaves, oranges, a banana, grapes, cherries, strawberries) on a ruffled hot-pink brim with pink and yellow ruffles trailing down. "Five servings a day. Too late for this guy." +4% max knuckle HP and +1 heal on kill.
  - Added 2026-10-17:
    - **Big Monkey Mask** (epic): a big rubber monkey head over the whole head, with a heavy brow, wide eyes, a toothy grin and round ears. "Ook. The dead find it deeply unsettling." +3% damage, +3% dodge window.
    - **Strong Guy Wigs:** big blocky spiked hair. The black one fans out every way; the powered-up colors stand straight up and taller.
      - Black (common): +1.5% damage. "Spiky. Suspiciously heroic."
      - Blonde (uncommon): +2.5% damage, +2% ultimate gain. "Took three episodes of screaming to put on."
      - Blue (rare): +3.5% damage, +3% ultimate gain. "Dyed. Don't tell anyone."
      - White (epic): +6% dodge window, +8% counter damage. "It moves on its own. So do you."
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

**Secret:** typing FUGGEDABOUDIT anywhere in Settings unlocks Tony (with his unlock screen; the title reloads so he's in the picker).

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

Hold **Emote** (G; View / Create on a controller, plus D-pad down in Weenie Hut Junior Mode, where it's free; in Pro Gamer Mode it's the back step) for the emote wheel, steer with the mouse or right stick, and let go on a dance. The camera pulls out to third person (about 0.35s, Destiny style) around your fighter. The mouse or right stick orbits the camera. Moving, punching, dodging, jumping, the ultimate or getting hit ends the dance and glides the camera back. Emoting works mid-fight; you're open while you dance. A quick tap repeats your last dance (or stops one). On a controller, a tap opens the map where there is one (the Crypt, the tutorial's dummy cycling), since the map gave up its own button.

**Dances** (`emotes.gd`, keyframed poses eased in a loop, mirrored with `Emotes.mirror`):
- The Default
- Dab
- Nae Nae
- Floss
- Take the L
- Griddy (heel taps, then the goggles)
- Horse Ride (reins hop, then the lasso)
- Running Man
- Bros. Shuffle (the Mario & Luigi dance: fists bouncing at the chest, knock-kneed sway, alternating fist pumps)

**Tightened 2026-10-17:** the dances were stiff from the front, because knee bends and hip dips happen front to back, and the feet sank into the floor.
- `PlayerBody._plant_feet` now keeps the feet on the canvas: dropping the hips bends the knees, and swaying them sideways leans the legs.
- Every dance moves in the frontal plane: wide hip sways, arms out to the sides, sideways kicks.
- Timing is snappier, about 0.15-0.2s a beat.
- The Nae Nae has a big overhead wave, a loose low arm, and a hip-to-hip rock with a knee pop into each side.

**The body** (`player_body.gd`) is voxel blocks like the enemies, dressed after each card:
- The Mauler: bare chest, red trunks, red gloves taped white, orange eyes.
- The Blur: dark top, violet sash, spiky hair, violet eyes.
- The Answer: black jacket, white belt, blue gloves, ice eyes.
- The Stray: a mop of locs, red headband with tails, green sash, taped fists, green eyes.
- Tony: black tracksuit with white stripes, white tee, gold chain and pinky ring, beanie, stubble, red nose.

It renders on its own layer, so the lantern at your eyes doesn't blow it out; a soft fill on the emote camera lights it. No crosshair while the camera's out.

**Wear a hat:** click an owned hat on the Hat Rack to wear it (WEARING tag, gold border); click again to take it off. It shows on your fighter when you emote (Tony's beanie comes off for it). It's cosmetic only: every owned hat's boost already counts. Saved as `worn_hat`.

**Enemy labels (2026-10-17):** the Armor number is gone from enemy name tags; the gear on the body says it. The damage-reduction line stays.

## Launch readiness [In progress, 2026-10-15]

Checked: every main scene (title, camp, Arena, Crypt, training, Dead League menu and arena) runs 400 frames headless with no script errors, and the web build loads with no console errors (38 MB wasm + 15 MB pck; itch serves them compressed).

Done:
- **Auto-pause:** clicking or tabbing away mid-fight opens the pause menu (`Hud._notification`), so nothing beats you up while you're gone.
- **Credits** on the title menu (`credits.gd`): made by, built with Godot and the Anton font, and the license notices the engine (MIT, plus its third-party components) and the font (OFL) require.

- **Versions and releases (2026-10-16):** the version lives in `project.godot` (`config/version`, now 0.9.0) and shows in the title screen's corner. Every change goes to GitHub Pages as the dev build (`deploy_pages.sh`, the `Web` preset, "DEV BUILD" in the corner). itch only gets a build on release: `bash release.sh <version>` exports the `Web Release` preset (the `release` feature tag hides DEV), pushes it to itch with that version, then commits and tags `v<version>` on GitHub.

Still open:
- Real sound effects and music (placeholders now; the Sound Lab is ready to audition them).
- Painted upgrade and skill icons (`art/icons/ICON_PROMPTS.md`).
- An ending for beating the Coffin King (right now it's one line and the Crown ring opening).
- Save backup: web saves live in browser storage and vanish if it's cleared; an export/import code in Settings would protect them.
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
