# Checkpoint Spit Control

### Introduction
- Patch memory bytes to allow spit to spread in saferoom area.
- Force spit to perform burst on any solid surfaces (before it does on world entities only).
  - Affected entities such as elevators, some stairs, props added via Stripper, etc.
  - Note that the patch method is rather risky since it simply ignores the touch entity type, disable if your setver crashes.
    - Probably better to move onto `CSpitterProjectile::DetonateThink`, well it's working so next time.

<hr>

### Installation
1. Put the **l4d2_checkpoint_spit_control.smx** to your _plugins_ folder.
2. Put the **l4d2_checkpoint_spit_control.txt** to your _gamedata_ folder.

<hr>

### Changelog
(v2.0 2021/8/22 UTC+8) Additional functionality to modify spit burst behavior.

(v1.0 2021/8/14 UTC+8) Initial release.