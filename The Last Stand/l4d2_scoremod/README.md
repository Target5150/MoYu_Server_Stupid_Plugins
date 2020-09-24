# l4d2_scoremod

- Added a native for other plugins to retrieve the health bonus (spechud mainly)

`/**
 * @brief Get the current health bonus.
 *
 * @return		Float health bonus
 */
public int Native_HealthBonus(Handle plugin, int numParams)
{
	decl iAliveCount;
	new Float:fAvgHealth = SM_CalculateAvgHealth(iAliveCount);	
	
	new iScore = RoundToFloor(fAvgHealth * SM_fMapMulti * SM_fHBRatio) * iAliveCount;
	
	return iScore;
}`