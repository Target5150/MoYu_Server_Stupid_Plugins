#if defined _l4d_tank_damage_announce_included
	#endinput
#endif
#define _l4d_tank_damage_announce_included

/**
 * @brief Retrieves total punches landed by a Tank during his lifetime.
 *
 * @param client	Client id of the Tank
 *
 * @return			Number of punches.
 */
native int TFA_Punches(int client);

/**
 * @brief Retrieves total rocks landed by a Tank during his lifetime.
 *
 * @param client	Client id of the Tank
 *
 * @return			Number of rocks.
 */
native int TFA_Rocks(int client);

/**
 * @brief Retrieves total hittables landed by a Tank during his lifetime.
 *
 * @param client	Client id of the Tank
 *
 * @return			Number of hittables.
 */
native int TFA_Hittables(int client);

/**
 * @brief Retrieves total damage done by a Tank during his lifetime.
 *
 * @param client	Client id of the Tank
 *
 * @return			Number of total damage.
 */
native int TFA_TotalDmg(int client);

/**
 * @brief Retrieves life time of an alive Tank.
 *
 * @param client	Client id of the Tank
 *
 * @return			Elasped time in seconds, -1 if non-exist or dead.
 */
native int TFA_UpTime(int client);

public SharedPlugin __pl_l4d_tank_damage_announce =
{
	name = "l4d_tank_damage_announce",
	file = "l4d_tank_damage_announce.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d_tank_control_eq_SetNTVOptional()
{
	MarkNativeAsOptional("TFA_Punches");
	MarkNativeAsOptional("TFA_Rocks");
	MarkNativeAsOptional("TFA_Hittables");
	MarkNativeAsOptional("TFA_TotalDmg");
	MarkNativeAsOptional("TFA_UpTime");
}
#endif
