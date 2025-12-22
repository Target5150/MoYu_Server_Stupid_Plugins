# [L4D2] Tank Damage Announce

### Introduction
- A modified version with full support for multiple tanks and better way to record last human control.
- Merged with [l4d2_tank_facts_announce](https://github.com/Target5150/MoYu_Server_Stupid_Plugins/tree/master/The%20Last%20Stand/l4d2_tank_facts_announce)
	- ~~NOTE: Currently no option to change the text style so both damage and facts are printed together. Maybe an update soon.~~
		- See Version 2.2
- ~~NOTE: There're some issues with `z_spawn` that prevent the plugin from working properly.~~
	- See Version 3.0

<hr>

### ConVars
```
// Announce damage done to tanks when enabled
// -
// Default: "1" | Range: [0, 1]
l4d_tankdamage_enabled 1

// Text style for how tank facts are printed.
// 0 = Nothing
// 1 = Combine with damage print
// 2 = Separate lines before damage print
// 3 = Separate lines after damage print
// 4 = Individually print with a delay.
// -
// Default: "2" | Range: [0, 4]
l4d_tankdamage_text_style 2
```

<hr>

### Installation
1. Put **plugins/l4d_tank_damage_announce.smx** to your _plugins_ folder.
2. Merge **translations** with your _translations_ folder.

<hr>

### Changelog
(v1.0 2022/11/28 UTC+8) Initial release.
