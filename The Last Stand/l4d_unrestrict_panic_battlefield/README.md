# [L4D & 2] Unrestrict Panic Battlefield

### Introduction
- Remove zombie spawning restrictions during panic events:
	1. Allow special/mob spawns in battlefield areas while panic event isn't active.
	2. "SPAWN_SPECIALS_ANYWHERE" instead of "SPAWN_SPECIALS_IN_FRONT_OF_SURVIVORS".
	3. Survivor active set as spawn areas instead of only "BATTLEFIELD" areas.
	4. Allow spawns on cleared areas.
- A good example is on **Swamp Fever 1** start the ferry and go back to saferoom area.

<hr>

### ConVars
```
// Special should spawn in battlefield areas while panic event isn't active.
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
special_battlefield_spawn "1"

// Natural mob should spawn when all survivors are in battlefield areas.
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
z_mob_battlefield_spawn "1"

// Special should spawn anywhere instead of only in front during a panic.
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
special_panic_spawn_anywhere "1"

// Zombies can spawn on non-battlefield areas during a panic.
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
z_panic_outside_battlefield "1"

// Zombies can spawn on cleared areas during a panic.
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
z_panic_ignore_clear_state "1"
```

<hr>

### Requirement
- [Source Scramble](https://forums.alliedmods.net/showthread.php?t=317175)

<hr>

### Installation

2. Put **gamedata/l4d_unrestrict_panic_battlefield.txt** to your _gamedata_ folder.

<hr>

### Changelog
(v1.0 2025/08/29 UTC+8) Initial release.
