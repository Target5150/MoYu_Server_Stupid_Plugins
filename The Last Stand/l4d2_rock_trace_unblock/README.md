# [L4D2 Only] Rock Trace Unblock

### Introduction
- Solely handles the rock radius checks to prevent blocking by hunter/jockey that is dominating survivors.
- Additionally allow to force jockey dismount the survivor who eats rock.
- This plugin takes over game function `ForEachPlayer<ProximityCheck>`.
	- It really seems like the game traces refuse to believe results from detoured `PassServerEntityFilter`, which is why I have to rework the whole logic.
	- And therefore it conflicts with [l4d_checkpoint_rock_patch](https://github.com/Target5150/MoYu_Server_Stupid_Plugins/tree/master/The%20Last%20Stand/l4d_checkpoint_rock_patch) whose functionalities are included here.

<hr>

### Installation
1. Put the **l4d2_rock_trace_unblock.smx** to your _plugins_ folder.
2. Put the **l4d2_rock_trace_unblock.txt** to your _gamedata_ folder.

<hr>

### Changelog
(v1.1 2022/2/18 UTC+8) Prevent rock detonating on close survivors

(v1.0 2022/2/18 UTC+8) Initial release.
