# [L4D2 Only] Uncommon Adjustment

### Introduction
- Custom adjustments to uncommon infected.
	- Max HP adjustment.
	- Uncommon infected attracting other commons (clowns / Jimmy gibbs Jr.).
	- Road workers / Jimmy gibbs Jr. reacting to sounds and/or smells.
	- Screen splatters (Mudman, Jimmy).
	- Fallen survivor equipments control.
	- Riotcop armor removal.
	- CEDA fireproof removal.

<hr>

### ConVars
```
// Set whether clowns and Jimmy gibbs Jr. can attract zombies.
// 0 = Neither, 1 = Clowns, 2 = Jimmy gibs Jr., 3 = Both
// -
// Default: "3" | Range: [0.0, 3.0]
l4d2_uncommon_attract "3"

// Set whether road workers can hear and/or smell, so they will react to certain attractions.
// 0 = Neither, 1 = Hear (pipe bombs, clowns), 2 = Smell (vomit jars), 3 = Both
// -
// Default: "0" | Range: [0.0, 3.0]
l4d2_roadworker_sense_flag "0"

// Set whether Jimmy gibbs Jr. can hear and/or smell, so they will react to certain attractions.
// 0 = Neither, 1 = Hear (pipe bombs, clowns), 2 = Smell (vomit jars), 3 = Both
// -
// Default: "0" | Range: [0.0, 3.0]
l4d2_jimmy_sense_flag "0"

// How many the uncommon health is scaled by.
// Doesn't apply to Jimmy gibs Jr., fallen survivors and Riot Cops.
// -
// Default: "3.0" | Range: [0.0, ~]
l4d2_uncommon_health_multiplier "3.0"

// How many the health of Jimmy gibbs Jr. is scaled by.
// -
// Default: "20.0" | Range: [0.0, ~]
l4d2_jimmy_health_multiplier "20.0"

// Set what items a fallen survivor can equip.
// 1 = Molotov, 2 = Pipebomb, 4 = Pills, 8 = Medkit, 15 = All, 0 = Nothing
// -
// Default: "15" | Range: [0.0, 15.0]
l4d2_fallen_equipments "15"

// Set whether riotcop has armor that prevents damages in front.
// -
// Default: "1" | Range: [0.0, 1.0]
l4d2_riotcop_armor "1"

// Set whether mudman can crouch while running.
// -
// Default: "1" | Range: [0.0, 1.0]
l4d2_mudman_crouch_run "1"

// Set whether mudman can blind your screen.
// -
// Default: "1" | Range: [0.0, 1.0]
l4d2_mudman_screen_splatter "1"

// Set whether Jimmy gibbs Jr. can blind your screen.
// -
// Default: "1" | Range: [0.0, 1.0]
l4d2_jimmy_screen_splatter "1"

// Set whether CEDA is fireproofed.
// -
// Default: "1" | Range: [0.0, 1.0]
l4d2_ceda_fire_proof "1"
```

<hr>

### Requirement
- **DHooks**
- [Actions](https://forums.alliedmods.net/showthread.php?p=2771520)

<hr>

### Installation
1. Put **plugins/l4d2_uncommon_adjustment.smx** to your _plugins_ folder.
2. Put **gamedata/l4d2_uncommon_adjustment.txt** to your _gamedata_ folder.

<hr>

### Changelog
(v3.1 2024/12/7 UTC+8) l4d2_uncommon_adjustment: Add CEDA fireproof option

(v3.0 2024/12/7 UTC+8) l4d2_uncommon_adjustment: More uncommon options

(v2.1 2023/5/11 UTC+8) Uncommon Attract: Sense setting for roadworker and jimmy

(v2.0 2023/5/8 UTC+8) Fix road workman not reacting to vomit jars

(v1.0 2022/9/26 UTC+8) Initial release.
