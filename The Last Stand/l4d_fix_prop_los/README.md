# [L4D & 2] Fix Prop LOS

### Introduction
- Fix thin/small 'prop_*' entity not blocking LOS.
	- [Game code causing this](https://github.com/alliedmodders/hl2sdk/blob/c2badaa4f7e763a92427ac11202c349385810cc2/game/server/props.cpp#L296-L299).

<hr>

### Requirement
- **DHooks**

<hr>

### Installation
1. Put **plugins/l4d_fix_prop_los.smx** to your _plugins_ folder.
2. Put **gamedata/l4d_fix_prop_los.txt** to your _gamedata_ folder.

<hr>

### Changelog
(v1.0 {2026/05/16} UTC+8) Initial release.
