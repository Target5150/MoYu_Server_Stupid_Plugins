# Restore Blocked Vocalize in Competitive

### Introduction
- **Self-descriptive**
	- Perform **Laughter**, **Taunt**, **Death Scream** _nearly_ as naturally as in vanilla.
		- Works via `PerformScene()` provided with **scene files** (.vcd).
		- **nearly** simply means since The Last Stand update, I cannot tell if certain voicelines are enabled or not, and how the new system of vocalize works.

<hr>

### Requirement
- [Scene Processor](https://forums.alliedmods.net/showthread.php?p=2147410)

<hr>

### Changelog
- (V1.2.11 2021/7/16)
	- Address out-of-bound issue of Restore Vocalize

- (V1.2.10 2021/6/2)
	- Restored previously removed checking to restrict usage.
	- Replaced `l4d2util` dependency with required functionalites only.
	- Modified `Math_GetRandomInt` to prevent sequently giving equal numbers.

- (V1.2.9 2021/5/4) Fixed spamming errors of not being able to create entity on no map loaded.

- (V1.2.8 2021/3/25) Precache sound files as well.

- (V1.2.7 2021/3/25) Fixed spamming array out of bounds errors.

- (V1.2.6 2021/2/22) Fixed wrong counted scene lists (:D).

- (V1.2.5 2021/2/22) Code optimize.

- (V1.2.4 2021/2/11) Altered method of scene files precache.

- (V1.2.3 2021/2/2) Tried to restore vanilla style when vocalize Taunt.

- (V1.2.1 2021/1/14) Initial Release
