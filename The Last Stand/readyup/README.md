# L4D2 Ready Up

# Introduction

- Enriched information on panel.
- Hints the player who cancels live countdown, by 3 main reasons.
- Fast ready / unready via **Vote** keys _(**F1** and **F2** by default)_
- Support **Scavenge**.
- Translations.

<hr>

# Instruction
### ConVars
- `l4d_ready_enabled` - Enable this plugin. (Values: 1 = Manual ready, 2 = Auto start). Default: `"1"`
- `l4d_ready_cfg_name` - Configname to display on the ready-up panel. Default: `""`
- `l4d_ready_server_cvar` - ConVar to retrieve the server name for displaying on the ready-up panel. Default: `"sn_main_name"`
- `l4d_ready_disable_spawns` - Prevent SI from having spawns during ready-up. Default: `"0"`
- `l4d_ready_survivor_freeze` - Freeze the survivors during ready-up. When unfrozen they are unable to leave the saferoom but can move freely inside. Default: `"0"`
- `l4d_ready_max_players` - Maximum number of players to show on the ready-up panel. Default: `"12"`
- `l4d_ready_delay` - Number of seconds to count down before the round goes live. Default: `"5"`
- `l4d_ready_autostart_delay` - Number of seconds to count down before auto-start kicks in. Default: `"5"`
- `l4d_ready_autostart_wait` - Number of seconds to wait for connecting players before auto-start is forced. Default: `"20"`
- `l4d_ready_enable_sound` - Enable sound during autostart & countdown & on live. Default: `"1"`
- `l4d_ready_countdown_sound` - The sound that plays when a round goes on countdown. Default: `"weapons/hegrenade/beep.wav"`
- `l4d_ready_live_sound` - The sound that plays when a round goes live. Default: `"ui/survival_medal.wav"`
- `l4d_ready_autostart_sound` - The sound that plays when auto-start goes on countdown. Default:`"uui/buttonrollover.wav"`
- `l4d_ready_chuckle` - Enable random moustachio chuckle during countdown. Default:`"0"`
- `l4d_ready_secret` - Play a medal particle every time a player marks ready. Default: `"1"`
- `l4d_ready_unbalanced_start` - Allow game to go live when teams are not full. Default: `"0"`
- `l4d_ready_unbalanced_min` - Minimum of players in each team to allow a unbalanced start. Default: `"2"`

<hr>

### Commands
> Ready Commands

- `!ready !r` - Mark yourself as ready for the round to go live.
- `!unready !nr` - Mark yourself as not ready if you have set yourself as ready.
- `!toggleready` - Toggle your ready status.

> Caster System

- Admins only:
  - `!caster <Name / Userid / SteamID>` - Registers a in-game player as a caster.
  - `!resetcasters` - Used to reset casters between matches.  This should be in confogl_off.cfg or equivalent for your system.
  - `!add_caster_id <SteamID>` - Used for adding casters to the whitelist -- i.e. who's allowed to self-register as a caster.
  - `!remove_caster_id <SteamID>` - Used for removing casters from the whitelist.
  - `!printcasters` - Used for print casters in the whitelist.

- Standard:
  - `!cast` - Registers the calling player as a caster.
  - `!notcasting !uncast <Name / Userid / SteamID>` - Unregister yourself as a caster or allow admins to unregister other players

> Admin Commands

- `!forcestart !fs` - Forces the round to start regardless of player ready status.

> Player Commands

- `!hide` - Hides the ready-up panel so other menus can be seen.
- `!show` - Shows a hidden ready-up panel.
- `!return` - Return to a valid saferoom spawn if you get stuck during an unfrozen ready-up period.
- `!kickspecs` - Let's vote to kick those Spectators! Can be used every now and then.

<hr>

# Installation

- Put _readyup.phrases.txt_ to **addons/sourcemod/translations**
- Edit the translation file to your language if you want to.
	- Remember to save the edition as another file in the correct language folder.
