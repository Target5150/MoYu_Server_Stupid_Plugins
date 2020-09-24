# l4d_tank_control_eq

- Added a native for other plugins to retrieve who will be the tank (spechud mainly)

```
/**  
 * @brief Get the selected player index to be the Tank.  
 *  
 * @return		client index  
 */  
public Native_GetTankSelection(Handle:plugin, numParams)  
{  
	return getInfectedPlayerBySteamId(queuedTankSteamId);  
}
```