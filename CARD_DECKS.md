# Fright Night — Card Decks [Built 2026-10-25, updated 2026-10-27]

Each fighter's deck for level-up draws (see "Level-ups: the card draw and attributes" in GAME_DESIGN.md). Every deck is 40 cards (20 different cards):

- **5 commons** (4 copies each, ranks I-IV): steady upgrades to the fighter's own game that work with any loadout.
- **5 rares** (2 copies each, ranks I-II): change how a move works.
- **5 epics** (1 each): one for each of the fighter's three passives and two ultimates, so your hand pulls you toward a loadout.
- **5 legendaries** (1 each): one joins the deck as each Dead League seal breaks (Bellman, Headless, Southpaw, Plague Doctor, Coffin King).

**The rule:** no card gives what a Sigil power (burn, freeze, lightning, heal on kill) does, or copies a coin-web or gear special or an attribute perk. Commons can give plain stats (damage, knuckle HP, speed); everything else builds on the fighter's own kit.

Numbers are tuned against POWER and par (`balance_report.gd`): every fighter's typical hand is worth about the same. The tables below are generated from `punch-craft/cards.gd`, so they match the game.

**Shared legendary, Ultimate Surge:** your ultimate starts every bout a quarter full, and using it gives a quarter back. Every deck has it as the Southpaw legendary (the old seal skill).

---

## The Mauler

Grudge / Wrecking Ball / Berserker / Inferno Uppercut / Brimstone Shield. A brawler who takes the hit and gives it back.

**Commons (ranks I/II/III/IV)**
| Card | Tag | Effect |
|---|---|---|
| **Payback** | Power | Your first punch after taking a hit deals +12/24/36/48% |
| **Heavy Hitter** | Power | +4/8/12/16% damage |
| **Thick Hide** | Defense | Hits deal 2/4/6/8% less to you |
| **Short Fuse** | Ultimate | Taking a hit fills your ultimate by 3/6/9/12 |
| **Mob Magnet** | Power | +2/3/4/5% damage for every monster within 3m (up to 3) |

**Rares (I-II)**
| Card | Tag | I | II |
|---|---|---|---|
| **Hold the Line** | Defense | Hits make you flinch half as long | Hits can't make you flinch |
| **Lights Out** | Power | Staggered monsters take +20% from you | Staggered monsters take +40% from you |
| **Haymaker Swing** | Power | Hooks also hit every monster in a wide arc in front of you, for 20% | Hooks also hit every monster in a wider arc in front of you, for 35% |
| **Shoulder Charge** | Movement | Dashing into a monster knocks it back and hits it for your base damage | Dashing into a monster knocks it far back and hits it for 2x your base damage |
| **Second Breath** | Rage | Below 30% knuckle HP, punches cost nothing | Below 40% knuckle HP, punches cost nothing |

**Epics**
| Card | Upgrades | Effect |
|---|---|---|
| **Blood Feud** | Grudge | Grudge: every hit from the marked monster adds +1x to your Grudge punch on it, and the Grudge punch staggers everything within 3m |
| **Strike!** | Wrecking Ball | Wrecking Ball: bowled monsters stay down longer, and a strike of 3 or more fills a quarter of your ultimate |
| **Red Mist** | Berserker | Berserker: the lower your knuckles, the faster you punch too (up to +40%) |
| **Inferno II** | Inferno Uppercut | Inferno Uppercut: after it lands, you leap at a second monster |
| **Brimstone Wall** | Brimstone Shield | Brimstone Shield: holds 1 more hit, and every hit it soaks hits the attacker back for your base damage |

**Legendaries**
| Seal | Card | Effect |
|---|---|---|
| Bellman | **Thrill of the Fight** | Every monster within 4m makes hits deal 5% less to you (up to 25%) |
| Headless | **Juggernaut** | Above half knuckle HP, hits deal 25% less and can't make you flinch |
| Southpaw | **Ultimate Surge** | Every bout starts with your ultimate a quarter full, and using it gives a quarter back |
| Plague Doctor | **Avalanche** | Every 4th punch you land shoves every monster in front of you back and staggers them, for a quarter of your base damage |
| Coffin King | **Berserk** | Once a bout, dropping below half knuckle HP makes you hit twice as hard and take half damage for 8s |

---

## The Answer

Perfect Counter / Phantom Step / Dodge Chain / Riposte Stance / Flow State. Slips, rolls and back steps; counters off a dodge.

**Commons (ranks I/II/III/IV)**
| Card | Tag | Effect |
|---|---|---|
| **Closing Statement** | Counter | Counters against the last attack of a monster's combo deal +20/40/60/80% |
| **Exploit** | Counter | A monster stays open 0.2/0.4/0.6/0.8s longer after you dodge its whole combo |
| **Iron Chin** | Defense | +6/12/18/24% max knuckle HP |
| **Stinging Jab** | Dodge | Jabbing a monster within 1s of dodging it delays its next attack by 0.1/0.2/0.3/0.4s |
| **Answered** | Ultimate | Counters fill your ultimate 8/16/24/32% more |

