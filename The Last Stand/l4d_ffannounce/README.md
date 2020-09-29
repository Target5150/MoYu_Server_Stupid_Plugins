# l4d_ffannounce

- Credit to AiMee.
- Briefly shows friendly fire info to activators, and additionally to spectators if set.
- Allows logging abnormal FF to file, along with flexible setting.

# ConVars
```
// Enable Announcing Friendly Fire (0 - Disabled, 1 - Announce in private, 2 - Announce to Activators and Spectators).  
// -  
// Default: "1"  
l4d_ff_announce_enable "1"  

// Friendly fire amount over this value will be logged to file (Found in sourcemod/logs/abnormalff.log), 0 to disable.  
// -  
// Default: "0"  
l4d_ff_announce_log "0"  

// File path to log friendly fire  
// -  
// Default: "logs/abnormalff.log"  
l4d_ff_announce_log_path "logs/abnormalff.log"
```