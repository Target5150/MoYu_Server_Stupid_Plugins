#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Vomit Impulse",
	author = "Forgetest",
	description = "Shove abusers deserve their punishment of rewarding opponents with shorter cooldown.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

float g_flVomitImpulse, g_flSpitImpulse;
bool g_bVomitFirstShove, g_bSpitFirstShove;

public void OnPluginStart()
{
	CreateConVarHook("vomit_shove_impulse_amount",
					"10.0",
					"Amount of time is decreased from vomit ability cooldown whenever the boomer is shoved by survivors.",
					FCVAR_SPONLY,
					true, 0.0, false, 0.0,
					CvarChg_VomitImpulse);
	
	CreateConVarHook("vomit_shove_impulse_first_time",
					"0",
					"Whether to apply impulse when the boomer is shoved for the first time.",
					FCVAR_SPONLY,
					true, 0.0, true, 1.0,
					CvarChg_VomitFirstShove);
	
	CreateConVarHook("spit_shove_impulse_amount",
					"8.0",
					"Amount of time is decreased from spit ability cooldown whenever the spitter is shoved by survivors.",
					FCVAR_SPONLY,
					true, 0.0, false, 0.0,
					CvarChg_SpitImpulse);
	
	CreateConVarHook("spit_shove_impulse_first_time",
					"0",
					"Whether to apply impulse when the spitter is shoved for the first time.",
					FCVAR_SPONLY,
					true, 0.0, true, 1.0,
					CvarChg_SpitFirstShove);
}

void CvarChg_VomitImpulse(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flVomitImpulse = convar.FloatValue;
}

void CvarChg_VomitFirstShove(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bVomitFirstShove = convar.BoolValue;
}

void CvarChg_SpitImpulse(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flSpitImpulse = convar.FloatValue;
}

void CvarChg_SpitFirstShove(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bSpitFirstShove = convar.BoolValue;
}

public void L4D_OnShovedBySurvivor_Post(int client, int victim, const float vecDir[3])
{
	if (!IsClientInGame(victim))
		return;
	
	if (GetClientTeam(victim) != 3)
		return;
	
	if (!IsPlayerAlive(victim))
		return;
	
	if (!L4D_IsPlayerStaggering(victim))
		return;
	
	int shoveCount = GetShovedCount(victim);
	
	float flImpulse;
	bool bIgnoreFirstShove;
	switch (GetEntProp(victim, Prop_Send, "m_zombieClass"))
	{
	case 2:
		{
			flImpulse = g_flVomitImpulse;
			bIgnoreFirstShove = (g_bVomitFirstShove == false);
		}
	case 4:
		{
			bIgnoreFirstShove = (g_bSpitFirstShove == false);
			
			flImpulse = g_flSpitImpulse * (bIgnoreFirstShove ? (shoveCount - 1) : shoveCount);
		}
	default:
		{
			return;
		}
	}
	
	if (bIgnoreFirstShove && shoveCount == 1)
		return;
	
	int ability = GetEntPropEnt(victim, Prop_Send, "m_customAbility");
	if (ability == -1)
		return;
	
	float timestamp = GetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer", 1);
	if (timestamp == -1.0)
		return;
	
	SetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer", timestamp - flImpulse, 1);
}

int GetShovedCount(int client)
{
	Address m_aShovedTimes__m_size = GetShovedTimeVector(client) + view_as<Address>(12);
	return LoadFromAddress(m_aShovedTimes__m_size, NumberType_Int32);
}

Address GetShovedTimeVector(int client)
{
	static int s_iOffs_m_aShovedTimes = -1;
	if (s_iOffs_m_aShovedTimes == -1)
		s_iOffs_m_aShovedTimes = FindSendPropInfo("CTerrorPlayer", "m_shoveForce") - 20;
	
	return GetEntityAddress(client) + view_as<Address>(s_iOffs_m_aShovedTimes);
}

ConVar CreateConVarHook(const char[] name,
	const char[] defaultValue,
	const char[] description="",
	int flags=0,
	bool hasMin=false, float min=0.0,
	bool hasMax=false, float max=0.0,
	ConVarChanged callback)
{
	ConVar cv = CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
	
	Call_StartFunction(INVALID_HANDLE, callback);
	Call_PushCell(cv);
	Call_PushNullString();
	Call_PushNullString();
	Call_Finish();
	
	cv.AddChangeHook(callback);
	
	return cv;
}
