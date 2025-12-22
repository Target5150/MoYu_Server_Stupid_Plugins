# Sweep Fist Patch
https://forums.alliedmods.net/showthread.php?t=332046

### Introduction
- Patch memory bytes to allow multi-punch for tanks in coop mode.

<hr>

### Requirement
- [Source Scramble](https://forums.alliedmods.net/showthread.php?t=317175)

<hr>

### Installation
1. Put **plugins/l4d_sweep_fist_patch.smx** to your _plugins_ folder.
2. Put **gamedata/l4d_sweep_fist_patch.txt** to your _gamedata_ folder.

<hr>

### Special Thanks
- **Crasher_3637** (**Psykotikism**): for providing everything.
- **HarryPotter**: for original idea.
- **Dragokas**: for L4D1 testing and gamedata update.

<hr>

### Changelog
(v3.0 2023/8/23 UTC+8)
- Rework
	1. I have no idea why I came up with the update -> [9329f5f](https://github.com/Target5150/MoYu_Server_Stupid_Plugins/commit/9329f5fb05f18affdc67614e5bc9dd9b95e8181b)
	When I finished reviewing the assembly, this doesn't appear to fix anything
	2. So I just got myself confused when I ended up with only a single patch, of course on function "SweepFist".
	3. I finally decide to blame the bad patching on "call" instruction, the only possible cause.
	4. All those detours are unnecessary, lead to performance drop, and no safety issue without them.

Good to realize I'm not that lazy to refuse reviewing my ass stuff when I was just a beginner.

(v2.3 2021/8/18 UTC+8)
- Add version ConVar for tracking and minor fix for compiling warnings.

(v2.3 2021/8/18 UTC+8)
- Final fix on both games both platforms.
- Polished MemortPatch error output.
  - Exception being bitflags, notifies which patches error out. (1 = Sweep Fist Check1, 2 = Sweep Fist Check2, 4 = Ground Pound Check)

(v2.2 2021/8/18 UTC+8) Minor fix for L4D1.

(v2.1a 2021/8/16 UTC+8) Minor change to detect map running.

(v2.1 2021/8/16 UTC+8) Support for both L4D on both platforms.

(v2.0 2021/8/16 UTC+8) Now should work on cases where tank punches onto incapacitated survivors.

(v1.5a 2021/8/16 UTC+8) Updated L4D2 Linux offsets.

(v1.5 2021/4/29 7PM UTC+8)
- Added L4D1 Linux support.
- Fixes for incorrect usage of `IsAllowedGamemode()`.

(v1.4 2021/4/26) Added a hook on game mode change to prevent issues.

(v1.3 2021/4/24 9PM UTC+8) Redirected the way message gets printed, no longer spamming in console.

(v1.2 2021/4/24 4PM UTC+8) Fixed server starting on Survival Mode.

(V1.1 2021/4/24 1PM UTC+8) Fixed IsTank check for L4D1 and some optimization.
