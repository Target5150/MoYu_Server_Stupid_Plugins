# [L4D2] Charger Target Fix

### Introduction
- Fix multiple charger targeting issues.
	- Fix charger grabbing victims of other chargers.
	- Fix hunter being able to pounce onto charger targets.
	- Fix jockey being able to pounce onto charger targets.
	- (Optional) Fix Survivors in pummel blocking movement of Infected Team.
	- (Optional) Fix Survivors getting up from pummel blocking movement of Infected Team.
	- (Since v1.9) Fix non-chargers stuck in pounding Survivors when they change team during queued pummel sections.
- NOTE: Remove `l4d2_jockeyed_charger_fix` for duplication.

<hr>

### ConVars
```
// Enable collision to Infected Team on Survivors pinned by charger.
// 1 = Enable collision during pummel, 2 = Enable collision during get-up, 3 = Both, 0 = No collision at all.
// -
// Default: "3" | Range: [0.0, 3.0]
z_charge_pinned_collision "1"

// Duration between knockdown timer ends and get-up finishes.
// The higher value is set, the earlier Survivors become collideable when getting up from charger.
// -
// Default: "0.1" | Range: [0.0, 4.0]
charger_knockdown_getup_window "0.1"
```

<hr>

### Requirement
- **[Left 4 DHooks Direct (1.127+)](https://forums.alliedmods.net/showthread.php?t=321696)**

<hr>

### Installation

2. Put **gamedata/l4d2_charge_target_fix.txt** to your _gamedata_ folder.

<hr>

### Changelog
(v2.0 2023/1/4 UTC+8) Initial release.
