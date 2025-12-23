# [L4D & 2] Tongue Fatigue Control

### Introduction
- Customize the fatigue from tongue release.
	1. Zero fatigue in favor of insta-clears.
		- By default`tongue_release_fatigue_scale_min_time` is `0.2`, means survivors will receive **no movement penalty** if released from tongue in 0.2s (in any way).
		- By default`tongue_release_fatigue_scale_max_time` is `1.0`, means survivors will receive __**scaled movement penalty**__ if released from tongue after the above minimum time, a maximum if over 1.0s.
	2. more? ...

<hr>

### ConVars
```
// Before this time of being pulled the victim gets no fatigue penalty.
// -
// Default: "0.200000"
// Minimum: "0.000000"
tongue_release_fatigue_scale_min_time "0.2"

// After this time of being pulled the victim gets full fatigue penalty.
// -
// Default: "1.000000"
// Minimum: "0.000000"
tongue_release_fatigue_scale_max_time "1.0"
```

<hr>



### Changelog
(v1.0 2023/10/30 UTC+8) Initial release.
