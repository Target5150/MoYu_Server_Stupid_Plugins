# [L4D & 2] Fix Fix Nextbot Collision

### Introduction
- Reduce the possibility that commons jiggle around when close to each other.
	- A well-known issue happens when setting `nb_update_frequency` to low value.
	- Note that this one doesn't perfectly fix the issue. Need more efforts into how the game resolves collisions.

<hr>

### ConVars
```
// How much to scale the move vector as a result of resolving zombie collision.
// -
// Default: "0.33333333"
// Minimum: "0.000000"
l4d_nextbot_collision_resolve_scale "0.33333333"
```

<hr>

### Requirement
- [Source Scramble](https://forums.alliedmods.net/showthread.php?t=317175)

<hr>

### Installation
1. Put **gamedata/l4d_fix_nextbot_collision.txt** to your _gamedata_ folder.

<hr>

### Changelog
(v1.0 2023/8/12 UTC+8) Initial release.
