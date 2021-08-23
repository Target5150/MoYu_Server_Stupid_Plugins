# Backjump Fix

### Intruduction
- DHook onto `CLunge::OnTouch` to override `IsValidEdict` check, if the touched other is a solid non-world entity.
- Currently tested on Linux L4D2 only.

<hr>

### Installation
1. Put the **l4d_backjump_fix.smx** to your _plugins_ folder.
2. Put the **l4d2_si_ability.txt** to your _gamedata_ folder.

<hr>

### Special Thanks
- **ProdigySim**: for sharing `gpGlobals` knowledge, helps a lot with my cognition.
- **Derpduck**: for sharing `entities` knowledge, helps a lot with my cognition.
- DHook setup from `L4D2 Jockeyed Charger Fix`, credits to **Visor**.
- GameData credits to **A1mDev**.

<hr>

### Changelog
(v1.0 2021/8/14 UTC+8) Initial release.