# melee spawn control

- Credit to IA-NanaNana
- Original post:https://forums.alliedmods.net/showthread.php?t=327605&highlight=melee+spawn+control
- Simply unlock melee weapons only, you can add melee weapons to map basis melee spawn in every map now.

	- Require Extension:**DHooks (Dynamic Hooks)**
		- http://forums.alliedmods.net/showthread.php?p=2588686#post2588686

# Convars
```
// Melee weapon list for unlock, use ',' to separate between names, e.g: pitchfork,shovel. Empty for no change 
// -  
// Default: ""
// MoYu server setting↓
l4d2_melee_spawn "fireaxe,frying_pan,machete,baseball_bat,crowbar,cricket_bat,tonfa,katana,electric_guitar,knife,golfclub,pitchfork,shovel"

// Add melee weapons to map basis melee spawn or l4d2_melee_spawn, use ',' to separate between names. Empty for don't add 
// -  
// Default: ""
// :D ↓
l4d2_add_melee "pitchfork"
```