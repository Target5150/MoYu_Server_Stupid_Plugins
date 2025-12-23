# [L4D & 2] Ghost Checkpoint Spawn

### Introduction
- Changes to conditions for ghost spawning in start areas.
	- (L4D1 Only) Allow ghost to materialize in start saferoom when all survivors leave.
	- Allow ghost to materialize in start saferoom even if not all survivors leave.

<hr>

### ConVars
```
// Allow ghost to materialize in start saferoom even if not all survivors leave.
// 0 = Disable, 1 = Intro maps only, 2 = All maps
// -
// Default: "0" | Range: [0, 2]
z_ghost_unrestricted_spawn_in_start 0

// Allow ghost to materialize in end saferoom.
// 0 = Disable, 1 = All maps
// -
// Default: "0" | Range: [0, 1]
z_ghost_unrestricted_spawn_in_end 0

// L4D1 only. Allow ghost to materialize in start saferoom when all survivors leave.
// 0 = Disable, 1 = Enable
// -
// Default: "0" | Range: [0, 1]
l4d1_ghost_spawn_in_start 0
```

<hr>

### Installation
1. Put **gamedata/l4d_ghost_checkpoint_spawn.txt** to your _gamedata_ folder.

<hr>

### Changelog
(v1.1 2022/11/26 UTC+8) In favor of SDKHooks

(v1.0 2022/11/26 UTC+8) Initial release.
