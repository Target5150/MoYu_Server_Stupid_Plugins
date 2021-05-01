#if defined _simple_playtime_interface_included
 #endinput
#endif
#define _simple_playtime_interface_included

/**
 * @brief Retrieves the playtime of game that client is playing.
 * @remarks respects sort of privacy settings.
 *
 * @param AuthID		String of steam2 auth to find
 *
 * @return				Playtime in minutes on success, 0 on failure to find.
 */
native int Steam_GetClientPlaytime(const char[] auth);


public SharedPlugin __pl_simple_playtime_interface = 
{
	name = "simple_playtime_interface",
	file = "simple_playtime_interface.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_simple_playtime_interface_SetNTVOptional()
{
	MarkNativeAsOptional("Steam_GetClientPlaytime");
}
#endif