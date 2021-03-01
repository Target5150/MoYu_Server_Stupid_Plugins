# AntiBreach ([Forum](https://forums.alliedmods.net/showthread.php?p=2520740))

### Introduction
Prevent infected players exploiting saferoom doors to spawn inside saferoom.

### Difference from the original
- Functions for all saferoom doors around end saferoom.
  - In general, there's only one saferoom door for end saferoom, so exploit happens only there.
  - The exception found was C12M4, where the end saferoom is a train with both entrance and exit saferoom doors. and they are accessible to the infected.
- Changed the algorithm used to check whether player as ghost is jumping through the door.
  - This should help prevent unexpected spawn blocking from happening, by calculating the player's component velocity against the door and comparing it with their distance to the door.
  - Possible bad performance due to those calculations (I haven't paid attention to this tho, maybe there can be optimization).
