#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>

#include <@Forgetest/gamedatawrapper>

#define PLUGIN_VERSION "3.0"

public Plugin myinfo =
{
	name = "[L4D & 2] Tongue Float Fix",
	author = "Forgetest",
	description = "Fix tongue instant choking survivors.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

ConVar g_cvTongueAirChokeTime;

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_tongue_float_fix");
	delete gd.CreateDetourOrFail("l4d_tongue_float_fix::CTongue::UpdateAirChoke", DTR_UpdateAirChoke);
	delete gd;

	g_cvTongueAirChokeTime = CreateConVar("tongue_vertical_choke_time", "1.0", "Don't consider air choke unless victim is pulled for this long.", FCVAR_NONE, true, 0.0, false);
}

MRESReturn DTR_UpdateAirChoke(int ability)
{
	int owner = GetEntPropEnt(ability, Prop_Send, "m_owner");
	if (owner == -1)
		return MRES_Ignored;
	
	int victim = GetEntPropEnt(owner, Prop_Send, "m_tongueVictim");
	if (victim == -1)
		return MRES_Ignored;
	
	if (GetEntProp(victim, Prop_Send, "m_isHangingFromTongue"))
		return MRES_Ignored;
	
	// Don't consider air choke unless victim is pulled for long enough time
	if (g_cvTongueAirChokeTime.FloatValue < GetGameTime() - GetEntPropFloat(ability, Prop_Send, "m_tongueHitTimestamp"))
		return MRES_Ignored;
	
	if (GetEntPropEnt(victim, Prop_Send, "m_hGroundEntity") != -1)
		SetEntPropFloat(ability, Prop_Send, "m_tongueVictimLastOnGroundTime", GetGameTime());

	return MRES_Supercede;
}
