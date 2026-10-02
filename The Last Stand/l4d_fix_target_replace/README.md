# [L4D & 2] Fix Target Replace

### Introduction
- Fix issues with infected targeting when replacing survivors.
    1. Smoker
        - Lose target when warning before vomit.
    2. Boomer
        - Lose target when warning before shooting tongue.
    3. Infected
        - Lose target when chasing / attacking.
        - Punch misses.
    4. Witch
        - Potentially lose target when chasing / attacking incapped.
            - This will only happen when you have plugins like fixing Witch's targeting for multiple characters.

<hr>

### ConVars
```
// Enable target fix for Smoker?
// -
// Default: "1.000000"
// Minimum: "0.000000"
// Maximum: "1.000000"
l4d_fix_target_replace_smoker "1"

// Enable target fix for Boomer?
// -
// Default: "1.000000"
// Minimum: "0.000000"
// Maximum: "1.000000"
l4d_fix_target_replace_boomer "1"

// Enable target fix for the common infected?
// -
// Default: "1.000000"
// Minimum: "0.000000"
// Maximum: "1.000000"
l4d_fix_target_replace_infected "1"

// Enable target fix for Witch?
// -
// Default: "1.000000"
// Minimum: "0.000000"
// Maximum: "1.000000"
l4d_fix_target_replace_witch "1"
```

<hr>

### Installation
1. Put **plugins/l4d_fix_target_replace.smx** to your _plugins_ folder.

<hr>

### Changelog
(v1.0 2024/2/1 UTC+8) Initial release.
