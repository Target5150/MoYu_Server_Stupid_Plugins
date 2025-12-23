# [L4D & 2] Fix Punch Block

### Introduction
- Developed after [tankdoorfix](https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/tankdoorfix.sp) which is really unreliable to fix the issue.
- After investigation, Common infected coinciding with tank will lead to the following:
	- Of course, traces in swing function detect them.
	- `CTankClaw::OnHit` is called on them, but nothing happens.
	- Somehow the swing is not going to hurt them, and therefore constantly blocks the punch.
- To fix this, CI within a certain range will be filtered in `PassServerEntityFilter`.

<hr>

### Installation
1. Put **gamedata/l4d_fix_punch_block.txt** to your _gamedata_ folder.

<hr>

### Changelog
(v1.0 2022/3/15 UTC+8) Initial release.
