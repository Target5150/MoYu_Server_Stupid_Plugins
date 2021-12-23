# [L4D2] Spit Frozen Fix

### Introduction
- Simple fix for spit activation being "frozen".
  - Spit activation timer gets reset only when the Update function finds current animation completed.
    - So if you despawn or are climbing ladders before it resets, the ability never goes into cooldown but "deadlocked".

<hr>

### Changelog
(v1.0 2021/12/23) Initial release.
