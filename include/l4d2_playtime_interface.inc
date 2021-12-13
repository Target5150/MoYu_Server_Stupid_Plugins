#if defined _l4d2_playtime_interface_included
 #endinput
#endif
#define _l4d2_playtime_interface_included

/**
 * @brief Called when a client's playtime of L4D2 is retrieved.
 * @remarks Uses Steam Web API so do not exceed Steam privacy settings.
 *
 * @param AuthID		String of steam64 auth
 * @param real			If true, value is actual playtime (shown in Achievements),
 *						total time otherwise
 * @param value			Playtime in seconds, -1 if not recorded, -2 if reached privacy.
 *
 * @noreturn
 */
forward void L4D2_OnGetPlaytime(const char[] auth, bool real, int value);

/**
 * @brief Retrieves the client playtime of L4D2.
 * @remarks Uses Steam Web API so do not exceed Steam privacy settings.
 *
 * @param AuthID		String of steam2 auth to find
 * @param real			True to retrieve actual playtime (shown in Achievements),
 *						total time otherwise
 *
 * @return				Playtime in seconds, -1 if not recorded, -2 if reached privacy.
 */
native int L4D2_GetTotalPlaytime(const char[] auth, bool real);


public SharedPlugin __pl_l4d2_playtime_interface = 
{
	name = "l4d2_playtime_interface",
	file = "l4d2_playtime_interface.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_playtime_interface_SetNTVOptional()
{
	MarkNativeAsOptional("L4D2_GetTotalPlaytime");
}
#endif