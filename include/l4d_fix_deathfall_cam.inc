#if defined _l4d_fix_deathfall_cam_included
 #endinput
#endif
#define _l4d_fix_deathfall_cam_included

/**
 * @brief Release client from possible view-lock by guilty "point_viewcontrol*", "point_deathfall_camera".
 * @remarks Generally set the client's view back to normal state. Perhaps no need for complicated check.
 * @note Alternatively use `AcceptEntityInput(entity, "Disable")` except on "point_deathfall_camera".
 *
 * @param client		Client index to release
 *
 * @noreturn
 */
native void L4D_ReleaseFromViewControl(int client);


public SharedPlugin __pl_l4d_fix_deathfall_cam = 
{
	name = "l4d_fix_deathfall_cam",
	file = "l4d_fix_deathfall_cam.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d_fix_deathfall_cam_SetNTVOptional()
{
	MarkNativeAsOptional("L4D_ReleaseFromViewControl");
}
#endif