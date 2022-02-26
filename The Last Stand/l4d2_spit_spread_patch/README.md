# [L4D2 Only] Spit Spread Patch

### Introduction
- Fix various spit spread issues.
	1. Spit bursts under props rather than on their surfaces.
	2. Spit doesn't spread on certain props (i.e. in elevator, on some stairs).
	3. Spit doesn't spread in saferoom/area.
		- Optional feature, controls provided to turn it off accordingly.
	4. Death spit becomes invisible (game insists to create it even if the trace misses).
		- Approach to disable spit puddle is from [l4d2_fix_deathspit](https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/l4d2_fix_deathspit.sp), but improved the detection.
		- There's also a `ConVar` provided to modify the trace length.

<hr>

### Requirement
- [DHooks](https://forums.alliedmods.net/showpost.php?p=2588686&postcount=589)
- [Source Scramble](https://forums.alliedmods.net/showthread.php?t=317175)
- [Collision Hook](https://github.com/L4D-Community/Collisionhook)

<hr>

### Installation
1. Put the **l4d2_spit_spread_patch.smx** to your _plugins_ folder.
2. Put the **l4d2_spit_spread_patch.txt** to your _gamedata_ folder.

<hr>

### Special Thanks
- **Psyk0tik**: for his generous share of lots of signatures.

<hr>

### Changelog
(v1.1 2022/2/26 UTC+8) Fix death spit.

(v1.0 2022/2/25 UTC+8) Initial release.
