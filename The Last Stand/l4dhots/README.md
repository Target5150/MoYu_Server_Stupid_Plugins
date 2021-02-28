# L4D Hots

### Introduction

Competitive L4D HOTs but narrowed down to another way to bother the system
- Avoid manipulating game ConVar _"pain_pills_health_value"_ and _"adrenaline_health_buffer"_
- Instead store their temp health when using those, and restore it after used
- Small workaround to deal with possible loss of temp health (_hurt_ or _healed with kits by teammate_)
	
<hr>

### Changelog
- (V0.7 2021/2/22) Changing team will no longer interrupt the healing due to bot/player replace.

- (V0.6 2020/12/2) Initial Release