# l4d_equalise_alarm_cars

- (V1.5 2021/2/25)
	- Prevented possible waste when no alarm-off gets triggered.
	- Removed more or less useless debug functionality.

- (V1.4 2021/2/17)
	- Further equalized colors since alarm cars would disappear due to the Tank.
	- Debug cvar.

- (V1.3 2021/2/14) Upgrade for Alarm Car Color Consistency

- (V1.2) Original version

- [Discussion](https://github.com/Derpduck/L4D2-Comp-Stripper-Rework/issues/12)
  - Alternative solution, by upgrading the plugin.
  - Globally applicable, as long as the name format of alarm cars are standard to be hooked.

# ConVars
```
// Makes alarmed cars spawn in the same way for both teams.
// -  
// Default: "1"  
l4d_equalise_alarm_cars "1"  
```