**Rares (I-II)**
| Card | Tag | I | II |
|---|---|---|---|
| **Two Answers** | Counter | A counter that knocks out its target readies another counter with your other hand, no dodge needed | A counter that knocks out its target readies another counter with your other hand, up to twice in a row |
| **Turnabout** | Counter | Counters stun the target for 0.6s | Counters stun the target for 1.2s and stagger every monster within 2m of it |
| **Read Twice** | Counter | A clean dodge cuts Perfect Counter's cooldown by 1s | A clean dodge cuts Perfect Counter's cooldown by 2s |
| **Return to Sender** | Dodge | Dodging an arrow, fireball or bolt sends it back at the thrower for 2x your base damage | Dodging an arrow, fireball or bolt sends it back at the thrower for 4x your base damage |
| **Crowd Reader** | Dodge | Dodging an attack also dodges any other attack landing within 0.3s | Dodging an attack also dodges any other attack landing within 0.6s |

**Epics**
| Card | Upgrades | Effect |
|---|---|---|
| **Checkmate** | Perfect Counter | Perfect Counter: on a monster under 40% HP it knocks it out (a boss loses 15% of its max HP) |
| **Ghost Walk** | Phantom Step | Phantom Step: recharges twice as fast, and whoever threw it is stunned for 1s |
| **Stored Answers** | Dodge Chain | Dodge Chain: each punch spends one dodge instead of all of them, and chains go up to 10 |
| **Riposte II** | Riposte Stance | Riposte Stance: lasts 50% longer, and every counter in it is a Perfect Counter |
| **Untouchable** | Flow State | Flow State: every punch that lands while it lasts adds 0.2s |

**Legendaries**
| Seal | Card | Effect |
|---|---|---|
| Bellman | **Free Flow** | A counter readies one more counter with your other hand |
| Headless | **Precision Strike** | Perfect Counters work with any punch |
| Southpaw | **Ultimate Surge** | Every bout starts with your ultimate a quarter full, and using it gives a quarter back |
| Plague Doctor | **Mirror Match** | After a counter, the next attack aimed at you within 1s is slipped for you |
| Coffin King | **The Last Word** | Every 10th counter in a bout slows time for 3s, and every counter in it is a Perfect Counter |

---

## The Blur

Rapid Combos / Echo Fists / Long Reach / Temporal Break / Unbroken. Long combos, fast hands, shockwaves.

**Commons (ranks I/II/III/IV)**
| Card | Tag | Effect |
|---|---|---|
| **Second Gear** | Combo | From the 5th hit of a combo, +4/8/12/16% punch speed |
| **Bounce Back** | Combo | Getting hit leaves 40/55/70/85% of your combo instead of none |
| **Keen Eye** | Power | +3/6/9/12% chance of a critical hit (x1.5) |
| **Vital Points** | Power | Critical hits deal +15/30/45/60% |
| **Speed Bag** | Combo | The first 5 hits of each combo come 6/12/18/24% faster |

**Rares (I-II)**
| Card | Tag | I | II |
|---|---|---|---|
| **Thousand Fists** | Combo | From the 20th hit of a combo, every punch throws an extra hit for half | From the 15th hit of a combo, every punch throws an extra hit for half |
| **Ricochet** | Combo | When a monster you're comboing goes down, the combo timer refills and your next punch dashes you to the nearest monster within 5m | When a monster you're comboing goes down, the combo timer refills and your next punch dashes you to the nearest monster within 10m |
| **Rhythm Guard** | Dodge | Every 8th hit in a combo slips the next attack aimed at you | Every 6th hit in a combo slips the next attack aimed at you |
| **Afterimage** | Dodge | A dodge leaves a violet afterimage that punches the attacker for your base damage | A dodge leaves a violet afterimage that punches the attacker twice for your base damage |
| **Light Hands** | Defense | Jabs and crosses have a 30% chance to cost no knuckle HP | Jabs, crosses and hooks have a 30% chance to cost no knuckle HP |

**Epics**
| Card | Upgrades | Effect |
|---|---|---|
| **Aftershock** | Rapid Combos | Rapid Combos: the stun also hits everything it stuns for your base damage, and holds the combo timer 2s |
| **Double Echo** | Echo Fists | Echo Fists: echoes echo once more, for half |
| **Spear Hands** | Long Reach | Long Reach: punches at the edge of your reach hit 30% harder and push the monster back out of its range |
| **Temporal Break II** | Temporal Break | Temporal Break: every prompt you hit grows your combo by 3, and the break lasts 30% longer |
| **Unbroken II** | Unbroken | Unbroken: lasts 50% longer, and your combo timer runs twice as long for 5s after it ends |

