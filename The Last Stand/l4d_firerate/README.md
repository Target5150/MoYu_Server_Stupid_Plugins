# [L4D & 2] Fire Rates

### Introduction
- Provide ConVars to change gun fire rates when **standing** and **incapped**.
	- Values of all ConVars are default to `0.0` which means no effect.
	- For example, changing `l4d_firerate_smg_normal` to `0.05` makes uzi shoot every **0.05s**.
- Not recommended to change fire rates of fully automatics which will raise **visual stutters** and **sound glitches** on clients.

<hr>

### ConVars
```
// Set incapped fire rate of autoshotgun
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_autoshotgun_incap "0.0"

// Set normal fire rate of autoshotgun
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_autoshotgun_normal "0.0"

// Set incapped fire rate of hunting_rifle
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_hunting_rifle_incap "0.0"

// Set normal fire rate of hunting_rifle
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_hunting_rifle_normal "0.0"

// Set incapped fire rate of pistol
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_pistol_incap "0.0"

// Set incapped fire rate of pistol_magnum
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_pistol_magnum_incap "0.0"

// Set normal fire rate of pistol_magnum
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_pistol_magnum_normal "0.0"

// Set normal fire rate of pistol
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_pistol_normal "0.0"

// Set incapped fire rate of pumpshotgun
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_pumpshotgun_incap "0.0"

// Set normal fire rate of pumpshotgun
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_pumpshotgun_normal "0.0"

// Set incapped fire rate of rifle_ak47
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_rifle_ak47_incap "0.0"

// Set normal fire rate of rifle_ak47
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_rifle_ak47_normal "0.0"

// Set incapped fire rate of rifle_desert
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_rifle_desert_incap "0.0"

// Set normal fire rate of rifle_desert
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_rifle_desert_normal "0.0"

// Set incapped fire rate of rifle
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_rifle_incap "0.0"

// Set incapped fire rate of rifle_m60
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_rifle_m60_incap "0.0"

// Set normal fire rate of rifle_m60
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_rifle_m60_normal "0.0"

// Set normal fire rate of rifle
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_rifle_normal "0.0"

// Set incapped fire rate of rifle_sg552
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_rifle_sg552_incap "0.0"

// Set normal fire rate of rifle_sg552
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_rifle_sg552_normal "0.0"

// Set incapped fire rate of shotgun_chrome
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_shotgun_chrome_incap "0.0"

// Set normal fire rate of shotgun_chrome
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_shotgun_chrome_normal "0.0"

// Set incapped fire rate of shotgun_spas
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_shotgun_spas_incap "0.0"

// Set normal fire rate of shotgun_spas
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_shotgun_spas_normal "0.0"

// Set incapped fire rate of smg
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_smg_incap "0.0"

// Set incapped fire rate of smg_mp5
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_smg_mp5_incap "0.0"

// Set normal fire rate of smg_mp5
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_smg_mp5_normal "0.0"

// Set normal fire rate of smg
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_smg_normal "0.0"

// Set incapped fire rate of smg_silenced
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_smg_silenced_incap "0.0"

// Set normal fire rate of smg_silenced
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_smg_silenced_normal "0.0"

// Set incapped fire rate of sniper_awp
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_sniper_awp_incap "0.0"

// Set normal fire rate of sniper_awp
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_sniper_awp_normal "0.0"

// Set incapped fire rate of sniper_military
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_sniper_military_incap "0.0"

// Set normal fire rate of sniper_military
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_sniper_military_normal "0.0"

// Set incapped fire rate of sniper_scout
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_sniper_scout_incap "0.0"

// Set normal fire rate of sniper_scout
// -
// Default: "0.0"
// Minimum: "0.000000"
l4d_firerate_sniper_scout_normal "0.0"
```

<hr>

### Requirement
- DHooks

<hr>

### Installation
1. Put **gamedata/l4d_firerate.txt** to your _gamedata_ folder.

<hr>

### Changelog
(v1.0 2023/5/11 UTC+8) Initial release.
