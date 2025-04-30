#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Grenade Throw",
	author = "Forgetest",
	description = "Modifications to throw timings.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define GAMEDATA_FILE "l4d_grenade_throw"

float g_flWindupTime, g_flThrowDelay;

public void OnPluginStart()
{
	GameData conf = new GameData(GAMEDATA_FILE);
	if (conf == null)
		SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	DynamicDetour hDetour = DynamicDetour.FromConf(conf, "CBaseCSGrenade::PrimaryAttack");
	if (hDetour == null)
		SetFailState("Missing detour setup \"CBaseCSGrenade::PrimaryAttack\"");
	if (!hDetour.Enable(Hook_Post, DTR_CBaseCSGrenade_PrimaryAttack_Post))
		SetFailState("Failed to detour \"CBaseCSGrenade::PrimaryAttack\"");
	
	delete hDetour;
	
	hDetour = DynamicDetour.FromConf(conf, "CBaseCSGrenade::StartGrenadeThrow");
	if (hDetour == null)
		SetFailState("Missing detour setup \"CBaseCSGrenade::StartGrenadeThrow\"");
	if (!hDetour.Enable(Hook_Post, DTR_CBaseCSGrenade_StartGrenadeThrow_Post))
		SetFailState("Failed to detour \"CBaseCSGrenade::StartGrenadeThrow\"");
	
	delete hDetour;
	
	delete conf;
	
	ConVar cv = CreateConVar("grenade_throw_windup_time",
									"0.5",
									"Time from intent to throw that throw is ready.",
									FCVAR_SPONLY|FCVAR_NOTIFY,
									true, 0.0);
	CvarChg_WindupTime(cv, NULL_STRING, NULL_STRING);
	cv.AddChangeHook(CvarChg_WindupTime);
	
	cv = CreateConVar("grenade_throw_delay",
									"0.2",
									"Time from throw action that grenade actually emits.",
									FCVAR_SPONLY|FCVAR_NOTIFY,
									true, 0.1);
	CvarChg_ThrowDelay(cv, NULL_STRING, NULL_STRING);
	cv.AddChangeHook(CvarChg_ThrowDelay);
}

void CvarChg_WindupTime(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flWindupTime = convar.FloatValue;
}

void CvarChg_ThrowDelay(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flThrowDelay = convar.FloatValue;
}

MRESReturn DTR_CBaseCSGrenade_PrimaryAttack_Post(int entity)
{
	if (GetEntPropFloat(entity, Prop_Send, "m_flNextPrimaryAttack") != GetGameTime() + 0.5)
		return MRES_Ignored;
	
	SetEntPropFloat(entity, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + g_flWindupTime);
	return MRES_Ignored;
}

MRESReturn DTR_CBaseCSGrenade_StartGrenadeThrow_Post(int entity)
{
	if (GetEntPropFloat(entity, Prop_Send, "m_fThrowTime") != GetGameTime() + 0.2)
		return MRES_Ignored;
	
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwner");
	
	SetEntPropFloat(entity, Prop_Send, "m_fThrowTime", GetGameTime() + g_flThrowDelay);
	
	float flRate = 0.2 / g_flThrowDelay;
	SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", flRate);
	SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", flRate);
	
	return MRES_Ignored;
}
