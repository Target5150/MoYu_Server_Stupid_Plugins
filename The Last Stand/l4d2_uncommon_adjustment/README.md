# [L4D2 Only] Uncommon Adjustment

### Introduction
- Custom adjustments to uncommon infected.
	- Max HP adjustment.
	- Uncommon infected attracting other commons (clowns / Jimmy gibbs Jr.).
	- Road workers / Jimmy gibbs Jr. reacting to sounds and/or smells.

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
```

<hr>

### Requirement
- [Actions](https://forums.alliedmods.net/showthread.php?p=2771520)

<hr>

### Installation
1. Put the **l4d2_uncommon_adjustment.smx** to your _plugins_ folder.

<hr>

### Changelog
(v2.1 2023/5/11 UTC+8) Uncommon Attract: Sense setting for roadworker and jimmy

(v2.0 2023/5/8 UTC+8) Fix road workman not reacting to vomit jars

(v1.0 2022/9/26 UTC+8) Initial release.
