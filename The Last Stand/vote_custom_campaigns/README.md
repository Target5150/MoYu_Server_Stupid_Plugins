# vote_custom_campaigns

### Introduction
- Self-descriptive.
- Maps not localized can be fixed via adding them to translations

<hr>

### Requirement
- [l4d2_mission_manager](https://github.com/rikka0w0/l4d2_mission_manager)
- (Optional, recommended for scavenge servers) [Proper Changelevel](https://forums.alliedmods.net/showthread.php?p=2669850)

<hr>

### Installation
1. Put the **vote_custom_campaigns.smx** in your _plugins_ folder.
2. Put the files in **translations** folder to your _trabslations_ folder.
3. Edit the **translation files** to cover missing localizations of custom campaigns.

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