**Legendaries**
| Seal | Card | Effect |
|---|---|---|
| Bellman | **Flurry** | Every 25th hit in a combo unleashes 8 lightning-fast hits on the target |
| Headless | **Perpetual Motion** | Your combo timer pauses while you dodge and for 1s after |
| Southpaw | **Ultimate Surge** | Every bout starts with your ultimate a quarter full, and using it gives a quarter back |
| Plague Doctor | **Blur** | From the 30th hit of a combo you move 20% faster, and 1 in 5 attacks aimed at you goes straight through you |
| Coffin King | **Fifty Before They Blink** | Reaching a 50-hit combo slows time for 3s (once a combo) |

---

## The Stray

Dash Punches / Head Stomp / Momentum / Highlight Reel / Hype Train. Always moving: dashes, jumps, hits from behind.

**Commons (ranks I/II/III/IV)**
| Card | Tag | Effect |
|---|---|---|
| **Rubber Legs** | Movement | Dashes cover 8/16/24/32% more ground |
| **Cheap Shot** | Power | Punches from behind or the side deal +10/20/30/40% |
| **Hang Time** | Movement | Jump punches deal +15/30/45/60% |
| **Stride** | Movement | +5/10/15/20% move and sprint speed |
| **Opportunist** | Power | +10/20/30/40% damage to monsters winding up an attack |

**Rares (I-II)**
| Card | Tag | I | II |
|---|---|---|---|
| **Dive Kick** | Movement | Jump punches stagger | Jump punches stagger and knock the monster back |
| **Vault** | Movement | Dashing into a monster vaults you over it, to its back | Dashing into a monster vaults you over it, and your next punch on it deals double |
| **Blindside** | Power | Your first punch on a monster that isn't facing you deals double | Your first punch on a monster that isn't facing you deals triple |
| **Ghost Step** | Dodge | Dashing through an attack dodges it | Dashing through an attack dodges it and gives the dash straight back |
| **Slick** | Dodge | Getting hit while sprinting only grazes you (half damage) | Getting hit while sprinting only grazes you (half damage), and every 3s one is a full dodge |

**Epics**
| Card | Upgrades | Effect |
|---|---|---|
| **Spear Line** | Dash Punches | Dash Punches: Spear Jab reaches 50% farther and staggers; Haymaker's blast throws monsters into the ones behind them |
| **Bounce House** | Head Stomp | Head Stomp: each bounce in a chain deals 50% more than the last, and a chain of 3 gives your dash back |
| **Full Tilt** | Momentum | Momentum: goes up to x3, and a punch spends only half of it |
| **Director's Cut** | Highlight Reel | Highlight Reel: hits 3 more monsters, and every hit stuns them for 1s |
| **Express** | Hype Train | Hype Train: lasts 1s longer for every monster you bowl over (up to +6s) |

**Legendaries**
| Seal | Card | Effect |
|---|---|---|
| Bellman | **High Ground** | Punches thrown in the air or from above the monster deal +50% |
| Headless | **Parkour** | You bounce off any monster's head you land on, stunning it for 0.5s, and a jump punch that lands gives your dash back |
| Southpaw | **Ultimate Surge** | Every bout starts with your ultimate a quarter full, and using it gives a quarter back |
| Plague Doctor | **Never Where They Swing** | While sprinting, every 3rd attack aimed at you misses |
| Coffin King | **Free Running** | Every 5s of nonstop moving makes your next punch triple damage and a stagger |

---

## Tony

Fuggedaboudit / The Muscle / The Take / Big Mouth / The Family. Enrages monsters (they take double from him) and works the crowd.

**Commons (ranks I/II/III/IV)**
| Card | Tag | Effect |
|---|---|---|
| **Trash Talk** | Rage | Enraged monsters stay mad 1/2/3/4s longer |
| **Below the Belt** | Power | Body shots on enraged monsters deal +12/24/36/48% |
| **Nice to Meet Ya** | Power | Your first punch on each monster deals +15/30/45/60% |
| **Shrug It Off** | Rage | A monster that hits you is enraged for 1/2/3/4s |
| **Tough Guy** | Defense | +5/10/15/20% max knuckle HP |

