# [L4D & 2] Auto Pick-up Weapon

### Introduction
- Re-implement the broken feature from CS of auto picking-up weapons.

![image](https://github.com/Target5150/MoYu_Server_Stupid_Plugins/blob/master/The%20Last%20Stand/l4d_auto_pickup_weapon/preview.gif?raw=true)

<hr>

### ConVars
```
// Default enabled of auto pick-up weapon.
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
auto_pickup_weapon_default "1"

// Auto equip guns that can be dual wielded.
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
auto_pickup_weapon_dualwield "1"

// Interval time for auto equipping guns dropped yourself.
// -
// Default: "1.0"
// Minimum: "0.000000"
auto_pickup_weapon_self_drop_interval "1.0"
```

<hr>

### Commands
```
sm_absorb | sm_pickup | !absorb | !pickup
	- Toggle the auto equipping guns for you.

```

<hr>

### Installation
1. Merge your _translations_ folder with the one here.

<hr>

### Changelog
(v1.0 2025/04/11 UTC+8) Initial release.
