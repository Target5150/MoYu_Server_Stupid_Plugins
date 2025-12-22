# [L4D & 2] Prop Touching Rules

### Introduction
- Rules of props' move away, moved above props.

<hr>

### ConVars
```
// Props lighter than this mass can be moved away on touching.
// NOTE: Unused if "prop_touching_moveaway" is disabled.
// -
// Default: "900.0"
// Minimum: "0.000000"
prop_moveaway_mass_thres "900.0"

// Move away medium-weight props on touching.
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
prop_touching_moveaway "1"

// Stop players being moved above heavy props on touching.
// 0 = Disable, 1 = Survivors, 2 = Special except tank, 4 = Tank, 7 = All
// -
// Default: "1"
// Minimum: "0.000000"
prop_heavy_touching_move_above "0"
```

<hr>

### Requirement
- [Source Scramble](https://forums.alliedmods.net/showthread.php?t=317175)
- **DHooks**

<hr>

### Installation

2. Put **gamedata/l4d_prop_touching_rules.txt** to your _gamedata_ folder.

<hr>

### Changelog
(v1.0 2025/04/05 UTC+8) Initial release.