**Rares (I-II)**
| Card | Tag | I | II |
|---|---|---|---|
| **Say It To My Face** | Rage | Every 4th punch you land enrages the target for 4s | Every 3rd punch you land enrages the target for 4s |
| **Bada Bing** | Rage | Knocking out an enraged monster enrages the nearest one | Knocking out an enraged monster enrages the nearest two |
| **Made Man** | Defense | Fuggedaboudit stuns the monster whose hit you waved off for 1s | Fuggedaboudit stuns the monster whose hit you waved off for 2s |
| **Vinnie's Cousin** | Power | Vinnie holds monsters 1s longer, and you deal +25% to a monster he's holding | Vinnie holds monsters 1s longer, and you deal +50% to a monster he's holding |
| **Wake-Up Call** | Rage | Set-up hooks and uppercuts on enraged monsters stun them for 0.6s | Set-up hooks and uppercuts on enraged monsters stun them for 0.6s and knock them back |

**Epics**
| Card | Upgrades | Effect |
|---|---|---|
| **Fuggedaboudit II** | Fuggedaboudit | Fuggedaboudit: waves off two hits in a row, and recharges 3s faster |
| **The Whole Crew** | The Muscle | The Muscle: Vinnie grabs two monsters and cracks their heads together (2x your base damage each) |
| **Skim Off the Top** | The Take | The Take: enraged monsters pay triple, and knocking one out enrages the nearest monster |
| **Big Mouth II** | Big Mouth | Big Mouth: insults every monster in front of you, not just one |
| **Family Reunion** | The Family | The Family: a fourth goon shows up, and they stay 5s longer |

**Legendaries**
| Seal | Card | Effect |
|---|---|---|
| Bellman | **Last Word** | Knocking out an enraged monster scares every monster within 4m off for 2s |
| Headless | **Untouchable** | While any monster is enraged, the rest deal 25% less to you |
| Southpaw | **Ultimate Surge** | Every bout starts with your ultimate a quarter full, and using it gives a quarter back |
| Plague Doctor | **Respect** | Bosses and contenders are enraged by your first punch on them |
| Coffin King | **Capo** | An enraged monster you hit slugs the nearest other monster for 3x your base damage and leaves you alone for 2s (once each) |

---

## The Catalyst

Dual Sigil / Attunement / Prism / Elemental Fists / Flame Burst. Punches that set off his Sigil powers.

**Commons (ranks I/II/III/IV)**
| Card | Tag | Effect |
|---|---|---|
| **Conduit** | Spell | Your selected powers are 5/10/15/20% stronger |
| **Spellfist** | Ultimate | Elemental Fists lasts 1/2/3/4s longer |
| **Old Iron** | Power | +4/8/12/16% damage |
| **Afterglow** | Spell | Punches within 1s of a power going off deal +10/20/30/40% |
| **Runic Wraps** | Spell | Every 15/13/11/9th punch you land sets off one of your selected powers |

**Rares (I-II)**
| Card | Tag | I | II |
|---|---|---|---|
| **Resonance** | Spell | Two different powers hitting the same monster within 2s stagger it | Two different powers hitting the same monster within 2s stagger it, and it takes +20% from you for 3s |
| **Overflow** | Spell | Power damage beyond what knocks a monster out spills to the nearest one, at half | Power damage beyond what knocks a monster out spills to the nearest one |
| **Ward** | Defense | Every time a power goes off you gain a ward that soaks 3% of your max knuckle HP (stacks to 3) | Every time a power goes off you gain a ward that soaks 5% of your max knuckle HP (stacks to 3) |
| **Focus** | Spell | With only one power selected, any punch has a 10% chance to set it off | With only one power selected, any punch has a 20% chance to set it off |
| **Twin Cast** | Spell | Powers have a 15% chance to go off twice | Powers have a 30% chance to go off twice |

**Epics**
| Card | Upgrades | Effect |
|---|---|---|
| **Sigil Weave** | Dual Sigil | Dual Sigil: when both your powers hit the same monster within 2s, it bursts for 2x your base damage |
| **Deep Attunement** | Attunement | Attunement: the attuned power is 25% stronger, and every time it goes off you're 10% faster for 2s |
| **Spectrum** | Prism | Prism: each different power you set off in a row adds +10% damage, up to +40% |
| **Elemental Fists II** | Elemental Fists | Elemental Fists: each element's chance is 25%, and every spell hits a second monster |
| **Flame Burst II** | Flame Burst | Flame Burst: the ring of fire goes off twice |

**Legendaries**
| Seal | Card | Effect |
|---|---|---|
| Bellman | **Archmage** | Your powers are 30% stronger while your ultimate is over half full |
| Headless | **Living Conduit** | A power going off has a 10% chance to set off a random power you own |
| Southpaw | **Ultimate Surge** | Every bout starts with your ultimate a quarter full, and using it gives a quarter back |
| Plague Doctor | **Elemental Body** | Getting hit sets off one of your selected powers on the attacker (once a second) |
| Coffin King | **Grand Unification** | Every 20th time a power goes off, every power you own goes off too |

