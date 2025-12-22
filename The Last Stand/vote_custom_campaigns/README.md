# vote_custom_campaigns

### Introduction
- Title.
- Maps not localized can be fixed via adding them to translations

<hr>

### Requirement
- [imatchext](https://github.com/shqke/imatchext)
- (Optional, recommended for scavenge servers) [Proper Changelevel](https://forums.alliedmods.net/showthread.php?p=2669850)

<hr>

### Installation

2. Merge your _translations_ folder with the one here.
3. Edit **missions.phrases.txt** to cover missing localizations of custom campaigns.

<hr>

### Commands
- `!vcc !mapvote` - Start a menu to select campaigns to vote.
- `!vcc_reload` - (Admin only) Re-parse the campaign list.

<hr>

### Convars
```
// Votes reaching this percent of clients(no-spec) can a vote result.
// -
// Default: "0.60"
vcc_vote_percent "0.60"

// Approvals reaching this percent of votes can a vote pass.
// -
// Default: "1"
vcc_pass_percent "0.60"`
```
