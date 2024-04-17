#if defined _l4d_reachable_patch_included
 #endinput
#endif
#define _l4d_reachable_patch_included

/**
 * @brief A "SurvivorBotPathCost" verion of "NavAreaBuildPath". Same as "SurvivorBot::IsReachable".
 * @note DOESN'T WORK ON Linux L4D1. SDKCall doesn't support custom registers.
 * @remarks This could be really slow for 10% ~ 200% longer than "SurvivorBot::IsReachable".
 * @remarks "SurvivorBot::IsReachable" is generally fast due to a built-in cache for recent checks.
 * 
 * @param startArea				Start nav area (Address).
 * @param goalArea				Goal nav area (Address). "goalPos" is used if this is null.
 * @param goalPos				Goal position.
 * @param closestArea			The closest area on path.
 * @param maxPathLength			Max path length.
 * @param teamID				Team ID.
 * @param ignoreNavBlockers		Ignore nav blockers.
 * 
 * @return bool					True on success, false otherwise.
 */
native bool L4D_SurvivorBot_NavAreaBuildPath(
		any startArea,
		any goalArea = Address_Null,
		const float goalPos[3] = NULL_VECTOR,
		Address &closestArea = Address_Null,
		float maxPathLength = 0.0,
		int teamID = -1,
		bool ignoreNavBlockers = false);
	
/**
 * @brief Test if there's a path from an area to an area.
 * 
 * @param startArea				Start nav area (Address).
 * @param goalArea				Goal nav area (Address).
 * 
 * @return bool					True on success, false otherwise.
 */
native bool L4D_SurvivorBot_IsReachable(any startArea, any goalArea);


public SharedPlugin __pl_l4d_reachable_patch =
{
	name = "l4d_reachable_patch",
	file = "l4d_reachable_patch.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d_reachable_patch_SetNTVOptional()
{
	MarkNativeAsOptional("L4D_SurvivorBot_NavAreaBuildPath");
	MarkNativeAsOptional("L4D_SurvivorBot_IsReachable");
}
#endif
