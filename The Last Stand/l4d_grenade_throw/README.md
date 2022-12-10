# [L4D & 2] Grenade Throw

### Introduction
- Modifications to throw timings..
- Basically this is developed to make throwables behave like in CS:GO where you can:
	1. Throw grenades without need to __"warm up"__ that prevents **fast use**.
		- From first M1 click to releasing M1.
	2. Emit grenades earlier (defaults to **0.1s** after releasing **M1** in CS:GO).
		- From releasing M1 to grenade actually flies.
- Recommended settings for CS:GO like experience:
	- `grenade_throw_windup_time 0.0`
	- `grenade_throw_delay 0.1` (Bindings for jump-throw could work)

<hr>

### ConVars
```
// Time from intent to throw that throw is ready.
// -
// Default: "0.5" | Range: [0.0, ~]
grenade_throw_windup_time "0.5"

// Time from throw action that grenade actually emits.
// -
// Default: "0.2" | Range: [0.1, ~]
grenade_throw_delay "0.2"
```

<hr>

### Requirement
- **DHooks**

<hr>

### Installation
1. Put the **l4d_grenade_throw.smx** to your _plugins_ folder.
2. Put the **l4d_grenade_throw.txt** to your _gamedata_ folder.

<hr>

### Changelog
(v1.0 2022/12/10 UTC+8) Initial release.
