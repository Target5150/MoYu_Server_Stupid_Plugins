# Backjump Fix

### Introduction
- DHook onto `CLunge::OnTouch` to override `IsValidEdict` check, if the touched other is a solid non-world entity.

<hr>

### Requirement
- [DHooks](https://forums.alliedmods.net/showpost.php?p=2588686&postcount=589)

<hr>

### Installation
1. Put **gamedata/l4d2_si_ability.txt** to your _gamedata_ folder.

<hr>

### Special Thanks
- **ProdigySim**: for sharing `gpGlobals` knowledge, helps a lot with my cognition.
- **Derpduck**: for sharing `entities` knowledge, helps a lot with my cognition.
- DHook setup from `L4D2 Jockeyed Charger Fix`, credits to **Visor**.
- GameData credits to **A1mDev**.

<hr>

### Changelog
(v1.2 2021/8/14 UTC+8) Fixed pouncing off 'weapon*_spawn'.

(v1.1 2021/8/14 UTC+8) Address several mistakes.

(v1.0 2021/8/14 UTC+8) Initial release.
