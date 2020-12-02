# l4dhots

- Competitive L4D HOTs but narrowed down to another way to bother the system
	- Avoid manipulating game ConVar _"pain_pills_health_value"_ and _"adrenaline_health_buffer"_
	- Instead store their temp health when using those, and restore it after used
	- Small workaround to deal with possible loss of temp health (_hurt_ or _healed with kits by teammate_)

- 2020/12/2: More tests needed. Not sure whether performing the same, theoretically yes.