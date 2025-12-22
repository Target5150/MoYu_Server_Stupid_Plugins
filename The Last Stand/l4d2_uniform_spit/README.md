# [L4D2] Uniform Spit

### Introduction
- Custom version that provides several features.
	1. Mimic vanilla behavior that damage changes per second according to a linear curve.
		- ![Vanilla damage curve](https://github.com/Target5150/MoYu_Server_Stupid_Plugins/raw/master/The%20Last%20Stand/l4d2_uniform_spit/vanilladamagecurve.png)
	2. Individual damage calculation for every player.
		- Only meaningful if damage curve is used.

<hr>

### ConVars
```
// Linear curve of damage per second that the spit inflicts. -1 to skip damage adjustments
// -
// Default: "0.0/1.0/2.0/4.0/6.0/6.0/4.0/1.4"
l4d2_spit_dmg "0.0/1.0/2.0/4.0/6.0/6.0/4.0/1.4"

// Damage per alternate tick. -1 to disable
// -
// Default: "-1.0"
l4d2_spit_alternate_dmg "-1.0"

// Maximum number of acid damage ticks
// -
// Default: "28"
l4d2_spit_max_ticks "28"

// Number of initial godframed acid ticks
// -
// Default: "4"
l4d2_spit_godframe_ticks "4"

// Individual damage calculation for every player.
// -
// Default: "0"
l4d2_spit_individual_calc "0"
```

<hr>

### Installation


<hr>

### Changelog
(v1.0 2022/11/11 UTC+8) Initial release.
