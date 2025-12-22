# [L4D Only] No M2 Movement Block

### Introduction
- Allow **free movement as SI** when scratching like L4D2.
	- In L4D1, SIs are blocked from ducking and side-moving whenever they are scratching.
- Worth memtioning that **client-side predition** issue is still there.
	- Original Mem-Patch version raises obvious visual glitches especially when crouching, because client-side prediction insist on movement block.
	- New Detour version tries its best to reduce this effect by tricking the client not scratching.

<hr>

### Installation
1. Put **plugins/l4d_no_m2_movement_block.smx** to your _plugins_ folder.
2. Put **gamedata/l4d_no_m2_movement_block.txt** to your _gamedata_ folder.

<hr>

### Changelog
(v2.1 2022/1/31 UTC+8) Reworked again to fix silenced hunter scratches and remove selective enabling due to client prediction again.

(v2.0 2022/1/31 UTC+8) Initial release of reworked version.

(v1.0 2022/1/31 UTC+8) Initial version that straight patches memory to bring back this feature.
