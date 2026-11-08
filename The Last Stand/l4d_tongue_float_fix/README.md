# [L4D & 2] Tongue Float Fix

### Introduction
- Fix tongue instant choking survivors by blocking vertical choke mechanism for a period.
	- Usually happens when as Survivor grabbed by tongue in the air or standing on some entities.

<hr>

### ConVars
```
// Don't consider air choke unless victim is pulled for this long.
// -
// Default: "1.0"
// Minimum: "0.000000"
tongue_vertical_choke_time "1.0"
```

<hr>

### Installation
1. Put **plugins/l4d_tongue_float_fix.smx** to your _plugins_ folder.
2. Put **gamedata/l4d_tongue_float_fix.txt** to your _gamedata_ folder.

<hr>

### Changelog
(v3.0 2026/11/08 UTC+8) l4d_tongue_float_fix: Restore detour handling

(v2.0 2023/6/23 UTC+8) More correct fix for instant tongue choking

(v1.1 2021/10/27 UTC+8) Initial release.
